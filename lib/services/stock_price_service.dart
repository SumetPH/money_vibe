import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'exchange_rate_service.dart';

class StockCompanyProfile {
  final String name;
  final String logoUrl;

  const StockCompanyProfile({this.name = '', this.logoUrl = ''});
}

/// ดึงราคาหุ้นและ company profile จาก Finnhub (ต้องมี API key ของผู้ใช้)
class StockPriceService {
  static const _finnhubHost = 'finnhub.io';
  static const _maxConcurrentPriceRequests = 4;
  static const _maxPriceFetchAttempts = 3;
  static const _singlePriceTimeout = Duration(seconds: 12);
  static const _requestTimeout = Duration(seconds: 10);

  final String? _finnhubApiKey;
  final ExchangeRateService _exchangeRateService;

  StockPriceService({
    String? finnhubApiKey,
    ExchangeRateService exchangeRateService = const ExchangeRateService(),
  }) : _finnhubApiKey = finnhubApiKey,
       _exchangeRateService = exchangeRateService;

  bool get isConfigured {
    final key = _finnhubApiKey;
    return key != null && key.isNotEmpty;
  }

  /// ดึงราคาปัจจุบันหลายหุ้นพร้อมกัน; คืน map ว่างถ้ายังไม่ได้ตั้งค่า Finnhub
  Future<Map<String, double>> fetchPrices(List<String> tickers) async {
    if (tickers.isEmpty || !isConfigured) return {};

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
          (ticker) => _fetchFinnhubPrice(
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

  Future<double?> _fetchFinnhubPrice(String ticker) async {
    try {
      final uri = _finnhubUri('/api/v1/quote', ticker);
      final response = await http.get(uri).timeout(_requestTimeout);
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
      final uri = _finnhubUri('/api/v1/stock/profile2', ticker);
      final response = await http.get(uri).timeout(_requestTimeout);
      if (response.statusCode != 200) {
        debugPrint(
          'StockPriceService: profile $ticker failed (${response.statusCode})',
        );
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final name = (data['name'] as String? ?? '').trim();
      final logoUrl = (data['logo'] as String? ?? '').trim();

      if (name.isEmpty && logoUrl.isEmpty) return null;
      return StockCompanyProfile(name: name, logoUrl: logoUrl);
    } catch (e) {
      debugPrint('StockPriceService: profile $ticker error: $e');
      return null;
    }
  }

  /// สร้าง URL ของ Finnhub โดย encode query ให้ถูกต้อง
  Uri _finnhubUri(String path, String ticker) => Uri.https(_finnhubHost, path, {
    'symbol': ticker,
    'token': _finnhubApiKey ?? '',
  });

  /// ดึงอัตราแลกเปลี่ยน USD/THB (Delegated to ExchangeRateService)
  Future<double> fetchUsdThbRate() => _exchangeRateService.fetchUsdThbRate();
}
