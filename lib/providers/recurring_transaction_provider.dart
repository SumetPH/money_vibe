import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../models/recurring_transaction.dart';

class RecurringTransactionProvider extends ChangeNotifier {
  final _uuid = const Uuid();
  final _db = DatabaseHelper.instance;

  final List<RecurringTransaction> _recurring = [];
  final List<RecurringOccurrence> _occurrences = [];

  List<RecurringTransaction> get recurring => List.unmodifiable(_recurring);

  Future<void> init() async {
    debugPrint('RecurringTransactionProvider: Initializing...');
    _recurring.clear();
    _occurrences.clear();
    final rows = await _db.getRecurringTransactions();
    for (final row in rows) {
      _recurring.add(RecurringTransaction.fromMap(row));
    }
    final occRows = await _db.getRecurringOccurrences();
    for (final row in occRows) {
      _occurrences.add(RecurringOccurrence.fromMap(row));
    }
    notifyListeners();
    debugPrint(
      'RecurringTransactionProvider: Loaded ${_recurring.length} recurring, '
      '${_occurrences.length} occurrences',
    );
  }

  Future<void> reload() => init();

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
    await _db.insertRecurringTransaction(updated.toMap());
    _recurring.add(updated);
    notifyListeners();
  }

  Future<void> updateRecurring(RecurringTransaction r) async {
    await _db.updateRecurringTransaction(r.toMap());
    final idx = _recurring.indexWhere((x) => x.id == r.id);
    if (idx != -1) {
      _recurring[idx] = r;
      notifyListeners();
    }
  }

  Future<void> deleteRecurring(String id) async {
    await _db.deleteRecurringTransaction(id);
    await _db.deleteOccurrencesByRecurring(id);
    _recurring.removeWhere((r) => r.id == id);
    _occurrences.removeWhere((o) => o.recurringId == id);
    notifyListeners();
  }

  Future<void> reorderRecurring(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final moved = _recurring.removeAt(oldIndex);
    _recurring.insert(newIndex, moved);
    for (var i = 0; i < _recurring.length; i++) {
      final updated = _recurring[i].copyWith(sortOrder: i * 10);
      _recurring[i] = updated;
      await _db.updateRecurringSortOrder(updated.id, i * 10);
    }
    notifyListeners();
  }

  // ── Occurrence management ──────────────────────────────────────────────────

  Future<RecurringOccurrence> markOccurrenceDone(
    String recurringId,
    DateTime dueDate,
    String transactionId,
  ) async {
    await _removeExistingOccurrence(recurringId, dueDate);
    final occ = RecurringOccurrence(
      id: generateId(),
      recurringId: recurringId,
      dueDate: dueDate,
      transactionId: transactionId,
      status: OccurrenceStatus.done,
    );
    await _db.insertRecurringOccurrence(occ.toMap());
    _occurrences.add(occ);
    notifyListeners();
    return occ;
  }

  Future<void> markOccurrenceSkipped(
    String recurringId,
    DateTime dueDate,
  ) async {
    await _removeExistingOccurrence(recurringId, dueDate);
    final occ = RecurringOccurrence(
      id: generateId(),
      recurringId: recurringId,
      dueDate: dueDate,
      status: OccurrenceStatus.skipped,
    );
    await _db.insertRecurringOccurrence(occ.toMap());
    _occurrences.add(occ);
    notifyListeners();
  }

  Future<void> undoOccurrence(String recurringId, DateTime dueDate) async {
    await _removeExistingOccurrence(recurringId, dueDate);
    notifyListeners();
  }

  Future<void> _removeExistingOccurrence(
    String recurringId,
    DateTime dueDate,
  ) async {
    final existing = findOccurrence(recurringId, dueDate);
    if (existing != null) {
      await _db.deleteOccurrence(existing.id);
      _occurrences.removeWhere((o) => o.id == existing.id);
    }
  }
}
