import 'package:flutter/material.dart';
import '../repositories/database_repository.dart';
import '../repositories/sqlite_repository.dart';

/// Service สำหรับจัดการ Database - SQLite (Offline-first)
class DatabaseManager extends ChangeNotifier {
  static final DatabaseManager _instance = DatabaseManager._internal();
  factory DatabaseManager() => _instance;
  DatabaseManager._internal();

  DatabaseRepository? _repository;
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

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;
  
  // Offline SQLite database is always ready/configured
  bool get isConfigured => true;

  // Getters for saved config (kept as dummy for compatibility)
  String? get supabaseUrl => null;
  String? get supabaseAnonKey => null;

  // ── Initialization ─────────────────────────────────────────────────────────

  Future<void> init() async {
    debugPrint('[DatabaseManager] Initializing SQLite...');
    _setLoading(true);

    try {
      final localRepo = SqliteRepository();
      await localRepo.init();
      _repository = localRepo;
      debugPrint('[DatabaseManager] Connected to SQLite database');
      _error = null;
    } catch (e, stackTrace) {
      debugPrint('[DatabaseManager] SQLite initialization error: $e');
      debugPrint('[DatabaseManager] Stack trace: $stackTrace');
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // ── Configuration Dummies ──────────────────────────────────────────────────

  Future<bool> configureSupabase({
    required String url,
    required String anonKey,
  }) async {
    // No-op in SQLite offline mode
    return true;
  }

  Future<void> clearSupabaseConfig() async {
    _setLoading(true);
    try {
      // Clear all SQLite data instead
      await _repository?.clearAllData();
      debugPrint('[DatabaseManager] Local SQLite database cleared');
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  // ── Health Check ───────────────────────────────────────────────────────────

  Future<bool> testSupabaseConnection() async {
    return true;
  }

  Future<bool> testSupabaseConnectionWithCredentials({
    required String url,
    required String anonKey,
  }) async {
    return true;
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
