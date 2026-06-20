import 'dart:convert';

enum AppEnvironment {
  dev,
  prod;

  static AppEnvironment fromName(String value) {
    switch (value.trim().toLowerCase()) {
      case 'dev':
      case 'development':
        return AppEnvironment.dev;
      case 'prod':
      case 'production':
        return AppEnvironment.prod;
      default:
        throw const AppConfigException(
          'APP_ENV must be either "dev" or "prod".',
        );
    }
  }
}

class AppConfigException implements Exception {
  final String message;

  const AppConfigException(this.message);

  @override
  String toString() => message;
}

class AppConfig {
  static const String _environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );
  static const String _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  final AppEnvironment environment;
  final String supabaseUrl;
  final String supabaseAnonKey;

  const AppConfig._({
    required this.environment,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  static AppConfig fromEnvironment() {
    final environment = AppEnvironment.fromName(_environment);
    final supabaseUrl = _normalizeUrl(_supabaseUrl);
    final supabaseAnonKey = _supabaseAnonKey.trim();

    final errors = <String>[
      if (supabaseUrl == null) 'SUPABASE_URL is required.',
      if (supabaseAnonKey.isEmpty) 'SUPABASE_ANON_KEY is required.',
      if (supabaseUrl != null && Uri.tryParse(supabaseUrl)?.hasScheme != true)
        'SUPABASE_URL must be a valid URL.',
      if (environment == AppEnvironment.prod &&
          supabaseUrl != null &&
          !supabaseUrl.startsWith('https://'))
        'Production SUPABASE_URL must use HTTPS.',
      if (supabaseAnonKey.isNotEmpty &&
          !_looksLikeAllowedSupabaseAnonKey(supabaseAnonKey))
        'SUPABASE_ANON_KEY must be an anon/public key, not a service role key.',
    ];

    if (errors.isNotEmpty) {
      throw AppConfigException(errors.join(' '));
    }

    return AppConfig._(
      environment: environment,
      supabaseUrl: supabaseUrl!,
      supabaseAnonKey: supabaseAnonKey,
    );
  }

  bool get isProduction => environment == AppEnvironment.prod;

  String get environmentName => environment.name;

  String get maskedSupabaseUrl {
    final uri = Uri.tryParse(supabaseUrl);
    if (uri == null || uri.host.isEmpty) return 'configured';
    return uri.host;
  }

  static String? _normalizeUrl(String value) {
    var normalized = value.trim();
    if (normalized.isEmpty) return null;

    if (!normalized.startsWith('http://') &&
        !normalized.startsWith('https://')) {
      normalized = 'https://$normalized';
    }

    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }

    return normalized;
  }

  static bool _looksLikeAllowedSupabaseAnonKey(String value) {
    final parts = value.split('.');
    if (parts.length != 3) {
      return false;
    }

    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final claims = jsonDecode(payload);
      if (claims is! Map<String, dynamic>) return false;

      final role = claims['role'];
      return role == null || role == 'anon';
    } catch (_) {
      return false;
    }
  }
}
