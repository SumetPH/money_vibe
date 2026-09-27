import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/fixed_cash_flow_item.dart';
import '../database_repository.dart';
import '../supabase_repository.dart';

/// Adapter สำหรับรายการเงินเข้าออกประจำและ paid mark บน Supabase
class SupabaseCashFlowAdapter implements CashFlowRepositoryInterface {
  static const _itemsTable = 'fixed_cash_flow_items';
  static const _marksTable = 'fixed_cash_flow_paid_marks';

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
  Future<List<FixedCashFlowPaidMark>> getFixedCashFlowPaidMarks() async {
    _requireAuth();
    repo.log('Fetching fixed cash-flow paid marks: $currentUserId');
    final response = await client
        .from(_marksTable)
        .select()
        .eq('user_id', currentUserId!)
        .order('month');
    return (response as List)
        .map(
          (row) => FixedCashFlowPaidMark.fromMap(
            repo.normalizeRow(row as Map<String, dynamic>),
          ),
        )
        .toList();
  }

  @override
  Future<void> upsertFixedCashFlowPaidMark(FixedCashFlowPaidMark mark) async {
    _requireAuth();
    repo.log('Marking fixed cash-flow item paid: ${mark.itemId}/${mark.month}');
    await client.from(_marksTable).upsert({
      ...mark.toMap(),
      'user_id': currentUserId,
    }, onConflict: 'item_id, month');
  }

  @override
  Future<void> deleteFixedCashFlowPaidMark(String itemId, String month) async {
    _requireAuth();
    repo.log('Unmarking fixed cash-flow item: $itemId/$month');
    await client
        .from(_marksTable)
        .delete()
        .eq('item_id', itemId)
        .eq('month', month)
        .eq('user_id', currentUserId!);
  }
}
