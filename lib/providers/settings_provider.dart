import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/theme_color_option.dart';

class SettingsProvider extends ChangeNotifier {
  static const _secureStorage = FlutterSecureStorage();
  static const _finnhubApiKeyKey = 'finnhub_api_key';
  // key ของฟีเจอร์ Yahoo/LLM ที่ถูกถอดออกแล้ว ลบทิ้งตอนโหลดเพื่อไม่ให้ API key ค้างในเครื่อง
  static const _removedFeatureKeys = [
    'price_source_finnhub',
    'yahoo_extended_hours_price',
    'exchange_rate_source',
    'llm_api_key',
    'llm_base_url',
    'llm_model',
  ];
  static const _darkModeKey = 'dark_mode';
  static const _themeColorKey = 'theme_color';
  static const _monthlyCycleStartDayKey = 'budget_start_day';
  static const _cashFlowAnchorDayKey = 'cash_flow_anchor_day';
  static const _legacyStatisticsStartDayKey = 'statistics_start_day';
  static const _netWorthFilterKey = 'net_worth_filter_ids';

  String? _finnhubApiKey;
  bool _isDarkMode = true;
  ThemeColorOption _themeColor = ThemeColorOption.classic;
  bool _isLoaded = false;
  int _monthlyCycleStartDay = 1;
  int? _cashFlowAnchorDay; // วันเคลียร์ยอดของการคาดการณ์; null = ยังไม่ได้ตั้ง
  Set<String>? _netWorthFilterIds; // null = all accounts

  String? get finnhubApiKey => _finnhubApiKey;
  bool get isDarkMode => _isDarkMode;
  ThemeColorOption get themeColor => _themeColor;
  bool get isLoaded => _isLoaded;
  int get monthlyCycleStartDay => _monthlyCycleStartDay;
  int? get cashFlowAnchorDay => _cashFlowAnchorDay;
  Set<String>? get netWorthFilterIds =>
      _netWorthFilterIds == null ? null : Set.unmodifiable(_netWorthFilterIds!);

  bool get isFinnhubConfigured =>
      _finnhubApiKey != null && _finnhubApiKey!.isNotEmpty;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _finnhubApiKey = await _loadFinnhubApiKey(prefs);
    await Future.wait(_removedFeatureKeys.map(prefs.remove));
    _isDarkMode = prefs.getBool(_darkModeKey) ?? true;
    _themeColor = ThemeColorOption.byId(prefs.getString(_themeColorKey));
    _monthlyCycleStartDay =
        prefs.getInt(_monthlyCycleStartDayKey) ??
        prefs.getInt(_legacyStatisticsStartDayKey) ??
        1;
    _cashFlowAnchorDay = prefs.getInt(_cashFlowAnchorDayKey);
    final filterJson = prefs.getString(_netWorthFilterKey);
    if (filterJson != null) {
      final list = jsonDecode(filterJson) as List;
      _netWorthFilterIds = list.cast<String>().toSet();
    }
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> setNetWorthFilterIds(Set<String>? ids) async {
    final prefs = await SharedPreferences.getInstance();
    if (ids == null) {
      await prefs.remove(_netWorthFilterKey);
      _netWorthFilterIds = null;
    } else {
      await prefs.setString(_netWorthFilterKey, jsonEncode(ids.toList()));
      _netWorthFilterIds = Set.from(ids);
    }
    notifyListeners();
  }

  Future<void> setMonthlyCycleStartDay(int day) async {
    if (day < 1 || day > 31) {
      throw ArgumentError.value(day, 'day', 'must be between 1 and 31');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_monthlyCycleStartDayKey, day);
    _monthlyCycleStartDay = day;
    notifyListeners();
  }

  /// วันเคลียร์ยอด (anchor day) ของ Cash-flow forecast (เก็บในเครื่อง); null = ล้างค่า
  Future<void> setCashFlowAnchorDay(int? day) async {
    if (day != null && (day < 1 || day > 31)) {
      throw ArgumentError.value(day, 'day', 'must be between 1 and 31');
    }
    final prefs = await SharedPreferences.getInstance();
    if (day == null) {
      await prefs.remove(_cashFlowAnchorDayKey);
    } else {
      await prefs.setInt(_cashFlowAnchorDayKey, day);
    }
    _cashFlowAnchorDay = day;
    notifyListeners();
  }

  Future<void> setFinnhubApiKey(String? apiKey) async {
    final trimmed = apiKey?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await _secureStorage.delete(key: _finnhubApiKeyKey);
      _finnhubApiKey = null;
    } else {
      await _secureStorage.write(key: _finnhubApiKeyKey, value: trimmed);
      _finnhubApiKey = trimmed;
    }
    notifyListeners();
  }

  /// ล้างข้อมูลลับในเครื่อง (ใช้ตอนลบบัญชี)
  Future<void> clearSensitiveData() async {
    await setFinnhubApiKey(null);
  }

  /// อ่าน Finnhub key จาก secure storage และย้ายค่าเก่าที่เคยเก็บใน
  /// SharedPreferences (plaintext) มาไว้ใน secure storage ครั้งเดียว
  Future<String?> _loadFinnhubApiKey(SharedPreferences prefs) async {
    try {
      final legacyKey = prefs.getString(_finnhubApiKeyKey);
      if (legacyKey != null) {
        if (legacyKey.isNotEmpty) {
          await _secureStorage.write(key: _finnhubApiKeyKey, value: legacyKey);
        }
        await prefs.remove(_finnhubApiKeyKey);
      }
      return await _secureStorage.read(key: _finnhubApiKeyKey);
    } catch (e) {
      debugPrint('SettingsProvider: failed to load Finnhub key: $e');
      return null;
    }
  }

  Future<void> setDarkMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, enabled);
    _isDarkMode = enabled;
    notifyListeners();
  }

  Future<void> setThemeColor(ThemeColorOption option) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeColorKey, option.id);
    _themeColor = option;
    notifyListeners();
  }

  Future<void> toggleDarkMode() async {
    await setDarkMode(!_isDarkMode);
  }
}
