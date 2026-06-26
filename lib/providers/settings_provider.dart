import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/theme_color_option.dart';

enum ExchangeRateSource { yahoo, frankfurter }

class SettingsProvider extends ChangeNotifier {
  static const _finnhubApiKeyKey = 'finnhub_api_key';
  static const _priceSourceFinnhubKey = 'price_source_finnhub';
  static const _yahooExtendedHoursKey = 'yahoo_extended_hours_price';
  static const _exchangeRateSourceKey = 'exchange_rate_source';
  static const _llmApiKeyKey = 'llm_api_key';
  static const _llmBaseUrlKey = 'llm_base_url';
  static const _llmModelKey = 'llm_model';
  static const _darkModeKey = 'dark_mode';
  static const _themeColorKey = 'theme_color';
  static const _budgetStartDayKey = 'budget_start_day';
  static const _netWorthFilterKey = 'net_worth_filter_ids';

  String? _finnhubApiKey;
  bool _priceSourceFinnhub = false;
  bool _useYahooExtendedHoursPrice = true;
  ExchangeRateSource _exchangeRateSource = ExchangeRateSource.yahoo;
  String? _llmApiKey;
  String? _llmBaseUrl;
  String? _llmModel;
  bool _isDarkMode = true;
  ThemeColorOption _themeColor = ThemeColorOption.classic;
  bool _isLoaded = false;
  int _budgetStartDay = 1;
  Set<String>? _netWorthFilterIds; // null = all accounts

  String? get finnhubApiKey => _finnhubApiKey;
  String? get llmApiKey => _llmApiKey;
  String? get llmBaseUrl => _llmBaseUrl;
  String? get llmModel => _llmModel;
  bool get isDarkMode => _isDarkMode;
  ThemeColorOption get themeColor => _themeColor;
  bool get isLoaded => _isLoaded;
  int get budgetStartDay => _budgetStartDay;
  Set<String>? get netWorthFilterIds =>
      _netWorthFilterIds == null ? null : Set.unmodifiable(_netWorthFilterIds!);

  bool get isFinnhubConfigured =>
      _finnhubApiKey != null && _finnhubApiKey!.isNotEmpty;

  bool get useFinnhubForPrices => _priceSourceFinnhub && isFinnhubConfigured;
  bool get useYahooExtendedHoursPrice => _useYahooExtendedHoursPrice;
  ExchangeRateSource get exchangeRateSource => _exchangeRateSource;
  bool get useYahooForExchangeRate =>
      _exchangeRateSource == ExchangeRateSource.yahoo;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _finnhubApiKey = prefs.getString(_finnhubApiKeyKey);
    _priceSourceFinnhub = prefs.getBool(_priceSourceFinnhubKey) ?? false;
    _useYahooExtendedHoursPrice = prefs.getBool(_yahooExtendedHoursKey) ?? true;
    final exchangeRateSourceRaw = prefs.getString(_exchangeRateSourceKey);
    _exchangeRateSource =
        exchangeRateSourceRaw == ExchangeRateSource.frankfurter.name
        ? ExchangeRateSource.frankfurter
        : ExchangeRateSource.yahoo;
    _llmApiKey = prefs.getString(_llmApiKeyKey);
    _llmBaseUrl = prefs.getString(_llmBaseUrlKey);
    _llmModel = prefs.getString(_llmModelKey);
    _isDarkMode = prefs.getBool(_darkModeKey) ?? true;
    _themeColor = ThemeColorOption.byId(prefs.getString(_themeColorKey));
    _budgetStartDay = prefs.getInt(_budgetStartDayKey) ?? 1;
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

  Future<void> setBudgetStartDay(int day) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_budgetStartDayKey, day);
    _budgetStartDay = day;
    notifyListeners();
  }

  Future<void> setFinnhubApiKey(String? apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    if (apiKey == null || apiKey.isEmpty) {
      await prefs.remove(_finnhubApiKeyKey);
      _finnhubApiKey = null;
    } else {
      await prefs.setString(_finnhubApiKeyKey, apiKey);
      _finnhubApiKey = apiKey;
    }
    notifyListeners();
  }

  Future<void> setUseFinnhubForPrices(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_priceSourceFinnhubKey, value);
    _priceSourceFinnhub = value;
    notifyListeners();
  }

  Future<void> setUseYahooExtendedHoursPrice(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_yahooExtendedHoursKey, value);
    _useYahooExtendedHoursPrice = value;
    notifyListeners();
  }

  Future<void> setExchangeRateSource(ExchangeRateSource value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_exchangeRateSourceKey, value.name);
    _exchangeRateSource = value;
    notifyListeners();
  }

  Future<void> setLLM(String? apiKey, String? baseUrl, String? model) async {
    final prefs = await SharedPreferences.getInstance();
    if (apiKey == null || apiKey.isEmpty) {
      await prefs.remove(_llmApiKeyKey);
      _llmApiKey = null;
    } else {
      await prefs.setString(_llmApiKeyKey, apiKey);
      _llmApiKey = apiKey;
    }

    if (baseUrl == null || baseUrl.isEmpty) {
      await prefs.remove(_llmBaseUrlKey);
      _llmBaseUrl = null;
    } else {
      await prefs.setString(_llmBaseUrlKey, baseUrl);
      _llmBaseUrl = baseUrl;
    }

    if (model == null || model.isEmpty) {
      await prefs.remove(_llmModelKey);
      _llmModel = null;
    } else {
      await prefs.setString(_llmModelKey, model);
      _llmModel = model;
    }

    notifyListeners();
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
