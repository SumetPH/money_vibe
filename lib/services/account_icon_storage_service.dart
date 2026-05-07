import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountIconStorageService {
  static const String bucketName = 'account-icons';

  final SupabaseClient _client;

  AccountIconStorageService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  bool get isAuthenticated => _client.auth.currentUser != null;

  bool isStoredIconUrl(String url) {
    if (url.isEmpty) return false;
    return url.contains('/storage/v1/object/public/$bucketName/');
  }

  Future<String?> uploadAccountIcon({
    required String accountId,
    required Uint8List bytes,
    required String extension,
    required String contentType,
  }) async {
    if (!isAuthenticated || bytes.isEmpty) return null;

    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final sanitizedExtension = _normalizeExtension(extension);
    final path =
        '$userId/${accountId}_${DateTime.now().millisecondsSinceEpoch}.$sanitizedExtension';

    try {
      await _client.storage
          .from(bucketName)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType),
          );

      final publicUrl = _client.storage.from(bucketName).getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      debugPrint('AccountIconStorageService: upload failed for $accountId: $e');
      return null;
    }
  }

  Future<bool> deleteAccountIcon(String url) async {
    if (!isAuthenticated || url.isEmpty) return false;
    if (!isStoredIconUrl(url)) return false;

    try {
      // Extract path from URL
      // URL format: .../storage/v1/object/public/account-icons/{path}
      final prefix = '/storage/v1/object/public/$bucketName/';
      final startIndex = url.indexOf(prefix);
      if (startIndex == -1) return false;

      final path = url.substring(startIndex + prefix.length);
      await _client.storage.from(bucketName).remove([path]);
      return true;
    } catch (e) {
      debugPrint('AccountIconStorageService: delete failed: $e');
      return false;
    }
  }

  String _normalizeExtension(String extension) {
    final normalized = extension.trim().toLowerCase().replaceFirst('.', '');
    if (normalized == 'jpeg') return 'jpg';
    if (normalized == 'jpg' || normalized == 'png' || normalized == 'webp') {
      return normalized;
    }
    return 'png';
  }
}
