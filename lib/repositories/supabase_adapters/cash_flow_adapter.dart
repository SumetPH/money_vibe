import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/budget_forecast_setting.dart';
import '../../models/fixed_cash_flow_item.dart';
import '../../models/planned_purchase.dart';
import '../database_repository.dart';
import '../supabase_repository.dart';

/// Adapter สำหรับรายการเงินเข้าออก, รายการอยากซื้อ
/// และการตั้งค่างบรายงวดบน Supabase
class SupabaseCashFlowAdapter implements CashFlowRepositoryInterface {
  static const _itemsTable = 'fixed_cash_flow_items';
  static const _purchasesTable = 'planned_purchases';
  static const _budgetSettingsTable = 'budget_forecast_settings';

  final SupabaseRepository repo;

  SupabaseCashFlowAdapter(this.repo);

  SupabaseClient get client => repo.client;
  String? get currentUserId => repo.currentUserId;

  void _requireAuth() {
    if (currentUserId == null) {
      throw StateError('User not authenticated. Please login first.');
    }
  }

  Map<String, dynamic> _itemToSupabase(FixedCashFlowItem item) => {
    ...item.toMap(),
    'user_id': currentUserId,
  };

  @override
  Future<List<FixedCashFlowItem>> getFixedCashFlowItems() async {
    _requireAuth();
    repo.log('Fetching fixed cash-flow items: $currentUserId');
    final response = await client
        .from(_itemsTable)
        .select()
        .eq('user_id', currentUserId!)
        .order('sort_order');
    return (response as List)
        .map(
          (row) => FixedCashFlowItem.fromMap(
            repo.normalizeRow(row as Map<String, dynamic>),
          ),
        )
        .toList();
  }

  @override
  Future<void> insertFixedCashFlowItem(FixedCashFlowItem item) async {
    _requireAuth();
    repo.log('Inserting fixed cash-flow item: ${item.id}');
    await client.from(_itemsTable).insert(_itemToSupabase(item));
  }

  @override
  Future<void> updateFixedCashFlowItem(FixedCashFlowItem item) async {
    _requireAuth();
    repo.log('Updating fixed cash-flow item: ${item.id}');
    await client
        .from(_itemsTable)
        .update(_itemToSupabase(item))
        .eq('id', item.id)
        .eq('user_id', currentUserId!);
  }

  @override
  Future<void> deleteFixedCashFlowItem(String id) async {
    _requireAuth();
    repo.log('Deleting fixed cash-flow item: $id');
    await client
        .from(_itemsTable)
        .delete()
        .eq('id', id)
        .eq('user_id', currentUserId!);
  }

  @override
  Future<List<PlannedPurchase>> getPlannedPurchases() async {
    _requireAuth();
    repo.log('Fetching planned purchases: $currentUserId');
    final response = await client
        .from(_purchasesTable)
        .select()
        .eq('user_id', currentUserId!)
        .order('sort_order');
    return (response as List)
        .map(
          (row) => PlannedPurchase.fromMap(
            repo.normalizeRow(row as Map<String, dynamic>),
          ),
        )
        .toList();
  }

  @override
  Future<void> insertPlannedPurchase(PlannedPurchase purchase) async {
    _requireAuth();
    repo.log('Inserting planned purchase: ${purchase.id}');
    await client.from(_purchasesTable).insert({
      ...purchase.toMap(),
      'user_id': currentUserId,
    });
  }

  @override
  Future<void> updatePlannedPurchase(PlannedPurchase purchase) async {
    _requireAuth();
    repo.log('Updating planned purchase: ${purchase.id}');
    await client
        .from(_purchasesTable)
        .update({...purchase.toMap(), 'user_id': currentUserId})
        .eq('id', purchase.id)
        .eq('user_id', currentUserId!);
  }

  @override
  Future<void> deletePlannedPurchase(String id) async {
    _requireAuth();
    repo.log('Deleting planned purchase: $id');
    await client
        .from(_purchasesTable)
        .delete()
        .eq('id', id)
        .eq('user_id', currentUserId!);
  }

  @override
  Future<List<BudgetForecastSetting>> getBudgetForecastSettings() async {
    _requireAuth();
    repo.log('Fetching budget forecast settings: $currentUserId');
    final response = await client
        .from(_budgetSettingsTable)
        .select()
        .eq('user_id', currentUserId!)
        .order('period_end_on');
    return (response as List)
        .map(
          (row) => BudgetForecastSetting.fromMap(
            repo.normalizeRow(row as Map<String, dynamic>),
          ),
        )
        .toList();
  }

  @override
  Future<void> upsertBudgetForecastSetting(
    BudgetForecastSetting setting,
  ) async {
    _requireAuth();
    repo.log(
      'Saving budget forecast setting: ${setting.budgetId}/'
      '${BudgetForecastSetting.periodKey(setting.periodEnd)}',
    );
    await client.from(_budgetSettingsTable).upsert({
      ...setting.toMap(),
      'user_id': currentUserId,
    }, onConflict: 'budget_id, period_end_on');
  }

  @override
  Future<void> deleteBudgetForecastSetting(
    String budgetId,
    DateTime periodEnd,
  ) async {
    _requireAuth();
    final periodKey = BudgetForecastSetting.periodKey(periodEnd);
    repo.log('Deleting budget forecast setting: $budgetId/$periodKey');
    await client
        .from(_budgetSettingsTable)
        .delete()
        .eq('budget_id', budgetId)
        .eq('period_end_on', periodKey)
        .eq('user_id', currentUserId!);
  }
}
