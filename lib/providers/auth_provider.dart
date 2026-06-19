import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider สำหรับจัดการ Authentication - SQLite (Offline mock)
class AuthProvider extends ChangeNotifier {
  static final AuthProvider _instance = AuthProvider._internal();
  factory AuthProvider() => _instance;
  AuthProvider._internal();

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
  Future<void> init() async {
    if (_isInitialized) return;

    _setLoading(true);
    try {
      // Mock local session/user for offline usage
      _user = User(
        id: 'local_user',
        appMetadata: const <String, dynamic>{},
        userMetadata: const <String, dynamic>{},
        aud: 'offline',
        createdAt: DateTime.now().toIso8601String(),
        email: 'local_user@moneyvibe.app',
      );
      _isInitialized = true;
    } catch (e) {
      _error = e.toString();
      debugPrint('AuthProvider init error: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// สมัครสมาชิกจำลอง
  Future<bool> signUp({required String email, required String password}) async {
    _setLoading(true);
    _clearError();
    try {
      _user = User(
        id: 'local_user',
        appMetadata: const <String, dynamic>{},
        userMetadata: const <String, dynamic>{},
        aud: 'offline',
        createdAt: DateTime.now().toIso8601String(),
        email: email,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// เข้าสู่ระบบจำลอง
  Future<bool> signIn({required String email, required String password}) async {
    _setLoading(true);
    _clearError();
    try {
      _user = User(
        id: 'local_user',
        appMetadata: const <String, dynamic>{},
        userMetadata: const <String, dynamic>{},
        aud: 'offline',
        createdAt: DateTime.now().toIso8601String(),
        email: email,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// ออกจากระบบจำลอง
  Future<void> signOut() async {
    _setLoading(true);
    try {
      _user = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  /// รีเซ็ตรหัสผ่านจำลอง
  Future<bool> resetPassword(String email) async {
    return true;
  }

  /// อัพเดทรหัสผ่านจำลอง
  Future<bool> updatePassword(String newPassword) async {
    return true;
  }

  /// ลบบัญชีผู้ใช้จำลอง
  Future<bool> deleteAccount() async {
    _setLoading(true);
    try {
      _user = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
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
}
