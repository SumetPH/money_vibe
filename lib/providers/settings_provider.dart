import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const _finnhubApiKeyKey = 'finnhub_api_key';
  static const _darkModeKey = 'dark_mode';
  static const _budgetStartDayKey = 'budget_start_day';

  String? _finnhubApiKey;
  bool _isDarkMode = false;
  bool _isLoaded = false;
  int _budgetStartDay = 1;

  String? get finnhubApiKey => _finnhubApiKey;
  bool get isDarkMode => _isDarkMode;
  bool get isLoaded => _isLoaded;
  int get budgetStartDay => _budgetStartDay;

  bool get isFinnhubConfigured =>
      _finnhubApiKey != null && _finnhubApiKey!.isNotEmpty;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _finnhubApiKey = prefs.getString(_finnhubApiKeyKey);
    _isDarkMode = prefs.getBool(_darkModeKey) ?? false;
    _budgetStartDay = prefs.getInt(_budgetStartDayKey) ?? 1;
    _isLoaded = true;
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

  Future<void> setDarkMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, enabled);
    _isDarkMode = enabled;
    notifyListeners();
  }

  Future<void> toggleDarkMode() async {
    await setDarkMode(!_isDarkMode);
  }
}
