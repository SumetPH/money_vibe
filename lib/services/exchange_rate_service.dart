import 'dart:convert';
import 'package:http/http.dart' as http;

/// บริการจัดการอัตราแลกเปลี่ยนสกุลเงิน (Exchange Rate Service)
/// ใช้ข้อมูลจาก Frankfurter (อ้างอิง ECB) ซึ่งไม่ต้องใช้ API key
class ExchangeRateService {
  static const _frankfurterHost = 'api.frankfurter.dev';
  static const _requestTimeout = Duration(seconds: 10);

  const ExchangeRateService();

  /// ดึงอัตราแลกเปลี่ยน USD/THB ล่าสุด
  Future<double> fetchUsdThbRate() => fetchRateToThb('USD');

  /// ดึงอัตราแลกเปลี่ยนล่าสุด: 1 [currency] = x THB
  Future<double> fetchRateToThb(String currency) =>
      fetchRate(base: currency, quote: 'THB');

  /// ดึงอัตราแลกเปลี่ยนล่าสุด: 1 [base] = x [quote]
  Future<double> fetchRate({
    required String base,
    required String quote,
  }) async {
    if (base == quote) return 1.0;
    final uri = Uri.https(_frankfurterHost, '/v1/latest', {
      'base': base,
      'symbols': quote,
    });
    final response = await http.get(uri).timeout(_requestTimeout);
    if (response.statusCode != 200) {
      throw Exception('Exchange rate API ตอบกลับ ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final rate = (data['rates']?[quote] as num?)?.toDouble();
    if (rate == null || rate <= 0) {
      throw Exception('ไม่พบอัตราแลกเปลี่ยน $quote');
    }
    return rate;
  }
}
