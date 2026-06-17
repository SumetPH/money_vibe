import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/stock_trade.dart';
import '../database_repository.dart';
import '../supabase_repository.dart';

/// Adapter สำหรับจัดการประวัติการขายหุ้นบน Supabase
class SupabaseStockTradeAdapter implements StockTradeRepositoryInterface {
  final SupabaseRepository repo;

  SupabaseStockTradeAdapter(this.repo);

  SupabaseClient get client => repo.client;
  String? get currentUserId => repo.currentUserId;

  void _requireAuth() {
    if (currentUserId == null) {
      throw StateError('User not authenticated. Please login first.');
    }
  }

  Map<String, dynamic> _tradeToSupabase(StockTrade trade) {
    return {
      'id': trade.id,
      'user_id': currentUserId,
      'portfolio_id': trade.portfolioId,
      'holding_id': trade.holdingId,
      'ticker': trade.ticker,
      'name': trade.name,
      'logo_url': trade.logoUrl,
      'shares_sold': trade.sharesSold,
      'sell_price_usd': trade.sellPriceUsd,
      'cash_received_usd': trade.cashReceivedUsd,
      'cost_basis_usd': trade.costBasisUsd,
      'realized_pnl_usd': trade.realizedPnlUsd,
      'sold_at': trade.soldAt.toIso8601String(),
      'created_at': trade.createdAt.toIso8601String(),
    };
  }

  StockTrade _tradeFromSupabase(Map<String, dynamic> row) {
    final normalized = repo.normalizeRow(row);
    return StockTrade.fromMap(normalized);
  }

  @override
  Future<List<StockTrade>> getStockTrades() async {
    _requireAuth();
    repo.log('Fetching stock trades for user: $currentUserId');
    final response = await client
        .from('stock_trades')
        .select()
        .eq('user_id', currentUserId!)
        .order('sold_at', ascending: false);
    return (response as List).map((row) => _tradeFromSupabase(row)).toList();
  }

  @override
  Future<void> insertStockTrade(StockTrade trade) async {
    _requireAuth();
    repo.log('Inserting stock trade: ${trade.id} for user: $currentUserId');
    await client.from('stock_trades').insert(_tradeToSupabase(trade));
    await repo.updateSyncLog('portfolio');
  }

  @override
  Future<void> updateStockTrade(StockTrade trade) async {
    _requireAuth();
    repo.log('Updating stock trade: ${trade.id} for user: $currentUserId');
    await client
        .from('stock_trades')
        .update(_tradeToSupabase(trade))
        .eq('id', trade.id)
        .eq('user_id', currentUserId!);
    await repo.updateSyncLog('portfolio');
  }

  @override
  Future<void> deleteStockTrade(String id) async {
    _requireAuth();
    repo.log('Deleting stock trade: $id for user: $currentUserId');
    await client
        .from('stock_trades')
        .delete()
        .eq('id', id)
        .eq('user_id', currentUserId!);
    await repo.updateSyncLog('portfolio');
  }

  @override
  Future<Set<String>> getExistingStockTradeIds() async {
    _requireAuth();
    final response = await client
        .from('stock_trades')
        .select('id')
        .eq('user_id', currentUserId!);
    return (response as List).map((r) => r['id'] as String).toSet();
  }

  @override
  Future<void> bulkInsertStockTrades(List<StockTrade> trades) async {
    _requireAuth();
    repo.log('Bulk inserting ${trades.length} stock trades');
    await repo.batchInsert(
      'stock_trades',
      trades.map((t) => _tradeToSupabase(t)).toList(),
    );
    await repo.updateSyncLog('portfolio');
  }
}
