import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const _finnhubApiKeyKey = 'finnhub_api_key';
  
  String? _finnhubApiKey;
  bool _isLoaded = false;

  String? get finnhubApiKey => _finnhubApiKey;
  bool get isLoaded => _isLoaded;

  bool get isFinnhubConfigured =>
      _finnhubApiKey != null && _finnhubApiKey!.isNotEmpty;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _finnhubApiKey = prefs.getString(_finnhubApiKeyKey);
    _isLoaded = true;
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
}
