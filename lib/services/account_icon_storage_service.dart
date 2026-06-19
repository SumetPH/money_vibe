import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AccountIconStorageService {
  static const String directoryName = 'account_icons';

  bool get isAuthenticated => true;

  bool isStoredIconUrl(String url) {
    if (url.isEmpty) return false;
    // ในโหมดออฟไลน์ รูปภาพที่บันทึกในเครื่องจะไม่ขึ้นต้นด้วย http
    return !url.startsWith('http://') && !url.startsWith('https://');
  }

  Future<String?> uploadAccountIcon({
    required String accountId,
    required Uint8List bytes,
    required String extension,
    required String contentType,
  }) async {
    if (bytes.isEmpty) return null;

    final sanitizedExtension = _normalizeExtension(extension);
    final filename = '${accountId}_${DateTime.now().millisecondsSinceEpoch}.$sanitizedExtension';

    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final targetDir = Directory(p.join(documentsDirectory.path, directoryName));
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      final file = File(p.join(targetDir.path, filename));
      await file.writeAsBytes(bytes);
      
      // คืนค่าเป็น absolute local path บนเครื่อง
      return file.path;
    } catch (e) {
      debugPrint('AccountIconStorageService: upload failed for $accountId: $e');
      return null;
    }
  }

  Future<bool> deleteAccountIcon(String url) async {
    if (url.isEmpty) return false;
    if (!isStoredIconUrl(url)) return false;

    try {
      final file = File(url);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
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
