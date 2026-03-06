import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider สำหรับจัดการ Authentication
class AuthProvider extends ChangeNotifier {
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
      _error = e.toString();
      debugPrint('AuthProvider init error: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// สมัครสมาชิกด้วย Email/Password
  Future<bool> signUp({
    required String email,
    required String password,
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
      );

      if (response.user != null) {
        _user = response.user;
        notifyListeners();
        return true;
      }
      return false;
    } on AuthException catch (e) {
      _error = _getErrorMessage(e.message);
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'เกิดข้อผิดพลาดที่ไม่คาดคิด: $e';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// เข้าสู่ระบบด้วย Email/Password
  Future<bool> signIn({
    required String email,
    required String password,
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
      _error = _getErrorMessage(e.message);
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'เกิดข้อผิดพลาดที่ไม่คาดคิด: $e';
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
      _error = e.toString();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  /// รีเซ็ตรหัสผ่าน
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
      _error = _getErrorMessage(e.message);
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'เกิดข้อผิดพลาดที่ไม่คาดคิด: $e';
      notifyListeners();
      return false;
    } finally {
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

      await client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return true;
    } on AuthException catch (e) {
      _error = _getErrorMessage(e.message);
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'เกิดข้อผิดพลาดที่ไม่คาดคิด: $e';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// ลบบัญชีผู้ใช้ (ต้อง login ก่อน)
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

      // ต้องเรียก RPC function บน Supabase เนื่องจาก delete user
      // ต้องใช้ service role key ซึ่งไม่ควรเก็บบน client
      // ให้เรียก edge function หรือ RPC แทน
      await client.rpc('delete_user');
      _user = null;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _error = _getErrorMessage(e.message);
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'เกิดข้อผิดพลาดที่ไม่คาดคิด: $e';
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
      return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
    } else if (message.contains('Unable to validate email address')) {
      return 'รูปแบบอีเมลไม่ถูกต้อง';
    } else if (message.contains('Email not confirmed')) {
      return 'กรุณายืนยันอีเมลก่อนเข้าสู่ระบบ';
    }
    return message;
  }
}
