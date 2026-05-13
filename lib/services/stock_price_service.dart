import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/settings_provider.dart';

class StockCompanyProfile {
  final String name;
  final String logoUrl;

  const StockCompanyProfile({this.name = '', this.logoUrl = ''});
}

class StockPriceService {
  static const _finnhubBase = 'https://finnhub.io/api/v1';
  static const _frankfurterBase = 'https://api.frankfurter.dev/v1';

  final String? _finnhubApiKey;
  final bool _useFinnhub;
  final bool _useYahooExtendedHoursPrice;
  final ExchangeRateSource _exchangeRateSource;

  late final supabase = Supabase.instance.client;

  StockPriceService({
    String? finnhubApiKey,
    bool useFinnhub = false,
    bool useYahooExtendedHoursPrice = true,
    ExchangeRateSource exchangeRateSource = ExchangeRateSource.yahoo,
  }) : _finnhubApiKey = finnhubApiKey,
       _useFinnhub = useFinnhub,
       _useYahooExtendedHoursPrice = useYahooExtendedHoursPrice,
       _exchangeRateSource = exchangeRateSource;

  bool get isConfigured {
    final key = _finnhubApiKey;
    return key != null && key.isNotEmpty;
  }

  /// ดึงราคาปัจจุบันหลายหุ้นพร้อมกัน (Yahoo หรือ Finnhub ตาม toggle)
  Future<Map<String, double>> fetchPrices(List<String> tickers) async {
    if (tickers.isEmpty) return {};

    final results = await Future.wait(
      tickers.map(_fetchSinglePrice),
      eagerError: false,
    );

    final prices = <String, double>{};
    for (int i = 0; i < tickers.length; i++) {
      if (results[i] != null) prices[tickers[i]] = results[i]!;
    }
    return prices;
  }

  Future<double?> _fetchSinglePrice(String ticker) {
    return _useFinnhub && isConfigured
        ? _fetchFinnhubPrice(ticker)
        : _fetchYahooPrice(ticker);
  }

  Future<double?> _fetchYahooPrice(String ticker) async {
    try {
      final res = await supabase.functions.invoke(
        'yfinance',
        body: {
          "symbol": ticker,
          "interval": "1m",
          "range": "1d",
          "includePrePost": _useYahooExtendedHoursPrice,
        },
      );

      final data = res.data;

      final result =
          (data['chart']?['result'] as List?)?.first as Map<String, dynamic>?;
      if (result == null) return null;

      final meta = result['meta'] as Map<String, dynamic>?;
      if (meta == null) return null;

      final regularPrice = (meta['regularMarketPrice'] as num?)?.toDouble();
      if (regularPrice == null || regularPrice <= 0) return null;

      if (!_useYahooExtendedHoursPrice) {
        return regularPrice;
      }

      // ใช้ราคาจาก candle ล่าสุด — รวม pre/regular/post ทุกช่วงตลาด
      final timestamps = (result['timestamp'] as List?)?.cast<num>();
      final quotes =
          (result['indicators']?['quote'] as List?)?.first
              as Map<String, dynamic>?;
      if (timestamps != null && timestamps.isNotEmpty && quotes != null) {
        final closes = (quotes['close'] as List?)?.cast<num>();
        if (closes != null && closes.isNotEmpty) {
          final lastClose = closes.last.toDouble();
          if (lastClose > 0) return lastClose;
        }
      }

      return regularPrice;
    } catch (_) {
      return null;
    }
  }

  Future<double?> _fetchFinnhubPrice(String ticker) async {
    try {
      final uri = Uri.parse(
        '$_finnhubBase/quote?symbol=$ticker&token=$_finnhubApiKey',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final price = (data['c'] as num?)?.toDouble();
      return (price != null && price > 0) ? price : null;
    } catch (_) {
      return null;
    }
  }

  /// ดึง company profile หลายตัวพร้อมกันเพื่อใช้ชื่อ/โลโก้ (Finnhub ต้องมี API key)
  Future<Map<String, StockCompanyProfile>> fetchProfiles(
    List<String> tickers,
  ) async {
    if (tickers.isEmpty || !isConfigured) return {};

    final uniqueTickers = tickers.toSet().toList();
    final results = await Future.wait(
      uniqueTickers.map(_fetchSingleProfile),
      eagerError: false,
    );

    final profiles = <String, StockCompanyProfile>{};
    for (int i = 0; i < uniqueTickers.length; i++) {
      final profile = results[i];
      if (profile != null) profiles[uniqueTickers[i]] = profile;
    }
    return profiles;
  }

  Future<StockCompanyProfile?> fetchProfile(String ticker) async {
    if (!isConfigured) return null;
    return _fetchSingleProfile(ticker);
  }

  Future<StockCompanyProfile?> _fetchSingleProfile(String ticker) async {
    try {
      final uri = Uri.parse(
        '$_finnhubBase/stock/profile2?symbol=$ticker&token=$_finnhubApiKey',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final name = (data['name'] as String? ?? '').trim();
      final logoUrl = (data['logo'] as String? ?? '').trim();

      if (name.isEmpty && logoUrl.isEmpty) return null;
      return StockCompanyProfile(name: name, logoUrl: logoUrl);
    } catch (_) {
      return null;
    }
  }

  /// ดึงอัตราแลกเปลี่ยน USD/THB (ไม่ต้อง API key)
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

  Future<double> fetchUsdThbRateYahoo() async {
    final res = await supabase.functions.invoke(
      'yfinance',
      body: {
        "symbol": "THB=X",
        "interval": "1m",
        "range": "1d",
        "includePrePost": false,
      },
    );

    final data = res.data;

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

  Future<double> fetchUsdThbRate() {
    return _exchangeRateSource == ExchangeRateSource.frankfurter
        ? fetchUsdThbRateFrankfurter()
        : fetchUsdThbRateYahoo();
  }
}
