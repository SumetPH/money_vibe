import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/investment_plan.dart';
import '../database_repository.dart';
import '../supabase_repository.dart';

/// Adapter สำหรับจัดการแผนลงทุนของพอร์ตบน Supabase
class SupabaseInvestmentPlanAdapter
    implements InvestmentPlanRepositoryInterface {
  final SupabaseRepository repo;

  SupabaseInvestmentPlanAdapter(this.repo);

  SupabaseClient get client => repo.client;
  String? get currentUserId => repo.currentUserId;

  void _requireAuth() {
    if (currentUserId == null) {
      throw StateError('User not authenticated. Please login first.');
    }
  }

  Map<String, dynamic> _monthStatusToSupabase(
    InvestmentPlanMonthStatus status,
  ) => {
    'id': status.id,
    'user_id': currentUserId,
    'portfolio_id': status.portfolioId,
    'dca_month': status.dcaMonth,
    'dca_completed': status.dcaCompleted,
  };

  Map<String, dynamic> _allocationTargetToSupabase(
    PortfolioAllocationTarget target,
  ) => {
    'id': target.id,
    'user_id': currentUserId,
    'portfolio_id': target.portfolioId,
    'holding_id': target.holdingId,
    'ticker': target.ticker,
    'target_percent': target.targetPercent,
    'is_enabled': target.isEnabled,
    'sort_order': target.sortOrder,
  };

  @override
  Future<List<InvestmentPlanMonthStatus>>
  getInvestmentPlanMonthStatuses() async {
    _requireAuth();
    repo.log('Fetching investment plan month statuses: $currentUserId');
    final response = await client
        .from('portfolio_investment_plans')
        .select()
        .eq('user_id', currentUserId!)
        .order('dca_month');
    return (response as List)
        .map(
          (row) => InvestmentPlanMonthStatus.fromMap(
            repo.normalizeRow(row as Map<String, dynamic>),
          ),
        )
        .toList();
  }

  @override
  Future<void> upsertInvestmentPlanMonthStatus(
    InvestmentPlanMonthStatus status,
  ) async {
    _requireAuth();
    repo.log(
      'Upserting investment plan month status: '
      '${status.portfolioId}/${status.dcaMonth}',
    );
    await client
        .from('portfolio_investment_plans')
        .upsert(
          _monthStatusToSupabase(status),
          onConflict: 'user_id, portfolio_id, dca_month',
        );
    await repo.updateSyncLog('portfolio');
  }

  @override
  Future<List<PortfolioAllocationTarget>>
  getPortfolioAllocationTargets() async {
    _requireAuth();
    repo.log('Fetching portfolio allocation targets: $currentUserId');
    final response = await client
        .from('portfolio_allocation_targets')
        .select()
        .eq('user_id', currentUserId!)
        .order('sort_order');
    return (response as List)
        .map(
          (row) => PortfolioAllocationTarget.fromMap(
            repo.normalizeRow(row as Map<String, dynamic>),
          ),
        )
        .toList();
  }

  @override
  Future<void> upsertPortfolioAllocationTarget(
    PortfolioAllocationTarget target,
  ) async {
    _requireAuth();
    repo.log('Upserting portfolio allocation target: ${target.ticker}');
    await client
        .from('portfolio_allocation_targets')
        .upsert(
          _allocationTargetToSupabase(target),
          onConflict: 'user_id, portfolio_id, ticker',
        );
    await repo.updateSyncLog('portfolio');
  }
}
