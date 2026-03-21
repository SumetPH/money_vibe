import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../repositories/database_repository.dart';
import '../services/database_manager.dart';
import '../services/recurring_notification_service.dart';
import '../models/recurring_transaction.dart';

class RecurringTransactionProvider extends ChangeNotifier {
  final _uuid = const Uuid();
  final DatabaseManager _dbManager = DatabaseManager();
  final RecurringNotificationService _notificationService =
      RecurringNotificationService.instance;

  final List<RecurringTransaction> _recurring = [];
  final List<RecurringOccurrence> _occurrences = [];
  bool _isLoading = false;
  bool _showHiddenRecurring = false;

  bool get isLoading => _isLoading;
  bool get showHiddenRecurring => _showHiddenRecurring;

  void toggleShowHiddenRecurring() {
    _showHiddenRecurring = !_showHiddenRecurring;
    notifyListeners();
  }

  List<RecurringTransaction> get recurring {
    if (_showHiddenRecurring) return List.unmodifiable(_recurring);
    return _recurring.where((r) => !r.isHidden).toList();
  }

  List<RecurringTransaction> get allRecurring => List.unmodifiable(_recurring);

  // ── Helper ────────────────────────────────────────────────────────────────

  DatabaseRepository get _db => _dbManager.repository;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    debugPrint('RecurringTransactionProvider: Initializing...');
    _setLoading(true);

    try {
      final recurring = await _db.getRecurringTransactions();
      final occurrences = await _db.getRecurringOccurrences();

      // Sort by sortOrder to ensure correct order
      recurring.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      _recurring.clear();
      _recurring.addAll(recurring);

      _occurrences.clear();
      _occurrences.addAll(occurrences);

      await _notificationService.rescheduleAllNotifications(
        recurring: _recurring,
        occurrences: _occurrences,
      );

      debugPrint(
        'RecurringTransactionProvider: Loaded ${_recurring.length} recurring, '
        '${_occurrences.length} occurrences',
      );
    } catch (e) {
      debugPrint('RecurringTransactionProvider: Init error: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> reload() async {
    debugPrint('RecurringTransactionProvider: Reloading...');
    return init();
  }

  String generateId() => _uuid.v4();

  // ── Recurring queries ──────────────────────────────────────────────────────

  List<RecurringOccurrence> occurrencesFor(String recurringId) {
    return _occurrences.where((o) => o.recurringId == recurringId).toList();
  }

  RecurringOccurrence? findOccurrence(String recurringId, DateTime dueDate) {
    final key = _dateKey(dueDate);
    try {
      return _occurrences.firstWhere(
        (o) => o.recurringId == recurringId && _dateKey(o.dueDate) == key,
      );
    } catch (_) {
      return null;
    }
  }

  /// Find occurrence by linked transaction ID
  RecurringOccurrence? findOccurrenceByTransactionId(String transactionId) {
    try {
      return _occurrences.firstWhere((o) => o.transactionId == transactionId);
    } catch (_) {
      return null;
    }
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ── CRUD ───────────────────────────────────────────────────────────────────

  Future<void> addRecurring(RecurringTransaction r) async {
    final sortOrder = _recurring.isEmpty
        ? 0
        : (_recurring.map((x) => x.sortOrder).reduce((a, b) => a > b ? a : b) +
              10);
    final updated = r.copyWith(sortOrder: sortOrder);

    _recurring.add(updated);
    notifyListeners();

    try {
      await _db.insertRecurringTransaction(updated);
      await _syncNotificationForRecurring(updated.id);
    } catch (e) {
      debugPrint('RecurringTransactionProvider: Error adding recurring: $e');
      _recurring.removeWhere((item) => item.id == updated.id);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateRecurring(RecurringTransaction r) async {
    final idx = _recurring.indexWhere((x) => x.id == r.id);
    if (idx == -1) return;

    final oldRecurring = _recurring[idx];
    _recurring[idx] = r;
    notifyListeners();

    try {
      await _db.updateRecurringTransaction(r);
      await _syncNotificationForRecurring(r.id);
    } catch (e) {
      debugPrint('RecurringTransactionProvider: Error updating recurring: $e');
      _recurring[idx] = oldRecurring;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteRecurring(String id) async {
    final idx = _recurring.indexWhere((r) => r.id == id);
    if (idx == -1) return;

    final oldRecurring = _recurring[idx];
    final oldOccurrences = _occurrences
        .where((o) => o.recurringId == id)
        .toList();

    _recurring.removeAt(idx);
    _occurrences.removeWhere((o) => o.recurringId == id);
    notifyListeners();

    try {
      await _db.deleteRecurringTransaction(id);
      await _db.deleteOccurrencesByRecurring(id);
      await _notificationService.cancelRecurringNotification(id);
    } catch (e) {
      debugPrint('RecurringTransactionProvider: Error deleting recurring: $e');
      _recurring.insert(idx, oldRecurring);
      _occurrences.addAll(oldOccurrences);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> reorderRecurring(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;

    final moved = _recurring.removeAt(oldIndex);
    _recurring.insert(newIndex, moved);

    for (var i = 0; i < _recurring.length; i++) {
      _recurring[i] = _recurring[i].copyWith(sortOrder: i * 10);
    }
    notifyListeners();

    try {
      for (var i = 0; i < _recurring.length; i++) {
        await _db.updateRecurringSortOrder(_recurring[i].id, i * 10);
      }
    } catch (e) {
      debugPrint(
        'RecurringTransactionProvider: Error reordering recurring: $e',
      );
      await reload();
      rethrow;
    }
  }

  // ── Occurrence management ──────────────────────────────────────────────────

  Future<RecurringOccurrence> markOccurrenceDone(
    String recurringId,
    DateTime dueDate,
    String transactionId,
  ) async {
    // Remove existing occurrence first
    final existing = findOccurrence(recurringId, dueDate);
    if (existing != null) {
      _occurrences.removeWhere((o) => o.id == existing.id);
    }

    final occ = RecurringOccurrence(
      id: generateId(),
      recurringId: recurringId,
      dueDate: dueDate,
      transactionId: transactionId,
      status: OccurrenceStatus.done,
    );

    _occurrences.add(occ);
    notifyListeners();

    try {
      if (existing != null) {
        await _db.deleteOccurrence(existing.id);
      }
      await _db.insertRecurringOccurrence(occ);
      await _syncNotificationForRecurring(recurringId);
    } catch (e) {
      debugPrint(
        'RecurringTransactionProvider: Error marking occurrence done: $e',
      );
      _occurrences.removeWhere((o) => o.id == occ.id);
      if (existing != null) {
        _occurrences.add(existing);
      }
      notifyListeners();
      rethrow;
    }

    return occ;
  }

  Future<void> markOccurrenceSkipped(
    String recurringId,
    DateTime dueDate,
  ) async {
    // Remove existing occurrence first
    final existing = findOccurrence(recurringId, dueDate);
    if (existing != null) {
      _occurrences.removeWhere((o) => o.id == existing.id);
    }

    final occ = RecurringOccurrence(
      id: generateId(),
      recurringId: recurringId,
      dueDate: dueDate,
      status: OccurrenceStatus.skipped,
    );

    _occurrences.add(occ);
    notifyListeners();

    try {
      if (existing != null) {
        await _db.deleteOccurrence(existing.id);
      }
      await _db.insertRecurringOccurrence(occ);
      await _syncNotificationForRecurring(recurringId);
    } catch (e) {
      debugPrint(
        'RecurringTransactionProvider: Error marking occurrence skipped: $e',
      );
      _occurrences.removeWhere((o) => o.id == occ.id);
      if (existing != null) {
        _occurrences.add(existing);
      }
      notifyListeners();
      rethrow;
    }
  }

  Future<void> undoOccurrence(String recurringId, DateTime dueDate) async {
    final existing = findOccurrence(recurringId, dueDate);
    if (existing == null) return;

    _occurrences.removeWhere((o) => o.id == existing.id);
    notifyListeners();

    try {
      await _db.deleteOccurrence(existing.id);
      await _syncNotificationForRecurring(recurringId);
    } catch (e) {
      debugPrint('RecurringTransactionProvider: Error undoing occurrence: $e');
      _occurrences.add(existing);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _syncNotificationForRecurring(String recurringId) async {
    final recurring = _findRecurringById(recurringId);
    if (recurring == null) return;

    await _notificationService.syncRecurringNotification(
      recurring: recurring,
      occurrences: occurrencesFor(recurringId),
    );
  }

  RecurringTransaction? _findRecurringById(String recurringId) {
    for (final recurring in _recurring) {
      if (recurring.id == recurringId) return recurring;
    }
    return null;
  }
}
