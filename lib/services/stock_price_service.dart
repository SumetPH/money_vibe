import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/settings_provider.dart';
import 'exchange_rate_service.dart';

class StockCompanyProfile {
  final String name;
  final String logoUrl;

  const StockCompanyProfile({this.name = '', this.logoUrl = ''});
}

class StockPriceService {
  static const _finnhubBase = 'https://finnhub.io/api/v1';
  static const _maxConcurrentPriceRequests = 4;
  static const _maxPriceFetchAttempts = 3;
  static const _singlePriceTimeout = Duration(seconds: 12);

  final String? _finnhubApiKey;
  final bool _useFinnhub;
  final bool _useYahooExtendedHoursPrice;
  final ExchangeRateSource _exchangeRateSource;

  late final supabase = Supabase.instance.client;
  late final _exchangeRateService = ExchangeRateService(
    source: _exchangeRateSource,
  );

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

    final pendingTickers = tickers.toSet().toList();
    final prices = <String, double>{};
    for (
      var attempt = 0;
      attempt < _maxPriceFetchAttempts && pendingTickers.isNotEmpty;
      attempt++
    ) {
      prices.addAll(await _fetchPriceBatch(pendingTickers));
      pendingTickers.removeWhere(prices.containsKey);

      if (pendingTickers.isNotEmpty && attempt < _maxPriceFetchAttempts - 1) {
        await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
      }
    }
    return prices;
  }

  Future<Map<String, double>> _fetchPriceBatch(List<String> tickers) async {
    final prices = <String, double>{};

    for (
      var start = 0;
      start < tickers.length;
      start += _maxConcurrentPriceRequests
    ) {
      final end = start + _maxConcurrentPriceRequests < tickers.length
          ? start + _maxConcurrentPriceRequests
          : tickers.length;
      final batch = tickers.sublist(start, end);
      final results = await Future.wait(
        batch.map(
          (ticker) => _fetchSinglePrice(
            ticker,
          ).timeout(_singlePriceTimeout, onTimeout: () => null),
        ),
        eagerError: false,
      );

      for (var i = 0; i < batch.length; i++) {
        final price = results[i];
        if (price != null) prices[batch[i]] = price;
      }
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
      final quotes =
          (result['indicators']?['quote'] as List?)?.first
              as Map<String, dynamic>?;
      final closes = quotes?['close'];
      if (closes is List) {
        for (var i = closes.length - 1; i >= 0; i--) {
          final close = closes[i];
          if (close is num && close > 0) {
            return close.toDouble();
          }
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

  /// ดึงอัตราแลกเปลี่ยน USD/THB (Delegated to ExchangeRateService)
  Future<double> fetchUsdThbRateFrankfurter() =>
      _exchangeRateService.fetchUsdThbRateFrankfurter();

  Future<double> fetchUsdThbRateYahoo() =>
      _exchangeRateService.fetchUsdThbRateYahoo();

  Future<double> fetchUsdThbRate() => _exchangeRateService.fetchUsdThbRate();
}
