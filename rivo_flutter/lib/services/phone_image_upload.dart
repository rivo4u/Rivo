import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PhoneImageUpload {
  PhoneImageUpload(this.client);

  static const legacyBucket = 'rivo-media';
  static const avatarsBucket = 'avatars';
  static const momentsBucket = 'moments';
  static const roomsBucket = 'rooms';
  static final ImagePicker _picker = ImagePicker();

  final SupabaseClient client;

  Future<XFile?> pick() => _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 84,
      );

  Future<String> upload(XFile image,
      {required String bucket, required String path}) async {
    final bytes = await image.readAsBytes();
    await client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );
    return path;
  }

  String? publicUrl(Object? path, {required String bucket}) {
    if (path == null || path.toString().isEmpty) return null;
    final imagePath = path.toString();
    final actualBucket = _isLegacyPath(imagePath) ? legacyBucket : bucket;
    return client.storage.from(actualBucket).getPublicUrl(imagePath);
  }

  Future<void> remove(Object? path, {required String bucket}) async {
    if (path == null || path.toString().isEmpty) return;
    final imagePath = path.toString();
    final actualBucket = _isLegacyPath(imagePath) ? legacyBucket : bucket;
    await client.storage.from(actualBucket).remove([imagePath]);
  }

  bool _isLegacyPath(String path) =>
      path.startsWith('profiles/') ||
      path.startsWith('moments/') ||
      path.startsWith('rooms/');
}
