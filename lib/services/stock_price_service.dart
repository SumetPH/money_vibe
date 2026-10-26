import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/stock_quote.dart';
import 'exchange_rate_service.dart';

export '../models/stock_quote.dart';

class StockCompanyProfile {
  final String name;
  final String logoUrl;

  const StockCompanyProfile({this.name = '', this.logoUrl = ''});
}

/// ราคาหุ้นจากแหล่งที่เลือก; company profile ใช้ Finnhub เสมอ
class StockPriceService {
  static const _finnhubHost = 'finnhub.io';
  static const _yahooProxyFunction = 'yahoo-quote';
  static const _maxConcurrentPriceRequests = 4;
  static const _maxPriceFetchAttempts = 3;
  static const _singlePriceTimeout = Duration(seconds: 12);
  static const _requestTimeout = Duration(seconds: 10);

  final String? _finnhubApiKey;
  final bool _useFinnhub;
  final ExchangeRateService _exchangeRateService;

  StockPriceService({
    String? finnhubApiKey,
    bool useFinnhub = true,
    ExchangeRateService exchangeRateService = const ExchangeRateService(),
  }) : _finnhubApiKey = finnhubApiKey,
       _useFinnhub = useFinnhub,
       _exchangeRateService = exchangeRateService;

  bool get isConfigured {
    final key = _finnhubApiKey;
    return key != null && key.isNotEmpty;
  }

  // บังคับที่ service ด้วย เพื่อไม่ให้ preference เก่าเปิด Yahoo ใน Store
  bool get useFinnhub => !AppConfig.canUseYahooPrices || _useFinnhub;
  bool get canFetchPrices => !useFinnhub || isConfigured;

  /// ดึงราคาปัจจุบันหลายหุ้นจากแหล่งที่เลือก
  Future<Map<String, double>> fetchPrices(List<String> tickers) async {
    final quotes = await fetchQuotes(tickers);
    return quotes.map((ticker, quote) => MapEntry(ticker, quote.price));
  }

  /// ราคาพร้อมเปอร์เซ็นต์เปลี่ยนแปลงเทียบราคาปิดครั้งก่อนจาก quote เดียวกัน
  Future<Map<String, StockQuote>> fetchQuotes(List<String> tickers) async {
    if (tickers.isEmpty || !canFetchPrices) return {};

    final pendingTickers = tickers.toSet().toList();
    final prices = <String, StockQuote>{};
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

  Future<Map<String, StockQuote>> _fetchPriceBatch(List<String> tickers) async {
    final prices = <String, StockQuote>{};

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
          (ticker) =>
              (useFinnhub
                      ? _fetchFinnhubQuote(ticker)
                      : _fetchYahooQuote(ticker))
                  .timeout(_singlePriceTimeout, onTimeout: () => null),
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

  Future<StockQuote?> _fetchYahooQuote(String ticker) async {
    if (!AppConfig.canUseYahooPrices) return null;
    if (kIsWeb) return _fetchYahooQuoteViaProxy(ticker);
    try {
      final uri = Uri.https(
        'query1.finance.yahoo.com',
        '/v8/finance/chart/$ticker',
        {'interval': '1d', 'range': '1d'},
      );
      // shortcut: endpoint ไม่เป็นทางการ; เปลี่ยนแหล่งราคาหาก Yahoo เลิกรองรับ
      final response = await http.get(uri).timeout(_requestTimeout);
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final chart = data['chart'] as Map<String, dynamic>?;
      if (chart == null || chart['error'] != null) return null;
      final results = chart['result'] as List?;
      if (results == null || results.isEmpty) return null;
      final result = results.first as Map<String, dynamic>;
      final meta = result['meta'] as Map<String, dynamic>?;
      return meta == null ? null : StockQuote.fromYahooMeta(meta);
    } catch (_) {
      return null;
    }
  }

  // Yahoo ไม่ส่ง CORS header จึงให้ Flutter Web เรียกผ่าน edge function แทน
  Future<StockQuote?> _fetchYahooQuoteViaProxy(String ticker) async {
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentUser == null) return null;
      final response = await client.functions
          .invoke(_yahooProxyFunction, body: {'ticker': ticker})
          .timeout(_requestTimeout);
      final data = response.data;
      if (data is! Map<String, dynamic>) return null;
      final meta = data['meta'];
      return meta is Map<String, dynamic>
          ? StockQuote.fromYahooMeta(meta)
          : null;
    } catch (e) {
      debugPrint('StockPriceService: yahoo proxy $ticker error: $e');
      return null;
    }
  }

  Future<StockQuote?> _fetchFinnhubQuote(String ticker) async {
    try {
      final uri = _finnhubUri('/api/v1/quote', ticker);
      final response = await http.get(uri).timeout(_requestTimeout);
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return StockQuote.fromJson(data);
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
