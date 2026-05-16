import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/recurring_transaction.dart';
import '../database_repository.dart';
import '../supabase_repository.dart';

/// Adapter สำหรับจัดการข้อมูลรายการเกิดซ้ำ (Recurring & Occurrence) บน Supabase
class SupabaseRecurringAdapter implements RecurringRepositoryInterface {
  final SupabaseRepository repo;

  SupabaseRecurringAdapter(this.repo);

  SupabaseClient get client => repo.client;
  String? get currentUserId => repo.currentUserId;

  void _requireAuth() {
    if (currentUserId == null) {
      throw StateError('User not authenticated. Please login first.');
    }
  }

  Map<String, dynamic> _recurringToSupabase(RecurringTransaction recurring) {
    return {
      'id': recurring.id,
      'user_id': currentUserId,
      'name': recurring.name,
      'icon': recurring.icon.codePoint,
      'color': SupabaseRepository.colorToSupabase(recurring.color.toARGB32()),
      'start_date': recurring.startDate.toIso8601String(),
      'end_date': recurring.endDate?.toIso8601String(),
      'day_of_month': recurring.dayOfMonth,
      'transaction_type': recurring.transactionType.name,
      'amount': recurring.amount,
      'account_id': recurring.accountId,
      'to_account_id': recurring.toAccountId,
      'category_id': recurring.categoryId,
      'note': recurring.note,
      'sort_order': recurring.sortOrder,
      'is_hidden': recurring.isHidden ? 1 : 0,
      'notification_enabled': recurring.notificationEnabled,
      'notification_hour': recurring.notificationHour,
      'notification_minute': recurring.notificationMinute,
    };
  }

  RecurringTransaction _recurringFromSupabase(Map<String, dynamic> row) {
    final normalized = Map<String, dynamic>.from(row);
    if (normalized['color'] is int) {
      normalized['color'] = SupabaseRepository.colorFromSupabase(
        normalized['color'] as int,
      );
    }
    return RecurringTransaction.fromMap(normalized);
  }

  Map<String, dynamic> _occurrenceToSupabase(RecurringOccurrence occurrence) {
    return {
      'id': occurrence.id,
      'user_id': currentUserId,
      'recurring_id': occurrence.recurringId,
      'due_date': occurrence.dueDate.toIso8601String(),
      'transaction_id': occurrence.transactionId,
      'status': occurrence.status.name,
    };
  }

  RecurringOccurrence _occurrenceFromSupabase(Map<String, dynamic> row) {
    final normalized = repo.normalizeRow(row);
    return RecurringOccurrence.fromMap(normalized);
  }

  // ── Recurring Transactions ─────────────────────────────────────────────────

  @override
  Future<List<RecurringTransaction>> getRecurringTransactions() async {
    _requireAuth();
    repo.log('Fetching recurring transactions for user: $currentUserId');
    final response = await client
        .from('recurring_transactions')
        .select()
        .eq('user_id', currentUserId!)
        .order('sort_order');
    return (response as List)
        .map((row) => _recurringFromSupabase(row))
        .toList();
  }

  @override
  Future<void> insertRecurringTransaction(
    RecurringTransaction recurring,
  ) async {
    _requireAuth();
    repo.log(
      'Inserting recurring transaction: ${recurring.id} for user: $currentUserId',
    );
    await client
        .from('recurring_transactions')
        .insert(_recurringToSupabase(recurring));
    await repo.updateSyncLog('recurring');
  }

  @override
  Future<void> updateRecurringTransaction(
    RecurringTransaction recurring,
  ) async {
    _requireAuth();
    repo.log(
      'Updating recurring transaction: ${recurring.id} for user: $currentUserId',
    );
    await client
        .from('recurring_transactions')
        .update(_recurringToSupabase(recurring))
        .eq('id', recurring.id)
        .eq('user_id', currentUserId!);
    await repo.updateSyncLog('recurring');
  }

  @override
  Future<void> deleteRecurringTransaction(String id) async {
    _requireAuth();
    repo.log('Deleting recurring transaction: $id for user: $currentUserId');
    await client
        .from('recurring_transactions')
        .delete()
        .eq('id', id)
        .eq('user_id', currentUserId!);
    await repo.updateSyncLog('recurring');
  }

  @override
  Future<void> updateRecurringSortOrder(String id, int sortOrder) async {
    _requireAuth();
    repo.log('Updating recurring sort order: $id -> $sortOrder');
    try {
      final response = await client
          .from('recurring_transactions')
          .update({'sort_order': sortOrder})
          .eq('id', id)
          .eq('user_id', currentUserId!)
          .select();

      if ((response as List).isEmpty) {
        throw Exception(
          'Failed to update recurring sort order: No rows affected',
        );
      }
      repo.log('Updated recurring sort order successfully: $id');
      await repo.updateSyncLog('recurring');
    } catch (e) {
      repo.logError('Error updating recurring sort order', e);
      rethrow;
    }
  }

  @override
  Future<Set<String>> getExistingRecurringIds() async {
    _requireAuth();
    final response = await client
        .from('recurring_transactions')
        .select('id')
        .eq('user_id', currentUserId!);
    return (response as List).map((r) => r['id'] as String).toSet();
  }

  @override
  Future<void> bulkInsertRecurring(List<RecurringTransaction> recurring) async {
    _requireAuth();
    repo.log(
      'Bulk inserting ${recurring.length} recurring transactions for user: $currentUserId',
    );
    await repo.batchInsert(
      'recurring_transactions',
      recurring.map((r) => _recurringToSupabase(r)).toList(),
    );
  }

  // ── Recurring Occurrences ──────────────────────────────────────────────────

  @override
  Future<List<RecurringOccurrence>> getRecurringOccurrences() async {
    _requireAuth();
    repo.log('Fetching recurring occurrences for user: $currentUserId');
    final response = await client
        .from('recurring_occurrences')
        .select()
        .eq('user_id', currentUserId!)
        .order('due_date');
    return (response as List)
        .map((row) => _occurrenceFromSupabase(row))
        .toList();
  }

  @override
  Future<List<RecurringOccurrence>> getOccurrencesFor(
    String recurringId,
  ) async {
    _requireAuth();
    repo.log('Fetching occurrences for: $recurringId, user: $currentUserId');
    final response = await client
        .from('recurring_occurrences')
        .select()
        .eq('recurring_id', recurringId)
        .eq('user_id', currentUserId!)
        .order('due_date');
    return (response as List)
        .map((row) => _occurrenceFromSupabase(row))
        .toList();
  }

  @override
  Future<void> insertRecurringOccurrence(RecurringOccurrence occurrence) async {
    _requireAuth();
    repo.log('Inserting occurrence: ${occurrence.id} for user: $currentUserId');
    await client
        .from('recurring_occurrences')
        .insert(_occurrenceToSupabase(occurrence));
    await repo.updateSyncLog('recurring');
  }

  @override
  Future<void> deleteOccurrence(String id) async {
    _requireAuth();
    repo.log('Deleting occurrence: $id for user: $currentUserId');
    await client
        .from('recurring_occurrences')
        .delete()
        .eq('id', id)
        .eq('user_id', currentUserId!);
    await repo.updateSyncLog('recurring');
  }

  @override
  Future<void> deleteOccurrencesByRecurring(String recurringId) async {
    _requireAuth();
    repo.log(
      'Deleting occurrences for recurring: $recurringId, user: $currentUserId',
    );
    await client
        .from('recurring_occurrences')
        .delete()
        .eq('recurring_id', recurringId)
        .eq('user_id', currentUserId!);
    await repo.updateSyncLog('recurring');
  }

  @override
  Future<Set<String>> getExistingOccurrenceIds() async {
    _requireAuth();
    final response = await client.from('recurring_occurrences').select('id');
    return (response as List).map((r) => r['id'] as String).toSet();
  }

  @override
  Future<void> bulkInsertOccurrences(
    List<RecurringOccurrence> occurrences,
  ) async {
    _requireAuth();
    repo.log(
      'Bulk inserting ${occurrences.length} occurrences for user: $currentUserId',
    );
    await repo.batchInsert(
      'recurring_occurrences',
      occurrences.map((o) => _occurrenceToSupabase(o)).toList(),
    );
  }
}
