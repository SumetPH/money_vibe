import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/tax_remittance.dart';
import '../database_repository.dart';
import '../supabase_repository.dart';

class SupabaseTaxRemittanceAdapter implements TaxRemittanceRepositoryInterface {
  final SupabaseRepository repo;

  SupabaseTaxRemittanceAdapter(this.repo);

  SupabaseClient get client => repo.client;
  String? get currentUserId => repo.currentUserId;

  void _requireAuth() {
    if (currentUserId == null) {
      throw StateError('User not authenticated. Please login first.');
    }
  }

  Map<String, dynamic> _remittanceToSupabase(TaxRemittance remittance) => {
    'id': remittance.id,
    'user_id': currentUserId,
    'portfolio_id': remittance.portfolioId,
    'remitted_at': remittance.remittedAt.toIso8601String(),
    'amount_usd': remittance.amountUsd,
    'fx_rate': remittance.fxRate,
    'thb_amount': remittance.thbAmount,
    'note': remittance.note,
    'created_at': remittance.createdAt.toIso8601String(),
  };

  Map<String, dynamic> _allocationToSupabase(
    TaxRemittanceAllocation allocation,
  ) => {
    'id': allocation.id,
    'user_id': currentUserId,
    'remittance_id': allocation.remittanceId,
    'bucket_type': allocation.bucketType.name,
    'tax_year': allocation.taxYear,
    'amount_usd': allocation.amountUsd,
    'note': allocation.note,
  };

  @override
  Future<List<TaxRemittance>> getTaxRemittances() async {
    _requireAuth();
    repo.log('Fetching tax remittances for user: $currentUserId');

    final remittanceRows = await client
        .from('tax_remittances')
        .select()
        .eq('user_id', currentUserId!)
        .order('remitted_at', ascending: false);
    final allocationRows = await client
        .from('tax_remittance_allocations')
        .select()
        .eq('user_id', currentUserId!);

    final allocationsByRemittance = <String, List<TaxRemittanceAllocation>>{};
    for (final row in allocationRows as List) {
      final allocation = TaxRemittanceAllocation.fromMap(
        repo.normalizeRow(row as Map<String, dynamic>),
      );
      allocationsByRemittance
          .putIfAbsent(allocation.remittanceId, () => [])
          .add(allocation);
    }

    return (remittanceRows as List).map((row) {
      final normalized = repo.normalizeRow(row as Map<String, dynamic>);
      final id = normalized['id'] as String;
      return TaxRemittance.fromMap(
        normalized,
        allocations: allocationsByRemittance[id] ?? const [],
      );
    }).toList();
  }

  @override
  Future<void> insertTaxRemittance(TaxRemittance remittance) async {
    _requireAuth();
    repo.log('Inserting tax remittance: ${remittance.id}');
    var insertedRemittance = false;
    try {
      await client
          .from('tax_remittances')
          .insert(_remittanceToSupabase(remittance));
      insertedRemittance = true;
      if (remittance.allocations.isNotEmpty) {
        await client
            .from('tax_remittance_allocations')
            .insert(remittance.allocations.map(_allocationToSupabase).toList());
      }
    } catch (_) {
      if (insertedRemittance) {
        await client
            .from('tax_remittances')
            .delete()
            .eq('id', remittance.id)
            .eq('user_id', currentUserId!);
      }
      rethrow;
    }
    await repo.updateSyncLog('portfolio');
  }

  @override
  Future<void> updateTaxRemittance(TaxRemittance remittance) async {
    _requireAuth();
    repo.log('Updating tax remittance: ${remittance.id}');
    await client
        .from('tax_remittances')
        .update(_remittanceToSupabase(remittance))
        .eq('id', remittance.id)
        .eq('user_id', currentUserId!);
    await client
        .from('tax_remittance_allocations')
        .delete()
        .eq('remittance_id', remittance.id)
        .eq('user_id', currentUserId!);
    if (remittance.allocations.isNotEmpty) {
      await client
          .from('tax_remittance_allocations')
          .insert(remittance.allocations.map(_allocationToSupabase).toList());
    }
    await repo.updateSyncLog('portfolio');
  }

  @override
  Future<void> deleteTaxRemittance(String id) async {
    _requireAuth();
    repo.log('Deleting tax remittance: $id');
    await client
        .from('tax_remittances')
        .delete()
        .eq('id', id)
        .eq('user_id', currentUserId!);
    await repo.updateSyncLog('portfolio');
  }
}
