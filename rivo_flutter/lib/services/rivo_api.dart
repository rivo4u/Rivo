import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'phone_image_upload.dart';

class RivoApi {
  RivoApi(this.client);

  final SupabaseClient client;

  PhoneImageUpload get _images => PhoneImageUpload(client);

    String? imageUrl(Object? path, {required String bucket}) =>
      _images.publicUrl(path, bucket: bucket);

    Future<String> uploadImage(XFile image,
        {required String bucket, required String path}) =>
      _images.upload(image, bucket: bucket, path: path);

  Future<Map<String, dynamic>?> myProfile() async {
    final user = client.auth.currentUser;
    if (user == null) return null;
    return await client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
  }

  Future<void> updateMyProfile(Map<String, dynamic> changes) async {
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Sign in before updating your profile.');
    if (changes.isEmpty) return;
    await client.from('profiles').update(changes).eq('id', user.id);
  }

  Future<List<Map<String, dynamic>>> activeRooms() async {
    final rows = await client
        .from('rooms')
        .select(
            'id, owner_id, title, description, image_path, is_active, created_at')
        .eq('is_active', true)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> createRoom({
    required String title,
    required String description,
    XFile? image,
  }) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sign in before creating a room.');
    
    // Call the backend RPC to create the room
    final rows = await client.rpc(
      'create_room',
      params: {
        'p_title': title.trim(),
        'p_description': description.trim().isEmpty ? null : description.trim(),
      },
    );
    
    // The RPC returns a list with one row (the created room)
    if (rows == null || (rows is List && rows.isEmpty)) {
      throw StateError('Room creation returned no data from the backend.');
    }
    
    final row = rows is List ? rows.first as Map<String, dynamic> : rows as Map<String, dynamic>;
    final roomId = row['id']?.toString();
    
    if (roomId == null) {
      throw StateError('Room ID is missing from the backend response.');
    }
    
    // Upload image if provided
    if (image != null) {
      final path = await uploadImage(
        image,
        bucket: PhoneImageUpload.roomsBucket,
        path: '$userId/$roomId/image.jpg',
      );
      await client.from('rooms').update({'image_path': path}).eq('id', roomId);
      row['image_path'] = path;
    }
    
    return row;
  }

  Future<void> joinRoom(String roomId) async {
    await client.rpc('join_room', params: {'p_room_id': roomId});
  }

  Future<void> leaveRoom(String roomId) async {
    await client.rpc('leave_room', params: {'p_room_id': roomId});
  }

  Future<List<Map<String, dynamic>>> roomSeats(String roomId) async {
    final rows = await client
        .from('mic_seats')
        .select('seat_no, user_id, is_muted, updated_at')
        .eq('room_id', roomId)
        .order('seat_no');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> roomMessages(String roomId) async {
    final rows = await client
        .from('room_messages')
        .select('id, user_id, body, created_at')
        .eq('room_id', roomId)
        .order('created_at', ascending: true)
        .limit(100);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> sendRoomMessage(String roomId, String body) async {
    await client.rpc('send_room_message', params: {
      'p_room_id': roomId,
      'p_body': body,
    });
  }

  Stream<List<Map<String, dynamic>>> watchRoomMessages(String roomId) {
    return client
        .from('room_messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at', ascending: true);
  }

  Stream<List<Map<String, dynamic>>> watchSeats(String roomId) {
    return client
        .from('mic_seats')
        .stream(primaryKey: ['room_id', 'seat_no'])
        .eq('room_id', roomId)
        .order('seat_no');
  }

  Future<void> claimSeat(String roomId, int seatNo) async {
    await client.rpc('claim_mic_seat', params: {
      'p_room_id': roomId,
      'p_seat_no': seatNo,
    });
  }

  Future<void> releaseSeat(String roomId, int seatNo) async {
    await client.rpc('release_mic_seat', params: {
      'p_room_id': roomId,
      'p_seat_no': seatNo,
    });
  }

  Future<void> setSeatMute(String roomId, int seatNo, bool muted) async {
    await client.rpc('set_mic_mute', params: {
      'p_room_id': roomId,
      'p_seat_no': seatNo,
      'p_muted': muted,
    });
  }

  Future<Map<String, dynamic>?> myWallet() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return null;
    return await client
        .from('wallets')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
  }

  Future<Map<String, dynamic>?> economyConfig() async {
    final rows = await client.from('economy_config').select().limit(1);
    final configs = List<Map<String, dynamic>>.from(rows);
    return configs.firstOrNull;
  }

  Future<List<Map<String, dynamic>>> rechargePackages() async {
    final rows = await client.from('recharge_packages').select();
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> coinTransactions() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];
    final rows = await client
        .from('coin_transactions')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> gifts() async {
    final rows = await client.from('gifts').select();
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> sendGift({
    required String receiverId,
    required String giftId,
    String? roomId,
  }) async {
    await client.rpc('send_gift', params: {
      'p_receiver_id': receiverId,
      'p_gift_id': giftId,
      'p_room_id': roomId,
    });
  }

  Stream<List<Map<String, dynamic>>> watchRoomGifts(String roomId) {
    return client
        .from('gift_transactions')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at', ascending: true);
  }

  Future<List<Map<String, dynamic>>> giftHistory() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];
    final rows = await client
        .from('gift_transactions')
        .select()
        .or('sender_id.eq.$userId,receiver_id.eq.$userId')
        .order('created_at', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> moments() async {
    final rows = await client
        .from('moments')
        .select()
        .order('created_at', ascending: false)
        .limit(100);
    final moments = List<Map<String, dynamic>>.from(rows);
    return moments.map((moment) {
      return {
        ...moment,
        'author': {
          'display_name': moment['author_name'],
          'avatar_path': moment['author_avatar_path'],
        },
      };
    }).toList();
  }

  Future<void> createMoment(String body,
      {required String momentId, XFile? image}) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sign in before posting a Moment.');
    final profile = await myProfile();
    final metadata = client.auth.currentUser?.userMetadata ?? {};
    final authorName = (profile?['display_name'] ??
            profile?['username'] ??
            metadata['full_name'] ??
            metadata['name'] ??
            'Rivo user')
        .toString();
    String? imagePath;
    if (image != null) {
      imagePath = await uploadImage(
        image,
        bucket: PhoneImageUpload.momentsBucket,
        path: '$userId/$momentId/image.jpg',
      );
    }
    await client.from('moments').upsert({
      'id': momentId,
      'user_id': userId,
      'body': body,
      'content': body,
      'image_path': imagePath,
      'author_name': authorName,
      'author_avatar_path': profile?['avatar_path'],
    }, onConflict: 'id');
  }

  Future<void> deleteMoment(String momentId) async {
    final moment = await client
        .from('moments')
        .select('image_path')
        .eq('id', momentId)
        .maybeSingle();
    await client.from('moments').delete().eq('id', momentId);
    await _images.remove(
      moment?['image_path'],
      bucket: PhoneImageUpload.momentsBucket,
    );
  }

  Future<List<Map<String, dynamic>>> directMessages() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];
    final rows = await client
        .from('messages')
        .select()
        .or('sender_id.eq.$userId,receiver_id.eq.$userId')
        .order('created_at', ascending: false)
        .limit(500);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> sendDirectMessage(String receiverId, String body) async {
    await client.from('messages').insert({
      'sender_id': client.auth.currentUser!.id,
      'receiver_id': receiverId,
      'body': body,
    });
  }

  Stream<List<Map<String, dynamic>>> watchDirectMessages(String otherUserId) {
    final userId = client.auth.currentUser!.id;
    return client
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .map((rows) => rows.where((row) {
              final sender = row['sender_id']?.toString();
              final receiver = row['receiver_id']?.toString();
              return (sender == userId && receiver == otherUserId) ||
                  (sender == otherUserId && receiver == userId);
            }).toList());
  }

  Future<void> markDirectMessagesRead(String otherUserId) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sign in to update message state.');
    await client
        .from('messages')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('sender_id', otherUserId)
        .eq('receiver_id', userId)
        .isFilter('read_at', null);
  }

  Future<List<Map<String, dynamic>>> notifications() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];
    final rows = await client
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(rows);
  }

  Stream<List<Map<String, dynamic>>> watchNotifications() {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return Stream.value(const []);
    return client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false);
  }

  Future<void> markNotificationRead(String notificationId) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sign in to update notifications.');
    await client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId)
        .eq('user_id', userId);
  }

  Future<Map<String, dynamic>?> mySettings() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return null;
    return await client
        .from('user_settings')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
  }

  Future<void> updateMySettings(Map<String, dynamic> changes) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sign in before updating settings.');
    await client.from('user_settings').upsert({'user_id': userId, ...changes});
  }

  Future<void> followUser(String userId) async {
    await client.from('follows').insert(
        {'follower_id': client.auth.currentUser!.id, 'followed_id': userId});
  }

  Future<void> blockUser(String userId) async {
    await client.from('blocks').insert(
        {'blocker_id': client.auth.currentUser!.id, 'blocked_id': userId});
  }

  Future<void> reportUser(String userId, String reason) async {
    await client.from('reports').insert({
      'reporter_id': client.auth.currentUser!.id,
      'reported_id': userId,
      'reason': reason,
    });
  }
}
