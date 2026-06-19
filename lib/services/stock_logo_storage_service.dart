import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class StockLogoStorageService {
  static const String directoryName = 'stock_logos';

  bool get isAuthenticated => true;

  bool isStoredLogoUrl(String url) {
    if (url.isEmpty) return false;
    return !url.startsWith('http://') && !url.startsWith('https://');
  }

  Future<String?> uploadLogoBytes({
    required String ticker,
    required Uint8List bytes,
    required String extension,
    required String contentType,
  }) async {
    if (bytes.isEmpty) return null;

    final normalizedTicker = _normalizeTicker(ticker);
    if (normalizedTicker == null) return null;

    final sanitizedExtension = _normalizeExtension(extension);
    final filename = '${normalizedTicker}_${DateTime.now().millisecondsSinceEpoch}.$sanitizedExtension';

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
      debugPrint('StockLogoStorageService: upload failed for $ticker: $e');
      return null;
    }
  }

  Future<String?> mirrorLogo({
    required String ticker,
    required String sourceUrl,
  }) async {
    if (sourceUrl.isEmpty) return null;

    try {
      final uri = Uri.parse(sourceUrl);
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        debugPrint('StockLogoStorageService: mirror fetch failed (${response.statusCode}) for $ticker');
        return null;
      }

      final contentType = response.headers['content-type'] ?? 'image/png';
      final extension = _getExtensionFromContentType(contentType, sourceUrl);
      
      return await uploadLogoBytes(
        ticker: ticker,
        bytes: response.bodyBytes,
        extension: extension,
        contentType: contentType,
      );
    } catch (e) {
      debugPrint('StockLogoStorageService: mirror failed for $ticker: $e');
    }

    return null;
  }

  String _getExtensionFromContentType(String contentType, String sourceUrl) {
    if (contentType.contains('svg')) return 'svg';
    if (contentType.contains('webp')) return 'webp';
    if (contentType.contains('jpeg') || contentType.contains('jpg')) return 'jpg';
    if (contentType.contains('png')) return 'png';

    try {
      final pathname = Uri.parse(sourceUrl).path.toLowerCase();
      final segments = pathname.split('.');
      final fromPath = segments.length > 1 ? segments.last : null;
      if (fromPath != null && ['png', 'jpg', 'jpeg', 'webp', 'svg'].contains(fromPath)) {
        return fromPath == 'jpeg' ? 'jpg' : fromPath;
      }
    } catch (_) {}

    return 'png';
  }

  String? _normalizeTicker(String ticker) {
    final normalized = ticker.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9.\-]{1,15}$').hasMatch(normalized)) {
      return null;
    }
    return normalized;
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
