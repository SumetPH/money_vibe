import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/database_repository.dart';
import '../repositories/supabase_repository.dart';

/// Service สำหรับจัดการ Database - Supabase Only
/// 
/// ออกแบบสำหรับ Multi-device usage:
/// - ข้อมูลอยู่บน Supabase (Cloud)
/// - ตรงกันทุก device แบบ real-time
/// - ไม่มี SQLite (ไม่ต้อง sync, ไม่ต้อง migration)
class DatabaseManager extends ChangeNotifier {
  static const String _supabaseUrlKey = 'supabase_url';
  static const String _supabaseKeyKey = 'supabase_anon_key';

  static final DatabaseManager _instance = DatabaseManager._internal();
  factory DatabaseManager() => _instance;
  DatabaseManager._internal();

  DatabaseRepository? _repository;
  
  String? _supabaseUrl;
  String? _supabaseAnonKey;
  bool _isLoading = false;
  String? _error;

  // ── Getters ────────────────────────────────────────────────────────────────

  DatabaseRepository get repository {
    if (_repository == null) {
      throw StateError('DatabaseManager not initialized. Call init() first.');
    }
    return _repository!;
  }

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;
  bool get isConfigured => _supabaseUrl != null && _supabaseAnonKey != null;
  
  // Getters for saved config (for auto-fill in settings)
  String? get supabaseUrl => _supabaseUrl;
  String? get supabaseAnonKey => _supabaseAnonKey;

  // ── Initialization ─────────────────────────────────────────────────────────

  Future<void> init() async {
    debugPrint('[DatabaseManager] Initializing...');
    _setLoading(true);

    try {
      final prefs = await SharedPreferences.getInstance();
      _supabaseUrl = prefs.getString(_supabaseUrlKey);
      _supabaseAnonKey = prefs.getString(_supabaseKeyKey);

      if (isConfigured) {
        _repository = SupabaseRepository(
          supabaseUrl: _supabaseUrl!,
          supabaseAnonKey: _supabaseAnonKey!,
        );
        await _repository!.init();
        debugPrint('[DatabaseManager] Connected to Supabase');
      } else {
        debugPrint('[DatabaseManager] Supabase not configured yet');
      }

      _error = null;
    } catch (e, stackTrace) {
      debugPrint('[DatabaseManager] Initialization error: $e');
      debugPrint('[DatabaseManager] Stack trace: $stackTrace');
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // ── Configuration ──────────────────────────────────────────────────────────

  Future<bool> configureSupabase({
    required String url,
    required String anonKey,
  }) async {
    _setLoading(true);

    try {
      // Test connection first
      final testRepo = SupabaseRepository(
        supabaseUrl: url,
        supabaseAnonKey: anonKey,
      );
      await testRepo.init();
      
      if (!await testRepo.isConnected()) {
        throw Exception('Cannot connect to Supabase');
      }

      // Save config
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_supabaseUrlKey, url);
      await prefs.setString(_supabaseKeyKey, anonKey);

      _supabaseUrl = url;
      _supabaseAnonKey = anonKey;
      _repository = testRepo;

      _error = null;
      notifyListeners();
      debugPrint('[DatabaseManager] Supabase configured successfully');
      return true;
    } catch (e) {
      debugPrint('[DatabaseManager] Configuration error: $e');
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> clearSupabaseConfig() async {
    _setLoading(true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_supabaseUrlKey);
      await prefs.remove(_supabaseKeyKey);

      await _repository?.close();
      _repository = null;
      _supabaseUrl = null;
      _supabaseAnonKey = null;

      _error = null;
      notifyListeners();
      debugPrint('[DatabaseManager] Supabase config cleared');
    } finally {
      _setLoading(false);
    }
  }

  // ── Health Check ───────────────────────────────────────────────────────────

  Future<bool> testSupabaseConnection() async {
    if (!isConfigured) return false;
    return await testSupabaseConnectionWithCredentials(
      url: _supabaseUrl!,
      anonKey: _supabaseAnonKey!,
    );
  }

  Future<bool> testSupabaseConnectionWithCredentials({
    required String url,
    required String anonKey,
  }) async {
    try {
      final testRepo = SupabaseRepository(
        supabaseUrl: url,
        supabaseAnonKey: anonKey,
      );
      await testRepo.init();
      return await testRepo.isConnected();
    } catch (e) {
      debugPrint('[DatabaseManager] Connection test failed: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> healthCheck() async {
    if (_repository == null) {
      return {'status': 'not_configured'};
    }
    return await _repository!.healthCheck();
  }

  // ── Private Helpers ────────────────────────────────────────────────────────

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
