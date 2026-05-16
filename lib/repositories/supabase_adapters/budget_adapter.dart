import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/budget.dart';
import '../database_repository.dart';
import '../supabase_repository.dart';

/// Adapter สำหรับจัดการข้อมูลงบประมาณ (Budget) บน Supabase
class SupabaseBudgetAdapter implements BudgetRepositoryInterface {
  final SupabaseRepository repo;

  SupabaseBudgetAdapter(this.repo);

  SupabaseClient get client => repo.client;
  String? get currentUserId => repo.currentUserId;

  void _requireAuth() {
    if (currentUserId == null) {
      throw StateError('User not authenticated. Please login first.');
    }
  }

  Map<String, dynamic> _budgetToSupabase(Budget budget) {
    return {
      'id': budget.id,
      'user_id': currentUserId,
      'name': budget.name,
      'amount': budget.amount,
      'category_ids': jsonEncode(budget.categoryIds),
      'icon': budget.icon.codePoint,
      'color': SupabaseRepository.colorToSupabase(budget.color.toARGB32()),
      'sort_order': budget.sortOrder,
      'group_name': budget.groupName,
      'budget_type': budget.type.name,
    };
  }

  Budget _budgetFromSupabase(Map<String, dynamic> row) {
    final normalized = Map<String, dynamic>.from(row);
    if (normalized['color'] is int) {
      normalized['color'] = SupabaseRepository.colorFromSupabase(
        normalized['color'] as int,
      );
    }
    return Budget.fromMap(normalized);
  }

  @override
  Future<List<Budget>> getBudgets() async {
    _requireAuth();
    repo.log('Fetching budgets for user: $currentUserId');
    final response = await client
        .from('budgets')
        .select()
        .eq('user_id', currentUserId!)
        .order('sort_order');
    return (response as List).map((row) => _budgetFromSupabase(row)).toList();
  }

  @override
  Future<void> insertBudget(Budget budget) async {
    _requireAuth();
    repo.log('Inserting budget: ${budget.id} for user: $currentUserId');
    await client.from('budgets').insert(_budgetToSupabase(budget));
    await repo.updateSyncLog('budgets');
  }

  @override
  Future<void> updateBudget(Budget budget) async {
    _requireAuth();
    repo.log('Updating budget: ${budget.id} for user: $currentUserId');
    await client
        .from('budgets')
        .update(_budgetToSupabase(budget))
        .eq('id', budget.id)
        .eq('user_id', currentUserId!);
    await repo.updateSyncLog('budgets');
  }

  @override
  Future<void> updateBudgetSortOrder(String id, int sortOrder) async {
    _requireAuth();
    repo.log('Updating budget sort order: $id -> $sortOrder');
    try {
      final response = await client
          .from('budgets')
          .update({'sort_order': sortOrder})
          .eq('id', id)
          .eq('user_id', currentUserId!)
          .select();

      if ((response as List).isEmpty) {
        throw Exception('Failed to update budget sort order: No rows affected');
      }
      repo.log('Updated budget sort order successfully: $id');
      await repo.updateSyncLog('budgets');
    } catch (e) {
      repo.logError('Error updating budget sort order', e);
      rethrow;
    }
  }

  @override
  Future<void> deleteBudget(String id) async {
    _requireAuth();
    repo.log('Deleting budget: $id for user: $currentUserId');
    await client
        .from('budgets')
        .delete()
        .eq('id', id)
        .eq('user_id', currentUserId!);
    await repo.updateSyncLog('budgets');
  }

  @override
  Future<Set<String>> getExistingBudgetIds() async {
    _requireAuth();
    final response = await client
        .from('budgets')
        .select('id')
        .eq('user_id', currentUserId!);
    return (response as List).map((r) => r['id'] as String).toSet();
  }

  @override
  Future<void> bulkInsertBudgets(List<Budget> budgets) async {
    _requireAuth();
    repo.log(
      'Bulk inserting ${budgets.length} budgets for user: $currentUserId',
    );
    await repo.batchInsert(
      'budgets',
      budgets.map((b) => _budgetToSupabase(b)).toList(),
    );
  }
}
