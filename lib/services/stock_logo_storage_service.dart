import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StockLogoStorageService {
  static const String bucketName = 'stock-logos';
  static const String _functionName = 'mirror-stock-logo';

  final SupabaseClient _client;

  StockLogoStorageService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  bool get isAuthenticated => _client.auth.currentUser != null;

  bool isStoredLogoUrl(String url) {
    if (url.isEmpty) return false;
    return url.contains('/storage/v1/object/public/$bucketName/');
  }

  Future<String?> uploadLogoBytes({
    required String ticker,
    required Uint8List bytes,
    required String extension,
    required String contentType,
  }) async {
    if (!isAuthenticated || bytes.isEmpty) return null;

    final userId = _client.auth.currentUser?.id;
    final normalizedTicker = _normalizeTicker(ticker);
    if (userId == null || normalizedTicker == null) return null;

    final sanitizedExtension = _normalizeExtension(extension);
    final path =
        '$userId/${normalizedTicker}_${DateTime.now().millisecondsSinceEpoch}.$sanitizedExtension';

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
      debugPrint('StockLogoStorageService: upload failed for $ticker: $e');
      return null;
    }
  }

  Future<String?> mirrorLogo({
    required String ticker,
    required String sourceUrl,
  }) async {
    if (!isAuthenticated || sourceUrl.isEmpty) return null;

    try {
      final response = await _client.functions.invoke(
        _functionName,
        body: {'ticker': ticker, 'sourceUrl': sourceUrl},
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        final publicUrl = data['publicUrl'] as String?;
        if (publicUrl != null && publicUrl.isNotEmpty) {
          return publicUrl;
        }
      }
    } catch (e) {
      debugPrint('StockLogoStorageService: mirror failed for $ticker: $e');
    }

    return null;
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
