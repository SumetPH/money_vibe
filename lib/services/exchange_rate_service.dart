import 'dart:convert';
import 'package:http/http.dart' as http;
import '../providers/settings_provider.dart';

/// บริการจัดการอัตราแลกเปลี่ยนสกุลเงิน (Exchange Rate Service)
/// แยกรับผิดชอบออกมาจาก StockPriceService เพื่อเพิ่ม Locality และ Leverage
class ExchangeRateService {
  static const _frankfurterBase = 'https://api.frankfurter.dev/v1';

  final ExchangeRateSource _source;

  ExchangeRateService({ExchangeRateSource source = ExchangeRateSource.yahoo})
    : _source = source;

  /// ดึงอัตราแลกเปลี่ยน USD/THB ล่าสุดจากแหล่งที่กำหนด
  Future<double> fetchUsdThbRate() {
    return _source == ExchangeRateSource.frankfurter
        ? fetchUsdThbRateFrankfurter()
        : fetchUsdThbRateYahoo();
  }

  /// ดึงอัตราแลกเปลี่ยนผ่าน API ของ Frankfurter (ไม่ต้องใช้ API key)
  Future<double> fetchUsdThbRateFrankfurter() async {
    final uri = Uri.parse('$_frankfurterBase/latest?base=USD&symbols=THB');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Exchange rate API ตอบกลับ ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final rate = (data['rates']?['THB'] as num?)?.toDouble();
    if (rate == null) throw Exception('ไม่พบอัตราแลกเปลี่ยน THB');
    return rate;
  }

  /// ดึงอัตราแลกเปลี่ยนตรงผ่าน Yahoo Finance API (Client-only)
  Future<double> fetchUsdThbRateYahoo() async {
    final uri = Uri.parse(
      'https://query1.finance.yahoo.com/v8/finance/chart/THB=X?interval=1m&range=1d&includePrePost=false',
    );
    final response = await http.get(
      uri,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Yahoo Finance API ตอบกลับด้วยสถานะ ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final result =
        (data['chart']?['result'] as List?)?.first as Map<String, dynamic>?;
    final meta = result?['meta'] as Map<String, dynamic>?;
    final regularMarketPrice = (meta?['regularMarketPrice'] as num?)
        ?.toDouble();
    final rate = (regularMarketPrice ?? 0);
    if (rate <= 0) {
      throw Exception('ไม่พบอัตราแลกเปลี่ยน USD/THB');
    }

    return rate;
  }
}
