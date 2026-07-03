import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/stock_holding.dart';
import '../database_repository.dart';
import '../supabase_repository.dart';

/// Adapter สำหรับจัดการข้อมูลพอร์ตโฟลิโอและหุ้น (Stock Holding) บน Supabase
class SupabasePortfolioAdapter implements PortfolioRepositoryInterface {
  final SupabaseRepository repo;

  SupabasePortfolioAdapter(this.repo);

  SupabaseClient get client => repo.client;
  String? get currentUserId => repo.currentUserId;

  void _requireAuth() {
    if (currentUserId == null) {
      throw StateError('User not authenticated. Please login first.');
    }
  }

  Map<String, dynamic> _holdingToSupabase(StockHolding holding) {
    return {
      'id': holding.id,
      'user_id': currentUserId,
      'portfolio_id': holding.portfolioId,
      'ticker': holding.ticker,
      'name': holding.name,
      'shares': holding.shares,
      'price_usd': holding.priceUsd,
      'cost_basis_usd': holding.costBasisUsd,
      'logo_url': holding.logoUrl,
      'sort_order': holding.sortOrder,
      'sell_plan_enabled': holding.sellPlanEnabled,
      'take_profit_pct': holding.takeProfitPct,
      'trailing_stop_pct': holding.trailingStopPct,
      'stop_loss_pct': holding.stopLossPct,
      'peak_profit_pct': holding.peakProfitPct,
      'portfolio_group': holding.portfolioGroup,
    };
  }

  StockHolding _holdingFromSupabase(Map<String, dynamic> row) {
    final normalized = repo.normalizeRow(row);
    return StockHolding.fromMap(normalized);
  }

  @override
  Future<List<StockHolding>> getPortfolioHoldings() async {
    _requireAuth();
    repo.log('Fetching portfolio holdings for user: $currentUserId');
    final response = await client
        .from('portfolio_holdings')
        .select()
        .eq('user_id', currentUserId!)
        .order('sort_order');
    return (response as List).map((row) => _holdingFromSupabase(row)).toList();
  }

  @override
  Future<void> insertHolding(StockHolding holding) async {
    _requireAuth();
    repo.log('Inserting holding: ${holding.id} for user: $currentUserId');
    await client.from('portfolio_holdings').insert(_holdingToSupabase(holding));
    await repo.updateSyncLog('portfolio');
  }

  @override
  Future<void> updateHolding(StockHolding holding) async {
    _requireAuth();
    repo.log('Updating holding: ${holding.id} for user: $currentUserId');
    await client
        .from('portfolio_holdings')
        .update(_holdingToSupabase(holding))
        .eq('id', holding.id)
        .eq('user_id', currentUserId!);
    await repo.updateSyncLog('portfolio');
  }

  @override
  Future<void> updateHoldingMarketData(StockHolding holding) async {
    _requireAuth();
    repo.log('Updating holding market data: ${holding.id}');
    await client
        .from('portfolio_holdings')
        .update({
          'price_usd': holding.priceUsd,
          'logo_url': holding.logoUrl,
          'peak_profit_pct': holding.peakProfitPct,
        })
        .eq('id', holding.id)
        .eq('user_id', currentUserId!);
    await repo.updateSyncLog('portfolio');
  }

  @override
  Future<void> updateHoldingSortOrder(String id, int sortOrder) async {
    _requireAuth();
    repo.log('Updating holding sort order: $id -> $sortOrder');
    try {
      final response = await client
          .from('portfolio_holdings')
          .update({'sort_order': sortOrder})
          .eq('id', id)
          .eq('user_id', currentUserId!)
          .select();

      if ((response as List).isEmpty) {
        throw Exception(
          'Failed to update holding sort order: No rows affected',
        );
      }
      repo.log('Updated holding sort order successfully: $id');
      await repo.updateSyncLog('portfolio');
    } catch (e) {
      repo.logError('Error updating holding sort order', e);
      rethrow;
    }
  }

  @override
  Future<void> deleteHolding(String id) async {
    _requireAuth();
    repo.log('Deleting holding: $id for user: $currentUserId');
    await client
        .from('portfolio_holdings')
        .delete()
        .eq('id', id)
        .eq('user_id', currentUserId!);
    await repo.updateSyncLog('portfolio');
  }

  @override
  Future<void> deleteHoldingsByPortfolio(String portfolioId) async {
    _requireAuth();
    repo.log(
      'Deleting holdings for portfolio: $portfolioId, user: $currentUserId',
    );
    await client
        .from('portfolio_holdings')
        .delete()
        .eq('portfolio_id', portfolioId)
        .eq('user_id', currentUserId!);
    await repo.updateSyncLog('portfolio');
  }

  @override
  Future<Set<String>> getExistingHoldingIds() async {
    _requireAuth();
    final response = await client
        .from('portfolio_holdings')
        .select('id')
        .eq('user_id', currentUserId!);
    return (response as List).map((r) => r['id'] as String).toSet();
  }

  @override
  Future<void> bulkInsertHoldings(List<StockHolding> holdings) async {
    _requireAuth();
    repo.log(
      'Bulk inserting ${holdings.length} holdings for user: $currentUserId',
    );
    await repo.batchInsert(
      'portfolio_holdings',
      holdings.map((h) => _holdingToSupabase(h)).toList(),
    );
  }
}
