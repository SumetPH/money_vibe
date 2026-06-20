import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../repositories/database_repository.dart';
import '../repositories/supabase_repository.dart';

/// Service สำหรับจัดการ Database - Supabase Only
///
/// ออกแบบสำหรับ Multi-device usage:
/// - ข้อมูลอยู่บน Supabase (Cloud)
/// - ตรงกันทุก device แบบ real-time
/// - ไม่มี SQLite (ไม่ต้อง sync, ไม่ต้อง migration)
class DatabaseManager extends ChangeNotifier {
  static final DatabaseManager _instance = DatabaseManager._internal();
  factory DatabaseManager() => _instance;
  DatabaseManager._internal();

  DatabaseRepository? _repository;
  AppConfig? _config;
  bool _isLoading = false;
  String? _error;

  // ── Getters ────────────────────────────────────────────────────────────────

  DatabaseRepository get repository {
    if (_repository == null) {
      throw StateError('DatabaseManager not initialized. Call init() first.');
    }
    return _repository!;
  }

  set repository(DatabaseRepository repo) {
    _repository = repo;
  }

  DatabaseRepository? get repositoryOrNull => _repository;

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;
  bool get isConfigured => _repository != null && _config != null;
  AppConfig? get config => _config;

  // ── Initialization ─────────────────────────────────────────────────────────

  Future<void> init() async {
    debugPrint('[DatabaseManager] Initializing...');
    _setLoading(true);

    try {
      final config = AppConfig.fromEnvironment();
      _config = config;
      _repository = SupabaseRepository(
        supabaseUrl: config.supabaseUrl,
        supabaseAnonKey: config.supabaseAnonKey,
      );
      await _repository!.init();
      debugPrint(
        '[DatabaseManager] Connected to Supabase (${config.environmentName})',
      );

      _error = null;
    } on AppConfigException catch (e) {
      debugPrint('[DatabaseManager] Config error: ${e.message}');
      _repository = null;
      _config = null;
      _error = e.message;
    } catch (e, stackTrace) {
      debugPrint('[DatabaseManager] Initialization error');
      debugPrint('[DatabaseManager] Stack trace: $stackTrace');
      _error = e.toString();
      _repository = null;
      _config = null;
    } finally {
      _setLoading(false);
    }
  }

  // ── Health Check ───────────────────────────────────────────────────────────

  Future<bool> testSupabaseConnection() async {
    if (!isConfigured) return false;
    try {
      return await _repository!.isConnected();
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
