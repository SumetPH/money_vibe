import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/google_auth_service.dart';
import '../utils/web_redirect.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider สำหรับจัดการ Authentication
class AuthProvider extends ChangeNotifier {
  static const _unexpectedErrorMessage =
      'เกิดข้อผิดพลาด กรุณาตรวจสอบการเชื่อมต่อแล้วลองใหม่';
  static const _deleteAccountFunction = 'delete-account';

  static final AuthProvider _instance = AuthProvider._internal();
  factory AuthProvider() => _instance;
  AuthProvider._internal();

  final _google = GoogleAuthService();
  bool get isGoogleAvailable => _google.isAvailable;
  bool _hasPassword = false;
  bool _signInMethodsReady = false;
  bool _signInMethodsFailed = false;
  bool _refreshingAccount = false;
  bool _refreshAccountAgain = false;
  bool _requiresPasswordNonce = false;
  bool get hasPassword => _hasPassword;
  bool get signInMethodsReady => _signInMethodsReady;
  bool get isLoadingSignInMethods =>
      !_signInMethodsReady && !_signInMethodsFailed;
  bool get requiresPasswordNonce => _requiresPasswordNonce;
  bool returnToSettings = false;
  static const _pendingGoogleLinkKey = 'pending_google_link_user';
  UserIdentity? get linkedGoogleIdentity {
    for (final identity in _user?.identities ?? <UserIdentity>[]) {
      if (identity.provider == 'google') return identity;
    }
    return null;
  }

  /// URL รูปโปรไฟล์จากบัญชี Google ที่ผูกอยู่ (ยกเลิกผูกแล้วรูปหายตาม)
  String? get avatarUrl {
    final googleData = linkedGoogleIdentity?.identityData;
    return _firstNonEmpty([googleData?['avatar_url'], googleData?['picture']]);
  }

  static String? _firstNonEmpty(List<Object?> values) => values
      .whereType<String>()
      .where((value) => value.trim().isNotEmpty)
      .firstOrNull;

  bool get canUnlinkGoogle =>
      linkedGoogleIdentity != null && (_user?.identities?.length ?? 0) >= 2;
  SupabaseClient? _client;
  bool _isSupabaseInitialized = false;

  /// Getter สำหรับ SupabaseClient
  /// จะคืนค่า null ถ้ายังไม่ได้ initialize
  SupabaseClient? get _safeClient {
    if (!_isSupabaseInitialized) {
      try {
        _client = Supabase.instance.client;
        _isSupabaseInitialized = true;
      } catch (_) {
        return null;
      }
    }
    return _client;
  }

  User? _user;
  bool _isLoading = false;
  bool _isUpdatingUsername = false;
  bool _isSendingResetCode = false;
  bool _isDeletingAccount = false;
  String? _error;
  bool _isInitialized = false;
  String? _emailNeedingConfirmation;
  String? get emailNeedingConfirmation => _emailNeedingConfirmation;
  static const _duplicateEmailMessage =
      'อีเมลนี้มีบัญชีผู้ใช้แล้ว ลองเข้าสู่ระบบด้วยรหัสผ่านหรือ Google';

  // ระหว่างตั้งรหัสผ่านใหม่ด้วยรหัส OTP จะมี session ชั่วคราว ไม่ให้ถือว่า login
  // (ไม่งั้น router จะ redirect ออกจากหน้าตั้งรหัสใหม่กลางทาง)
  bool _isRecoveringPassword = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isUpdatingUsername => _isUpdatingUsername;
  bool get isSendingResetCode => _isSendingResetCode;
  bool get isDeletingAccount => _isDeletingAccount;
  String? get error => _error;
  bool get isLoggedIn => _user != null;
  String? get userId => _user?.id;
  String? get userEmail => _user?.email;
  String? get username => _user?.userMetadata?['username'] as String?;
  bool get isInitialized => _isInitialized;

  /// เริ่มต้นและตรวจสอบสถานะการ login
  /// ต้องเรียกหลังจาก Supabase ถูก initialize แล้วเท่านั้น
  Future<void> init({Uri? callbackUri}) async {
    if (_isInitialized) return;

    _setLoading(true);
    try {
      final client = _safeClient;
      if (client == null) {
        debugPrint('AuthProvider: Supabase not initialized yet');
        _setLoading(false);
        return;
      }

      // ตรวจสอบ session ปัจจุบัน
      final session = client.auth.currentSession;
      _user = session?.user;
      final preferences = await SharedPreferences.getInstance();
      returnToSettings =
          _user != null &&
          preferences.getString(_pendingGoogleLinkKey) == _user!.id;
      if (_user != null) await _refreshAccount();

      // ฟังการเปลี่ยนแปลง auth state
      client.auth.onAuthStateChange.listen(
        (data) {
          if (_isRecoveringPassword) return;
          final AuthChangeEvent event = data.event;
          final Session? session = data.session;

          switch (event) {
            case AuthChangeEvent.signedIn:
            case AuthChangeEvent.tokenRefreshed:
            case AuthChangeEvent.userUpdated:
              if (_user?.id != session?.user.id) {
                _hasPassword = false;
                _signInMethodsReady = false;
                _signInMethodsFailed = false;
                _requiresPasswordNonce = false;
              }
              _user = session?.user;
              break;
            case AuthChangeEvent.signedOut:
              _user = null;
              _hasPassword = false;
              _signInMethodsReady = false;
              _requiresPasswordNonce = false;
              break;
            default:
              break;
          }
          notifyListeners();
          if (_user != null && event != AuthChangeEvent.initialSession) {
            // Leave the SDK event callback before making more Auth requests.
            Timer.run(_refreshAccount);
          }
        },
        onError: (Object error) {
          if (error is AuthException) {
            _setOAuthError(error.code ?? '', error.message);
            notifyListeners();
          }
        },
      );

      if (callbackUri != null) {
        final params = {
          ...callbackUri.queryParameters,
          if (callbackUri.fragment.contains('=') &&
              !callbackUri.fragment.startsWith('/'))
            ...Uri.splitQueryString(callbackUri.fragment),
        };
        if (params['error'] != null) {
          _setOAuthError(
            params['error_code'] ?? params['error']!,
            params['error_description'] ?? '',
          );
        }
      }

      _isInitialized = true;
    } catch (e) {
      _error = _unexpectedErrorMessage;
      debugPrint('AuthProvider init error: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// สมัครสมาชิกด้วย Email/Password
  Future<bool> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      final client = _safeClient;
      if (client == null) {
        _error = 'Supabase ยังไม่ได้ตั้งค่า';
        notifyListeners();
        return false;
      }

      final response = await client.auth.signUp(
        email: email,
        password: password,
        data: {'username': username},
      );

      if (response.user != null) {
        if (response.user!.identities?.isEmpty == true) {
          _error = _duplicateEmailMessage;
          return false;
        }
        _emailNeedingConfirmation = response.session == null ? email : null;
        _user = response.session?.user;
        return true;
      }
      return false;
    } on AuthException catch (e) {
      debugPrint('AuthProvider: auth error: ${e.message}');
      _error = _getErrorMessage(e.message);
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('AuthProvider: unexpected error: $e');
      _error = _unexpectedErrorMessage;
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// เข้าสู่ระบบด้วย Email/Password
  Future<bool> signIn({required String email, required String password}) async {
    _setLoading(true);
    _clearError();
    try {
      final client = _safeClient;
      if (client == null) {
        _error = 'Supabase ยังไม่ได้ตั้งค่า';
        notifyListeners();
        return false;
      }

      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        _user = response.user;
        notifyListeners();
        return true;
      }
      return false;
    } on AuthException catch (e) {
      debugPrint('AuthProvider: auth error: ${e.message}');
      if (e.code == 'email_not_confirmed' ||
          e.message.contains('Email not confirmed')) {
        _emailNeedingConfirmation = email;
      }
      _error = _getErrorMessage(e.message);
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('AuthProvider: unexpected error: $e');
      _error = _unexpectedErrorMessage;
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// ค่าที่ต้องเติมลง user metadata จากบัญชี Google ที่ผูกไว้
  /// การผูก Google ไม่ได้ copy ชื่อมาให้ (ได้เฉพาะตอน login ด้วย Google)
  Map<String, dynamic> _googleProfileUpdates() {
    final googleData = linkedGoogleIdentity?.identityData;
    if (googleData == null) return const {};
    final metadata = _user?.userMetadata;
    if (_firstNonEmpty([metadata?['username']]) != null) return const {};

    return {
      'username':
          _firstNonEmpty([
            metadata?['full_name'],
            metadata?['name'],
            googleData['full_name'],
            googleData['name'],
            userEmail?.split('@').first,
          ]) ??
          'ผู้ใช้',
    };
  }

  Future<void> _refreshAccount() async {
    if (_user == null) return;
    if (_refreshingAccount) {
      _refreshAccountAgain = true;
      return;
    }
    _refreshingAccount = true;
    if (_signInMethodsFailed) _error = null;
    _signInMethodsFailed = false;
    notifyListeners();
    final userId = _user!.id;
    try {
      final client = _safeClient!;
      final current = (await client.auth.getUser()).user;
      if (_user?.id != userId || current?.id != userId) return;
      _user = current;
      final google = linkedGoogleIdentity;
      final googleEmail = google?.identityData?['email'] as String?;
      if (google != null &&
          googleEmail?.toLowerCase() != userEmail?.toLowerCase()) {
        await client.auth.unlinkIdentity(google);
        final refreshedUser = (await client.auth.getUser()).user;
        if (_user?.id != userId) return;
        _user = refreshedUser;
        _error = 'ต้องใช้บัญชี Google ที่อีเมลตรงกับบัญชีผู้ใช้';
      }
      final profileUpdates = _googleProfileUpdates();
      if (profileUpdates.isNotEmpty) {
        final response = await client.auth.updateUser(
          UserAttributes(data: profileUpdates),
        );
        if (_user?.id != userId) return;
        _user = response.user;
      }
      final password = await client.rpc('has_password');
      if (_user?.id != userId) return;
      _hasPassword = password == true;
      _signInMethodsReady = true;
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_pendingGoogleLinkKey) == userId) {
        await prefs.remove(_pendingGoogleLinkKey);
      }
    } catch (e) {
      if (_user?.id == userId) {
        _signInMethodsReady = false;
        _signInMethodsFailed = true;
        _error = 'โหลดช่องทางเข้าสู่ระบบไม่สำเร็จ กรุณาลองใหม่';
      }
    } finally {
      _refreshingAccount = false;
      notifyListeners();
      if (_refreshAccountAgain) {
        _refreshAccountAgain = false;
        Timer.run(_refreshAccount);
      }
    }
  }

  Future<void> reloadSignInMethods() => _refreshAccount();

  void _setOAuthError(String code, String message) {
    if (code == 'access_denied' && !message.contains('identity')) {
      _error = null;
      return;
    }
    _error = _getErrorMessage('$code $message');
  }

  Future<bool> signInWithGoogle() => _performAuth(() async {
    if (!isGoogleAvailable) throw StateError('Google unavailable');
    if (kIsWeb) {
      final response = await _safeClient!.auth.getOAuthSignInUrl(
        provider: OAuthProvider.google,
        redirectTo: Uri.base.origin,
        queryParams: {'prompt': 'select_account'},
      );
      redirectWebTo(response.url);
    } else {
      final credential = await _google.authenticate();
      final response = await _safeClient!.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: credential.idToken,
        accessToken: credential.accessToken,
      );
      _user = response.user;
      await _refreshAccount();
    }
  });

  Future<void> signOut() async {
    _setLoading(true);
    try {
      final client = _safeClient;
      if (client != null) {
        await client.auth.signOut();
      }
      _user = null;
      _hasPassword = false;
      _signInMethodsReady = false;
      await _clearGoogleSession();
      notifyListeners();
    } catch (e) {
      debugPrint('AuthProvider: sign out error: $e');
      _error = 'ออกจากระบบไม่สำเร็จ กรุณาลองใหม่';
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  /// ขอรหัส OTP สำหรับตั้งรหัสผ่านใหม่ทางอีเมล
  /// (email template "Reset Password" ต้องแสดง `{{ .Token }}`)
  Future<bool> resetPassword(String email) async {
    _setSendingResetCode(true);
    _clearError();
    try {
      final client = _safeClient;
      if (client == null) {
        _error = 'Supabase ยังไม่ได้ตั้งค่า';
        notifyListeners();
        return false;
      }

      await client.auth.resetPasswordForEmail(email);
      return true;
    } on AuthException catch (e) {
      debugPrint('AuthProvider: auth error: ${e.message}');
      _error = _getErrorMessage(e.message);
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('AuthProvider: unexpected error: $e');
      _error = _unexpectedErrorMessage;
      notifyListeners();
      return false;
    } finally {
      _setSendingResetCode(false);
    }
  }

  /// ตรวจรหัส OTP จากอีเมลแล้วตั้งรหัสผ่านใหม่ในครั้งเดียว
  ///
  /// verifyOTP สร้าง session ชั่วคราว จึง sign out ทุกครั้งเมื่อจบ
  /// ให้ผู้ใช้ login ใหม่ด้วยรหัสผ่านใหม่เอง
  Future<bool> resetPasswordWithCode({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final client = _safeClient;
    if (client == null) {
      _error = 'Supabase ยังไม่ได้ตั้งค่า';
      notifyListeners();
      return false;
    }

    _setLoading(true);
    _clearError();
    _isRecoveringPassword = true;
    try {
      await client.auth.verifyOTP(
        email: email,
        token: code,
        type: OtpType.recovery,
      );
      await client.auth.updateUser(UserAttributes(password: newPassword));
      return true;
    } on AuthException catch (e) {
      debugPrint('AuthProvider: reset password error: ${e.message}');
      _error = _getErrorMessage(e.message);
      return false;
    } catch (e) {
      debugPrint('AuthProvider: reset password unexpected error: $e');
      _error = _unexpectedErrorMessage;
      return false;
    } finally {
      try {
        await client.auth.signOut(scope: SignOutScope.local);
      } catch (e) {
        debugPrint('AuthProvider: sign out after reset failed: $e');
      }
      _user = null;
      _isRecoveringPassword = false;
      _setLoading(false);
    }
  }

  /// อัพเดทรหัสผ่าน
  Future<bool> updatePassword(String newPassword) async {
    _setLoading(true);
    _clearError();
    try {
      final client = _safeClient;
      if (client == null) {
        _error = 'Supabase ยังไม่ได้ตั้งค่า';
        notifyListeners();
        return false;
      }

      await client.auth.updateUser(UserAttributes(password: newPassword));
      return true;
    } on AuthException catch (e) {
      debugPrint('AuthProvider: auth error: ${e.message}');
      _error = _getErrorMessage(e.message);
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('AuthProvider: unexpected error: $e');
      _error = _unexpectedErrorMessage;
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// เปลี่ยนชื่อผู้ใช้ (เก็บใน user_metadata)
  Future<bool> updateUsername(String username) async {
    _setUpdatingUsername(true);
    _clearError();
    try {
      final client = _safeClient;
      if (client == null) {
        _error = 'Supabase ยังไม่ได้ตั้งค่า';
        notifyListeners();
        return false;
      }

      final response = await client.auth.updateUser(
        UserAttributes(data: {'username': username}),
      );
      _user = response.user ?? _user;
      return true;
    } on AuthException catch (e) {
      debugPrint('AuthProvider: auth error: ${e.message}');
      _error = _getErrorMessage(e.message);
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('AuthProvider: unexpected error: $e');
      _error = _unexpectedErrorMessage;
      notifyListeners();
      return false;
    } finally {
      _setUpdatingUsername(false);
    }
  }

  /// ลบบัญชีผู้ใช้ถาวร (ต้อง login ก่อน)
  ///
  /// เรียก Edge Function `delete-account` ซึ่งใช้ service role ลบไฟล์ใน storage
  /// และลบ auth user (ข้อมูลทุกตารางถูกลบตาม ON DELETE CASCADE)
  Future<bool> deleteAccount() async {
    _setDeletingAccount(true);
    _clearError();
    try {
      final client = _safeClient;
      if (client == null) {
        _error = 'Supabase ยังไม่ได้ตั้งค่า';
        notifyListeners();
        return false;
      }

      await client.functions.invoke(_deleteAccountFunction);
      // ลบ session ในเครื่อง; user ฝั่ง server ถูกลบไปแล้วจึงไม่ต้องเรียก global sign out
      await client.auth.signOut(scope: SignOutScope.local);
      _user = null;
      _hasPassword = false;
      _signInMethodsReady = false;
      await _clearGoogleSession();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('AuthProvider: delete account error: $e');
      _error = 'ลบบัญชีไม่สำเร็จ กรุณาลองใหม่อีกครั้ง';
      notifyListeners();
      return false;
    } finally {
      _setDeletingAccount(false);
    }
  }

  /// ล้างข้อความ error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setUpdatingUsername(bool value) {
    _isUpdatingUsername = value;
    notifyListeners();
  }

  void _setSendingResetCode(bool value) {
    _isSendingResetCode = value;
    notifyListeners();
  }

  void _setDeletingAccount(bool value) {
    _isDeletingAccount = value;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    _emailNeedingConfirmation = null;
  }

  /// แปลงข้อความ error ให้เข้าใจง่าย
  String _getErrorMessage(String message) {
    if (message.contains('password_nonce_sent')) {
      return 'กรุณากรอกรหัสยืนยันที่ส่งไปทางอีเมล';
    }
    if (message.contains('reauthentication_not_valid')) {
      return 'รหัสยืนยันไม่ถูกต้องหรือหมดอายุ กรุณาขอรหัสใหม่';
    }
    if (message.contains('identity_already_exists') ||
        message.contains('Identity is already linked')) {
      return 'บัญชี Google นี้ถูกใช้กับบัญชีผู้ใช้อื่นแล้ว';
    }
    if (message.contains('email_mismatch')) {
      return 'ต้องใช้บัญชี Google ที่อีเมลตรงกับบัญชีผู้ใช้';
    }
    if (message.contains('same_password')) {
      return 'รหัสผ่านใหม่ต้องไม่ซ้ำกับรหัสผ่านเดิม';
    }
    if (message.contains('email_exists') ||
        message.contains('user_already_exists')) {
      return _duplicateEmailMessage;
    }
    if (message.contains('Invalid login credentials')) {
      return 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
    } else if (message.contains('User already registered')) {
      return _duplicateEmailMessage;
    } else if (message.contains('Password should be at least')) {
      return 'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร';
    } else if (message.contains('Password should contain') ||
        message.contains('weak') ||
        message.contains('pwned')) {
      return 'รหัสผ่านนี้คาดเดาง่ายหรือเคยรั่วไหล กรุณาใช้รหัสผ่านอื่น';
    } else if (message.contains('Token has expired') ||
        message.contains('otp_expired') ||
        message.contains('Invalid OTP')) {
      return 'รหัสยืนยันไม่ถูกต้องหรือหมดอายุ กรุณาขอรหัสใหม่';
    } else if (message.contains('should be different')) {
      return 'รหัสผ่านใหม่ต้องไม่ซ้ำกับรหัสผ่านเดิม';
    } else if (message.contains('security purposes')) {
      return 'กรุณารอสักครู่ก่อนขอรหัสใหม่อีกครั้ง';
    } else if (message.contains('rate limit') ||
        message.contains('Too many requests')) {
      return 'ลองหลายครั้งเกินไป กรุณารอสักครู่แล้วลองใหม่';
    } else if (message.contains('Unable to validate email address')) {
      return 'รูปแบบอีเมลไม่ถูกต้อง';
    } else if (message.contains('Email not confirmed')) {
      return 'กรุณายืนยันอีเมลก่อนเข้าสู่ระบบ';
    }
    return _unexpectedErrorMessage;
  }

  Future<bool> verifySignUpCode(String email, String code) =>
      _performAuth(() async {
        final response = await _safeClient!.auth.verifyOTP(
          email: email,
          token: code,
          type: OtpType.signup,
        );
        _user = response.user;
        _emailNeedingConfirmation = null;
      });

  Future<bool> resendSignUpCode(String email) => _performAuth(() async {
    await _safeClient!.auth.resend(type: OtpType.signup, email: email);
  });

  Future<bool> _performAuth(Future<void> Function() action) async {
    if (_isLoading) return false;
    _setLoading(true);
    _clearError();
    try {
      if (_safeClient == null) {
        _error = 'Supabase ยังไม่ได้ตั้งค่า';
        return false;
      }
      await action();
      return true;
    } on GoogleSignInException catch (e) {
      _error = e.code == GoogleSignInExceptionCode.canceled
          ? null
          : 'ดำเนินการกับ Google ไม่สำเร็จ กรุณาลองใหม่';
      return false;
    } on AuthException catch (e) {
      _error = _getErrorMessage('${e.code ?? ''} ${e.message}');
      return false;
    } catch (e) {
      _error = _unexpectedErrorMessage;
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> changePassword(String currentPassword, String newPassword) =>
      _performAuth(() async {
        final client = _safeClient!;
        final id = userId;
        final email = userEmail;
        if (!_hasPassword || email == null) {
          throw const AuthException('Password unavailable');
        }
        await client.auth.signInWithPassword(
          email: email,
          password: currentPassword,
        );
        if (userId != id) throw const AuthException('User changed');
        if (currentPassword == newPassword) {
          throw const AuthException('New password should be different');
        }
        final response = await client.auth.updateUser(
          UserAttributes(password: newPassword),
        );
        _user = response.user;
        await _refreshAccount();
      });

  Future<bool> setPassword(String newPassword, {String? nonce}) =>
      _performAuth(() async {
        final client = _safeClient!;
        try {
          final response = await client.auth.updateUser(
            UserAttributes(password: newPassword, nonce: nonce),
          );
          _user = response.user;
          _requiresPasswordNonce = false;
          await _refreshAccount();
        } on AuthException catch (e) {
          if (e.code == 'reauthentication_needed' ||
              e.message.toLowerCase().contains('reauthentication') &&
                  e.code != 'reauthentication_not_valid') {
            await client.auth.reauthenticate();
            _requiresPasswordNonce = true;
            throw const AuthException(
              'Password nonce sent',
              code: 'password_nonce_sent',
            );
          }
          rethrow;
        }
      });

  Future<bool> resendPasswordNonce() => _performAuth(() async {
    await _safeClient!.auth.reauthenticate();
    _requiresPasswordNonce = true;
  });

  Future<bool> linkGoogle() => _performAuth(() async {
    if (!isGoogleAvailable || _user == null) {
      throw StateError('Google unavailable');
    }
    final client = _safeClient!;
    final id = userId;
    final email = userEmail;
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingGoogleLinkKey, id!);
      try {
        final response = await client.auth.getLinkIdentityUrl(
          OAuthProvider.google,
          redirectTo: Uri.base.origin,
          queryParams: {'prompt': 'select_account'},
        );
        redirectWebTo(response.url);
      } catch (_) {
        await prefs.remove(_pendingGoogleLinkKey);
        rethrow;
      }
    } else {
      final credential = await _google.authenticate();
      if (credential.email.toLowerCase() != email?.toLowerCase()) {
        await _google.signOut();
        throw const AuthException(
          'Google email mismatch',
          code: 'email_mismatch',
        );
      }
      if (userId != id) throw StateError('User changed');
      final response = await client.auth.linkIdentityWithIdToken(
        provider: OAuthProvider.google,
        idToken: credential.idToken,
        accessToken: credential.accessToken,
      );
      _user = response.user;
      await _refreshAccount();
    }
  });

  Future<bool> unlinkGoogle() => _performAuth(() async {
    // Refresh identities before guarding the last available sign-in method.
    _user = (await _safeClient!.auth.getUser()).user;
    if (!canUnlinkGoogle) {
      throw const AuthException('Cannot remove last identity');
    }
    await _safeClient!.auth.unlinkIdentity(linkedGoogleIdentity!);
    await _clearGoogleSession();
    _user = (await _safeClient!.auth.getUser()).user;
    await _refreshAccount();
  });

  Future<void> _clearGoogleSession() async {
    try {
      await _google.signOut();
    } catch (e) {
      debugPrint('Google sign-out failed');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingGoogleLinkKey);
  }
}
