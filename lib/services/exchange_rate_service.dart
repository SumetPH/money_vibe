import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class _CachedRates {
  final DateTime timestamp;
  final Map<String, double> rates;

  const _CachedRates({required this.timestamp, required this.rates});

  bool isFresh(Duration ttl) => DateTime.now().difference(timestamp) < ttl;

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.millisecondsSinceEpoch,
    'rates': rates,
  };

  factory _CachedRates.fromJson(Map<String, dynamic> json) {
    final ts = DateTime.fromMillisecondsSinceEpoch(
      json['timestamp'] as int? ?? 0,
    );
    final rawRates = json['rates'] as Map<String, dynamic>? ?? {};
    final rates = <String, double>{};
    for (final entry in rawRates.entries) {
      if (entry.value is num) {
        rates[entry.key] = (entry.value as num).toDouble();
      }
    }
    return _CachedRates(timestamp: ts, rates: rates);
  }
}

/// บริการจัดการอัตราแลกเปลี่ยนสกุลเงิน (Exchange Rate Service)
/// - Primary API: ExchangeRate-API (open.er-api.com) ครอบคลุม 160+ สกุลเงิน ทำงานบน Global CDN รวดเร็วและเสถียร
/// - Fallback API: Frankfurter (api.frankfurter.dev) จากฐานข้อมูล ECB
/// - Caching: แคชทั้งระดับ In-memory และ SharedPreferences (TTL 6 ชั่วโมง)
/// - Stale Cache: หากเครือข่ายมีปัญหาทั้ง 2 API จะดึงค่าล่าสุดจากแคชที่เคยมีมาใช้แทน
class ExchangeRateService {
  static const _openErApiHost = 'open.er-api.com';
  static const _frankfurterHost = 'api.frankfurter.dev';
  static const _requestTimeout = Duration(milliseconds: 3500); // 3.5 วินาที
  static const _cacheTtl = Duration(hours: 6);
  static const _cacheKeyPrefix = 'exchange_rate_cache_v1_';

  // In-memory cache สำหรับแต่ละสกุลเงินหลัก (base currency)
  static final Map<String, _CachedRates> _memoryCache = {};

  // ป้องกันการยิง request ซ้ำซ้อนพร้อมกันในเสี้ยววินาทีเดียวกัน
  static final Map<String, Future<Map<String, double>>> _inFlightRequests = {};

  final http.Client? _client;

  const ExchangeRateService({http.Client? client}) : _client = client;

  /// ปัดเศษอัตราแลกเปลี่ยนให้เหลือทศนิยม 4 ตำแหน่ง
  /// สอดคล้องกับ schema ของ Database numeric(15, 4) และมาตรฐานอัตราแลกเปลี่ยนทางการ
  static double roundRate(double rate) {
    return double.parse(rate.toStringAsFixed(4));
  }

  /// ดึงอัตราแลกเปลี่ยน USD/THB ล่าสุด
  Future<double> fetchUsdThbRate({bool forceRefresh = false}) =>
      fetchRateToThb('USD', forceRefresh: forceRefresh);

  /// ดึงอัตราแลกเปลี่ยนล่าสุด: 1 [currency] = x THB
  Future<double> fetchRateToThb(String currency, {bool forceRefresh = false}) =>
      fetchRate(base: currency, quote: 'THB', forceRefresh: forceRefresh);

  /// ดึงอัตราแลกเปลี่ยนล่าสุด: 1 [base] = x [quote]
  Future<double> fetchRate({
    required String base,
    required String quote,
    bool forceRefresh = false,
  }) async {
    final normalizedBase = base.toUpperCase().trim();
    final normalizedQuote = quote.toUpperCase().trim();

    if (normalizedBase == normalizedQuote) return 1.0;

    // 1. ตรวจสอบ Fresh Cache (ถ้าไม่ได้สั่ง forceRefresh)
    if (!forceRefresh) {
      final cachedRate = await _getCachedRate(normalizedBase, normalizedQuote);
      if (cachedRate != null) {
        return cachedRate;
      }
    }

    // 2. ดึงจาก Network (Primary -> Fallback)
    final rates = await _fetchRatesWithFallback(
      base: normalizedBase,
      quote: normalizedQuote,
    );

    final rate = rates[normalizedQuote];
    if (rate == null || rate <= 0) {
      throw Exception(
        'ไม่พบอัตราแลกเปลี่ยน $normalizedQuote จากฐาน $normalizedBase',
      );
    }
    return roundRate(rate);
  }

  /// อ่านค่าจาก memory cache หรือ SharedPreferences หากยังไม่หมดอายุ
  Future<double?> _getCachedRate(String base, String quote) async {
    // 1. In-memory
    final mem = _memoryCache[base];
    if (mem != null && mem.isFresh(_cacheTtl) && mem.rates.containsKey(quote)) {
      return mem.rates[quote];
    }

    // 2. SharedPreferences
    final persisted = await _loadFromPrefs(base);
    if (persisted != null) {
      _memoryCache[base] = persisted;
      if (persisted.isFresh(_cacheTtl) && persisted.rates.containsKey(quote)) {
        return persisted.rates[quote];
      }
    }

    return null;
  }

  /// ดึงอัตราแลกเปลี่ยนพร้อม Deduplication และ Fallback chain
  Future<Map<String, double>> _fetchRatesWithFallback({
    required String base,
    required String quote,
  }) {
    final existingFuture = _inFlightRequests[base];
    if (existingFuture != null) {
      return existingFuture;
    }

    final future = _executeFetchWithFallback(base: base, quote: quote);
    _inFlightRequests[base] = future;
    return future.whenComplete(() {
      _inFlightRequests.remove(base);
    });
  }

  Future<Map<String, double>> _executeFetchWithFallback({
    required String base,
    required String quote,
  }) async {
    Map<String, double>? fetchedRates;
    Object? primaryError;

    // Step 1: ลอง Primary API (ExchangeRate-API)
    try {
      fetchedRates = await _fetchFromOpenErApi(base: base, client: _client);
    } catch (e) {
      primaryError = e;
      debugPrint(
        'ExchangeRateService: Primary API (open.er-api.com) failed: $e',
      );
    }

    // Step 2: ลอง Fallback API (Frankfurter) หาก Primary ล้มเหลว หรือไม่มี quote นั้น
    if (fetchedRates == null || !fetchedRates.containsKey(quote)) {
      try {
        debugPrint(
          'ExchangeRateService: Attempting fallback to Frankfurter for $base/$quote...',
        );
        final fallbackRates = await _fetchFromFrankfurter(
          base: base,
          quote: quote,
          client: _client,
        );
        fetchedRates = {...?fetchedRates, ...fallbackRates};
      } catch (e) {
        debugPrint(
          'ExchangeRateService: Fallback API (Frankfurter) also failed: $e',
        );
      }
    }

    // ถ้าดึงสำเร็จอย่างน้อย 1 แหล่ง -> บันทึกลง cache ทันที
    if (fetchedRates != null && fetchedRates.isNotEmpty) {
      final now = DateTime.now();
      final existingRates = _memoryCache[base]?.rates ?? {};
      final mergedRates = Map<String, double>.from(existingRates)
        ..addAll(fetchedRates);
      final cacheEntry = _CachedRates(timestamp: now, rates: mergedRates);

      _memoryCache[base] = cacheEntry;
      unawaited(_saveToPrefs(base, cacheEntry));
      return mergedRates;
    }

    // Step 3: หาก API ทั้งสองล้มเหลว -> ใช้ Stale Cache (แม้จะหมดอายุแล้วก็ตาม)
    final stale = _memoryCache[base] ?? await _loadFromPrefs(base);
    if (stale != null && stale.rates.containsKey(quote)) {
      debugPrint(
        'ExchangeRateService: Using stale cached rate for $base/$quote (as of ${stale.timestamp})',
      );
      return stale.rates;
    }

    // Step 4: หากไม่มีแคชเลย -> แจ้งข้อผิดพลาด
    throw Exception('ไม่สามารถดึงอัตราแลกเปลี่ยนได้: $primaryError');
  }

  /// Primary: ExchangeRate-API (open.er-api.com)
  Future<Map<String, double>> _fetchFromOpenErApi({
    required String base,
    http.Client? client,
  }) async {
    final uri = Uri.https(_openErApiHost, '/v6/latest/$base');
    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient.get(uri).timeout(_requestTimeout);
      if (response.statusCode != 200) {
        throw Exception('ExchangeRate-API ตอบกลับ ${response.statusCode}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['result'] != 'success') {
        final errorType = data['error-type'] ?? 'unknown';
        throw Exception('ExchangeRate-API แจ้งข้อผิดพลาด: $errorType');
      }
      final rawRates = data['rates'] as Map<String, dynamic>? ?? {};
      final rates = <String, double>{};
      for (final entry in rawRates.entries) {
        if (entry.value is num) {
          rates[entry.key] = roundRate((entry.value as num).toDouble());
        }
      }
      if (rates.isEmpty) {
        throw Exception('ไม่พบอัตราแลกเปลี่ยนในผลลัพธ์');
      }
      return rates;
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Fallback: Frankfurter (api.frankfurter.dev)
  Future<Map<String, double>> _fetchFromFrankfurter({
    required String base,
    required String quote,
    http.Client? client,
  }) async {
    final uri = Uri.https(_frankfurterHost, '/v1/latest', {
      'base': base,
      'symbols': quote,
    });
    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient.get(uri).timeout(_requestTimeout);
      if (response.statusCode != 200) {
        throw Exception('Frankfurter ตอบกลับ ${response.statusCode}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final rawRates = data['rates'] as Map<String, dynamic>? ?? {};
      final rates = <String, double>{};
      for (final entry in rawRates.entries) {
        if (entry.value is num) {
          rates[entry.key] = roundRate((entry.value as num).toDouble());
        }
      }
      if (rates.isEmpty) {
        throw Exception('ไม่พบอัตราแลกเปลี่ยนจาก Frankfurter');
      }
      return rates;
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  Future<_CachedRates?> _loadFromPrefs(String base) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('$_cacheKeyPrefix$base');
      if (jsonStr == null || jsonStr.isEmpty) return null;
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return _CachedRates.fromJson(json);
    } catch (e) {
      debugPrint('ExchangeRateService: Failed to read cache from prefs: $e');
      return null;
    }
  }

  Future<void> _saveToPrefs(String base, _CachedRates cachedRates) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(cachedRates.toJson());
      await prefs.setString('$_cacheKeyPrefix$base', jsonStr);
    } catch (e) {
      debugPrint('ExchangeRateService: Failed to save cache to prefs: $e');
    }
  }

  @visibleForTesting
  static void clearCache() {
    _memoryCache.clear();
    _inFlightRequests.clear();
  }
}
