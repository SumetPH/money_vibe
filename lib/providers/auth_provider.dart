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
  String? _error;
  bool _isInitialized = false;

  // ระหว่างตั้งรหัสผ่านใหม่ด้วยรหัส OTP จะมี session ชั่วคราว ไม่ให้ถือว่า login
  // (ไม่งั้น router จะ redirect ออกจากหน้าตั้งรหัสใหม่กลางทาง)
  bool _isRecoveringPassword = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;
  String? get userId => _user?.id;
  String? get userEmail => _user?.email;
  bool get isInitialized => _isInitialized;

  /// เริ่มต้นและตรวจสอบสถานะการ login
  /// ต้องเรียกหลังจาก Supabase ถูก initialize แล้วเท่านั้น
  Future<void> init() async {
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

      // ฟังการเปลี่ยนแปลง auth state
      client.auth.onAuthStateChange.listen((data) {
        if (_isRecoveringPassword) return;
        final AuthChangeEvent event = data.event;
        final Session? session = data.session;

        switch (event) {
          case AuthChangeEvent.signedIn:
          case AuthChangeEvent.tokenRefreshed:
            _user = session?.user;
            break;
          case AuthChangeEvent.signedOut:
            _user = null;
            break;
          default:
            break;
        }
        notifyListeners();
      });

      _isInitialized = true;
    } catch (e) {
      _error = _unexpectedErrorMessage;
      debugPrint('AuthProvider init error: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// สมัครสมาชิกด้วย Email/Password
  Future<bool> signUp({required String email, required String password}) async {
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
      );

      if (response.user != null) {
        if (response.session != null) {
          await client.auth.signOut();
        }
        _user = null;
        notifyListeners();
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

  /// ออกจากระบบ
  Future<void> signOut() async {
    _setLoading(true);
    try {
      final client = _safeClient;
      if (client != null) {
        await client.auth.signOut();
      }
      _user = null;
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
    _setLoading(true);
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
      _setLoading(false);
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

  /// ลบบัญชีผู้ใช้ถาวร (ต้อง login ก่อน)
  ///
  /// เรียก Edge Function `delete-account` ซึ่งใช้ service role ลบไฟล์ใน storage
  /// และลบ auth user (ข้อมูลทุกตารางถูกลบตาม ON DELETE CASCADE)
  Future<bool> deleteAccount() async {
    _setLoading(true);
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
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('AuthProvider: delete account error: $e');
      _error = 'ลบบัญชีไม่สำเร็จ กรุณาลองใหม่อีกครั้ง';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
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

  void _clearError() {
    _error = null;
  }

  /// แปลงข้อความ error ให้เข้าใจง่าย
  String _getErrorMessage(String message) {
    if (message.contains('Invalid login credentials')) {
      return 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
    } else if (message.contains('User already registered')) {
      return 'อีเมลนี้มีการลงทะเบียนแล้ว';
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
}
