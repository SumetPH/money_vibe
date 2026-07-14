import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/stock_purchase.dart';
import '../database_repository.dart';
import '../supabase_repository.dart';

class SupabaseStockPurchaseAdapter implements StockPurchaseRepositoryInterface {
  final SupabaseRepository repo;

  SupabaseStockPurchaseAdapter(this.repo);

  SupabaseClient get client => repo.client;

  String get _userId {
    final userId = repo.currentUserId;
    if (userId == null) throw StateError('User not authenticated.');
    return userId;
  }

  Map<String, dynamic> _toRow(StockPurchase purchase) => {
    ...purchase.toMap(),
    'user_id': _userId,
  };

  @override
  Future<List<StockPurchase>> getStockPurchases() async {
    final userId = _userId;
    final response = await client
        .from('stock_purchases')
        .select()
        .eq('user_id', userId)
        .order('bought_at', ascending: false);
    return (response as List)
        .map((row) => StockPurchase.fromMap(repo.normalizeRow(row)))
        .toList();
  }

  @override
  Future<void> insertStockPurchase(StockPurchase purchase) async {
    await client.from('stock_purchases').insert(_toRow(purchase));
    await repo.updateSyncLog('portfolio');
  }

  @override
  Future<void> updateStockPurchase(StockPurchase purchase) async {
    await client
        .from('stock_purchases')
        .update(_toRow(purchase))
        .eq('id', purchase.id)
        .eq('user_id', _userId);
    await repo.updateSyncLog('portfolio');
  }

  @override
  Future<void> deleteStockPurchase(String id) async {
    await client
        .from('stock_purchases')
        .delete()
        .eq('id', id)
        .eq('user_id', _userId);
    await repo.updateSyncLog('portfolio');
  }
}
