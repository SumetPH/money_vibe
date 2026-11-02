import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../config/app_config.dart';

class GoogleAuthService {
  Future<void>? _initialization;

  bool get isSupported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
  bool get isAvailable =>
      isSupported &&
      AppConfig.googleWebClientId.isNotEmpty &&
      (kIsWeb ||
          defaultTargetPlatform != TargetPlatform.iOS ||
          AppConfig.googleIosClientId.isNotEmpty);

  Future<({String email, String idToken, String accessToken})>
  authenticate() async {
    if (!isAvailable || kIsWeb) {
      throw StateError('Native Google sign-in unavailable');
    }
    await _initialize();
    await GoogleSignIn.instance.signOut();
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) throw StateError('Missing Google ID token');
    const scopes = ['email', 'profile'];
    final authorization =
        await account.authorizationClient.authorizationForScopes(scopes) ??
        await account.authorizationClient.authorizeScopes(scopes);
    return (
      email: account.email,
      idToken: idToken,
      accessToken: authorization.accessToken,
    );
  }

  Future<void> _initialize() =>
      _initialization ??= GoogleSignIn.instance.initialize(
        clientId: defaultTargetPlatform == TargetPlatform.iOS
            ? AppConfig.googleIosClientId
            : null,
        serverClientId: AppConfig.googleWebClientId,
      );

  Future<void> signOut() async {
    if (!isAvailable || kIsWeb) return;
    await _initialize();
    await GoogleSignIn.instance.signOut();
  }
}
