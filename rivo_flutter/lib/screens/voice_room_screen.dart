import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../services/rivo_api.dart';
import '../widgets/common.dart';
import '../widgets/game_sheet.dart';
import '../widgets/room_tools_sheet.dart';
import 'feature_screens.dart';

class VoiceRoomScreen extends StatefulWidget {
  final String? roomId;
  final String? roomTitle;
  final String hostName;
  final String hostId;
  final int trophyCount;
  final int onlineCount;

  const VoiceRoomScreen({
    super.key,
    this.roomId,
    this.roomTitle,
    this.hostName = 'Mr Adi',
    this.hostId = '192681',
    this.trophyCount = 10800,
    this.onlineCount = 1,
  });

  @override
  State<VoiceRoomScreen> createState() => _VoiceRoomScreenState();
}

class _VoiceRoomScreenState extends State<VoiceRoomScreen> {
  final RivoApi _api = RivoApi(Supabase.instance.client);
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  Stream<List<Map<String, dynamic>>>? _seatStream;
  Stream<List<Map<String, dynamic>>>? _messageStream;
  Stream<List<Map<String, dynamic>>>? _giftStream;
  late Future<List<Map<String, dynamic>>> _giftCatalog;
  List<Map<String, dynamic>> _currentSeats = [];
  bool _sending = false;
  bool _leaving = false;
  bool _hasLeft = false;
  int _streamVersion = 0;
  int _lastMessageCount = -1;

  @override
  void initState() {
    super.initState();
    _giftCatalog = Future.value(const []);
    final roomId = widget.roomId;
    if (roomId != null) {
      _seatStream = _api.watchSeats(roomId);
      _messageStream = _api.watchRoomMessages(roomId);
      _giftStream = _api.watchRoomGifts(roomId);
      _giftCatalog = _api.gifts();
    }
  }

  void _retryRoomStreams() {
    final roomId = widget.roomId;
    if (roomId == null) return;
    setState(() {
      _seatStream = _api.watchSeats(roomId);
      _messageStream = _api.watchRoomMessages(roomId);
      _giftStream = _api.watchRoomGifts(roomId);
      _giftCatalog = _api.gifts();
      _streamVersion++;
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final roomId = widget.roomId;
    final body = _messageController.text.trim();
    if (roomId == null || body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _api.sendRoomMessage(roomId, body);
      _messageController.clear();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send message: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _tapSeat(int seatNo) async {
    final roomId = widget.roomId;
    if (roomId == null) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final seat =
        _currentSeats.where((item) => item['seat_no'] == seatNo).firstOrNull;
    final occupant = seat?['user_id']?.toString();
    try {
      if (occupant == null) {
        await _api.claimSeat(roomId, seatNo);
      } else if (occupant == userId) {
        await _api.releaseSeat(roomId, seatNo);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update mic seat: $error')),
        );
      }
    }
  }

  void _showVoiceUnavailable() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Live audio is unavailable because no voice transport is configured.'),
      ),
    );
  }

  Future<void> _leaveRoom() async {
    if (_leaving) return;
    _leaving = true;
    try {
      final roomId = widget.roomId;
      if (roomId != null) await _api.leaveRoom(roomId);
      if (!mounted) return;
      setState(() => _hasLeft = true);
      Navigator.of(context).pop();
    } catch (error) {
      _leaving = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not leave room: $error')),
        );
      }
    }
  }

  void _openSheet(BuildContext context, Widget sheet) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => sheet,
    );
  }

  void _openGiftPicker() {
    final roomId = widget.roomId;
    if (roomId == null) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final recipients = _currentSeats
        .where((seat) =>
            seat['user_id'] != null && seat['user_id'].toString() != userId)
        .map((seat) {
      final id = seat['user_id'].toString();
      return {
        'user_id': id,
        'label':
            'Seat ${seat['seat_no']} · ${id.substring(0, id.length.clamp(0, 8))}'
      };
    }).toList();
    if (recipients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Another participant must join a seat before you can send a room gift.')),
      );
      return;
    }
    _openSheet(context, GiftSendSheet(roomId: roomId, recipients: recipients));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: _hasLeft,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _leaveRoom();
      },
      child: Scaffold(
        backgroundColor: AppColors.roomDeep,
        body: SafeArea(
          child: Column(
            children: [
              _header(context),
              _seatsGrid(),
              _roomGiftBanner(),
              Expanded(child: _chatArea()),
              _inputBar(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF243027), AppColors.roomDeep],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      AppAvatar(
                          label: widget.hostName,
                          size: 26,
                          ringColor: Colors.transparent),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.roomTitle ?? widget.hostName,
                              style: AppTextStyles.body(
                                  size: 12.5,
                                  weight: FontWeight.w800,
                                  color: AppColors.roomText)),
                          Text('ID: ${widget.hostId}',
                              style: AppTextStyles.label(
                                  size: 10, color: AppColors.roomTextMute)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _roomIcon(Icons.ios_share_rounded),
              const SizedBox(width: 8),
              _roomIcon(Icons.groups_rounded),
              const SizedBox(width: 8),
              _roomIcon(Icons.card_giftcard_rounded, onTap: _openGiftPicker),
              const SizedBox(width: 8),
              _roomIcon(Icons.power_settings_new_rounded, onTap: _leaveRoom),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.emoji_events_rounded,
                  size: 16, color: Colors.amber.shade300),
              const SizedBox(width: 6),
              Text('${(widget.trophyCount / 1000).toStringAsFixed(1)}K',
                  style: AppTextStyles.body(
                      size: 13,
                      weight: FontWeight.w800,
                      color: AppColors.roomText)),
              const Icon(Icons.chevron_right_rounded,
                  size: 16, color: AppColors.roomTextMute),
              const Spacer(),
              CircleAvatar(radius: 10, backgroundColor: AppColors.green),
              const SizedBox(width: 6),
              Text('${widget.onlineCount}',
                  style: AppTextStyles.label(
                      size: 11, color: AppColors.roomTextMute)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _roomIcon(IconData icon, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Icon(icon, size: 14, color: AppColors.roomText),
      ),
    );
  }

  Widget _seatsGrid() {
    final seatStream = _seatStream;
    if (seatStream == null) return _seatGrid(const []);
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: seatStream,
      builder: (context, snapshot) {
        if (snapshot.hasData) _currentSeats = snapshot.data!;
        if (snapshot.hasError) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _roomNotice(
                  'Microphone seats are unavailable: ${snapshot.error}'),
              _seatGrid(_currentSeats),
            ],
          );
        }
        return _seatGrid(_currentSeats);
      },
    );
  }

  Widget _roomGiftBanner() {
    final giftStream = _giftStream;
    if (giftStream == null) return const SizedBox.shrink();
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: giftStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _roomNotice('Gift activity is unavailable: ${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return const LinearProgressIndicator(minHeight: 2);
        }
        if (snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        final latest = snapshot.data!.last;
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _giftCatalog,
          builder: (context, giftsSnapshot) {
            if (giftsSnapshot.hasError) {
              return _roomNotice(
                  'Gift details are unavailable: ${giftsSnapshot.error}');
            }
            if (!giftsSnapshot.hasData) {
              return const LinearProgressIndicator(minHeight: 2);
            }
            final giftId = latest['gift_id']?.toString();
            final gift = giftsSnapshot.data!
                .where((row) => row['id']?.toString() == giftId)
                .firstOrNull;
            final giftName = gift?['name'] ??
                gift?['title'] ??
                gift?['gift_name'] ??
                giftId ??
                'Gift';
            final amount = latest['coin_amount'] ??
                latest['price'] ??
                latest['amount'] ??
                '?';
            final sender = latest['sender_id']?.toString() ?? 'Someone';
            final receiver = latest['receiver_id']?.toString() ?? 'someone';
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: AppColors.greenDark.withValues(alpha: 0.35),
              child: Text('$sender sent $giftName to $receiver · $amount coins',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      AppTextStyles.label(size: 10, color: AppColors.roomText)),
            );
          },
        );
      },
    );
  }

  Widget _seatGrid(List<Map<String, dynamic>> seats) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    return Container(
      color: AppColors.roomDeep,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: GridView.count(
        crossAxisCount: 5,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 14,
        childAspectRatio: 0.78,
        children: List.generate(10, (i) {
          final seatNo = i + 1;
          final seat =
              seats.where((item) => item['seat_no'] == seatNo).firstOrNull;
          final userId = seat?['user_id']?.toString();
          final occupied = userId != null;
          final isSelf = occupied && userId == currentUserId;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => _tapSeat(seatNo),
                customBorder: const CircleBorder(),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelf ? Colors.amber : AppColors.green,
                      width: 2,
                    ),
                    color: AppColors.green.withValues(alpha: 0.15),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    occupied ? Icons.mic_rounded : Icons.add_rounded,
                    color: AppColors.green,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                occupied
                    ? userId.substring(0, userId.length.clamp(0, 6))
                    : 'No.$seatNo',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.label(
                    size: 9.5, color: AppColors.roomTextMute),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _roomNotice(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
      color: Colors.amber.withValues(alpha: 0.12),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 16, color: Colors.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label(size: 10, color: AppColors.roomText),
            ),
          ),
          TextButton.icon(
            onPressed: _retryRoomStreams,
            icon: const Icon(Icons.refresh_rounded, size: 14),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _chatArea() {
    final roomId = widget.roomId;
    if (roomId == null) {
      return const Center(
        child: Text('Room chat is unavailable without a room connection.'),
      );
    }
    return KeyedSubtree(
      key: ValueKey(_streamVersion),
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _messageStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Could not load room messages: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body(
                          size: 12, color: AppColors.roomTextMute)),
                  TextButton.icon(
                    onPressed: _retryRoomStreams,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final messages = snapshot.data!;
          if (messages.length != _lastMessageCount) {
            _lastMessageCount = messages.length;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_chatScrollController.hasClients) {
                _chatScrollController
                    .jumpTo(_chatScrollController.position.maxScrollExtent);
              }
            });
          }
          if (messages.isEmpty) {
            return Center(
              child: Text('No messages yet.',
                  style: AppTextStyles.body(
                      size: 12, color: AppColors.roomTextMute)),
            );
          }
          final currentUserId = Supabase.instance.client.auth.currentUser?.id;
          return ListView.builder(
            controller: _chatScrollController,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index];
              final userId = message['user_id']?.toString() ?? '';
              final isSelf = userId == currentUserId;
              final body = message['body']?.toString() ?? '';
              final createdAt =
                  DateTime.tryParse(message['created_at']?.toString() ?? '')
                      ?.toLocal();
              final time = createdAt == null
                  ? ''
                  : '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
              return Align(
                alignment:
                    isSelf ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 280),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelf
                        ? AppColors.greenDark.withValues(alpha: 0.45)
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isSelf ? 'You' : userId,
                          style: AppTextStyles.label(
                              size: 10, color: AppColors.green)),
                      const SizedBox(height: 3),
                      Text(body,
                          style: AppTextStyles.body(
                              size: 12, color: AppColors.roomText)),
                      if (time.isNotEmpty)
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(time,
                              style: AppTextStyles.label(
                                  size: 9, color: AppColors.roomTextMute)),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _inputBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.roomDeep,
        border: Border(top: BorderSide(color: Color(0x14FFFFFF))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              enabled: widget.roomId != null && !_sending,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              style: AppTextStyles.body(size: 12, color: AppColors.roomText),
              decoration: InputDecoration(
                hintText: 'Say something',
                hintStyle:
                    AppTextStyles.body(size: 12, color: AppColors.roomTextMute),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Send message',
            onPressed: _sending ? null : _sendMessage,
            icon: _sending
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded),
            color: AppColors.green,
          ),
          _inputIcon(Icons.mic_none_rounded, onTap: _showVoiceUnavailable),
          _inputIcon(Icons.card_giftcard_rounded, onTap: _openGiftPicker),
          _inputIcon(Icons.videogame_asset_rounded,
              onTap: () => _openSheet(context, const GameSheet())),
          _inputIcon(Icons.grid_view_rounded,
              onTap: () => _openSheet(context, const RoomToolsSheet())),
        ],
      ),
    );
  }

  Widget _inputIcon(IconData icon, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Icon(icon, size: 15, color: AppColors.roomText),
        ),
      ),
    );
  }
}
