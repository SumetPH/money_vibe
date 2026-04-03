import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/auth_provider.dart';

/// Applies fixed local values for debug web runs via --dart-define.
class DebugBootstrapService {
  static final DebugBootstrapService instance = DebugBootstrapService._();

  static const bool _enabled = bool.fromEnvironment('DEBUG_WEB_BOOTSTRAP');
  static const String _supabaseUrl = String.fromEnvironment(
    'DEBUG_SUPABASE_URL',
  );
  static const String _supabaseAnonKey = String.fromEnvironment(
    'DEBUG_SUPABASE_ANON_KEY',
  );
  static const String _loginEmail = String.fromEnvironment('DEBUG_LOGIN_EMAIL');
  static const String _loginPassword = String.fromEnvironment(
    'DEBUG_LOGIN_PASSWORD',
  );
  static const String _finnhubApiKey = String.fromEnvironment(
    'DEBUG_FINNHUB_API_KEY',
  );
  static const bool _hasDarkMode = bool.hasEnvironment('DEBUG_DARK_MODE');
  static const bool _darkMode = bool.fromEnvironment('DEBUG_DARK_MODE');
  static const bool _hasBudgetStartDay = bool.hasEnvironment(
    'DEBUG_BUDGET_START_DAY',
  );
  static const int _budgetStartDay = int.fromEnvironment(
    'DEBUG_BUDGET_START_DAY',
  );

  static const String _supabaseUrlKey = 'supabase_url';
  static const String _supabaseKeyKey = 'supabase_anon_key';
  static const String _finnhubApiKeyKey = 'finnhub_api_key';
  static const String _darkModeKey = 'dark_mode';
  static const String _budgetStartDayKey = 'budget_start_day';

  DebugBootstrapService._();

  bool get isEnabled => kDebugMode && kIsWeb && _enabled;

  Future<void> primeLocalState() async {
    if (!isEnabled) return;

    final prefs = await SharedPreferences.getInstance();
    final appliedKeys = <String>[];

    final supabaseUrl = _normalizeUrl(_supabaseUrl);
    final supabaseAnonKey = _trimmedOrNull(_supabaseAnonKey);
    if (supabaseUrl != null && supabaseAnonKey != null) {
      await prefs.setString(_supabaseUrlKey, supabaseUrl);
      await prefs.setString(_supabaseKeyKey, supabaseAnonKey);
      appliedKeys.add('supabase');
    }

    final finnhubApiKey = _trimmedOrNull(_finnhubApiKey);
    if (finnhubApiKey != null) {
      await prefs.setString(_finnhubApiKeyKey, finnhubApiKey);
      appliedKeys.add('finnhubApiKey');
    }

    if (_hasDarkMode) {
      await prefs.setBool(_darkModeKey, _darkMode);
      appliedKeys.add('darkMode');
    }

    if (_hasBudgetStartDay && _budgetStartDay >= 1 && _budgetStartDay <= 31) {
      await prefs.setInt(_budgetStartDayKey, _budgetStartDay);
      appliedKeys.add('budgetStartDay');
    }

    final summary = appliedKeys.isEmpty ? 'none' : appliedKeys.join(', ');
    debugPrint('[DebugBootstrapService] Applied debug values: $summary');
  }

  Future<void> signInIfNeeded(AuthProvider authProvider) async {
    if (!isEnabled) return;

    final email = _trimmedOrNull(_loginEmail);
    final password = _trimmedOrNull(_loginPassword);
    if (email == null || password == null) return;

    if (authProvider.isLoggedIn && authProvider.userEmail == email) {
      debugPrint('[DebugBootstrapService] Debug user already signed in');
      return;
    }

    if (authProvider.isLoggedIn && authProvider.userEmail != email) {
      await authProvider.signOut();
    }

    final success = await authProvider.signIn(email: email, password: password);
    if (success) {
      debugPrint('[DebugBootstrapService] Debug auto sign-in completed');
      return;
    }

    debugPrint(
      '[DebugBootstrapService] Debug auto sign-in failed: '
      '${authProvider.error ?? 'unknown error'}',
    );
  }

  String? _trimmedOrNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _normalizeUrl(String value) {
    var normalized = _trimmedOrNull(value);
    if (normalized == null) return null;

    if (!normalized.startsWith('http://') &&
        !normalized.startsWith('https://')) {
      normalized = 'https://$normalized';
    }

    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }

    return normalized;
  }
}
