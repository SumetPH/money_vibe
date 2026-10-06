import 'dart:convert';
import 'package:http/http.dart' as http;

/// บริการจัดการอัตราแลกเปลี่ยนสกุลเงิน (Exchange Rate Service)
/// ใช้ข้อมูลจาก Frankfurter (อ้างอิง ECB) ซึ่งไม่ต้องใช้ API key
class ExchangeRateService {
  static const _frankfurterHost = 'api.frankfurter.dev';
  static const _requestTimeout = Duration(seconds: 10);

  const ExchangeRateService();

  /// ดึงอัตราแลกเปลี่ยน USD/THB ล่าสุด
  Future<double> fetchUsdThbRate() async {
    final uri = Uri.https(_frankfurterHost, '/v1/latest', {
      'base': 'USD',
      'symbols': 'THB',
    });
    final response = await http.get(uri).timeout(_requestTimeout);
    if (response.statusCode != 200) {
      throw Exception('Exchange rate API ตอบกลับ ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final rate = (data['rates']?['THB'] as num?)?.toDouble();
    if (rate == null || rate <= 0) {
      throw Exception('ไม่พบอัตราแลกเปลี่ยน THB');
    }
    return rate;
  }
}
