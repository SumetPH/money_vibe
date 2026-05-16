import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/account.dart';
import '../database_repository.dart';
import '../supabase_repository.dart';

/// Adapter สำหรับจัดการข้อมูลบัญชี (Account) บน Supabase
class SupabaseAccountAdapter implements AccountRepositoryInterface {
  final SupabaseRepository repo;

  SupabaseAccountAdapter(this.repo);

  SupabaseClient get client => repo.client;
  String? get currentUserId => repo.currentUserId;

  void _requireAuth() {
    if (currentUserId == null) {
      throw StateError('User not authenticated. Please login first.');
    }
  }

  Map<String, dynamic> _accountToSupabase(Account account) {
    return {
      'id': account.id,
      'user_id': currentUserId,
      'name': account.name,
      'type': account.type.name,
      'initial_balance': account.initialBalance,
      'currency': account.currency,
      'start_date': account.startDate.toIso8601String(),
      'icon': account.icon.codePoint,
      'icon_url': account.iconUrl,
      'color': SupabaseRepository.colorToSupabase(account.color.toARGB32()),
      'exclude_from_net_worth': account.excludeFromNetWorth ? 1 : 0,
      'is_hidden': account.isHidden ? 1 : 0,
      'sort_order': account.sortOrder,
      'cash_balance': account.cashBalance,
      'exchange_rate': account.exchangeRate,
      'auto_update_rate': account.autoUpdateRate ? 1 : 0,
      'statement_day': account.statementDay,
    };
  }

  Account _accountFromSupabase(Map<String, dynamic> row) {
    final normalized = Map<String, dynamic>.from(row);
    if (normalized['color'] is int) {
      normalized['color'] = SupabaseRepository.colorFromSupabase(
        normalized['color'] as int,
      );
    }
    if (normalized['sort_order'] == null) {
      repo.log('Warning: sort_order is null for account ${normalized['id']}');
    }
    return Account.fromMap(normalized);
  }

  @override
  Future<List<Account>> getAccounts() async {
    _requireAuth();
    repo.log('Fetching accounts for user: $currentUserId');
    final response = await client
        .from('accounts')
        .select()
        .eq('user_id', currentUserId!)
        .order('sort_order');
    return (response as List).map((row) => _accountFromSupabase(row)).toList();
  }

  @override
  Future<void> insertAccount(Account account) async {
    _requireAuth();
    repo.log('Inserting account: ${account.id} for user: $currentUserId');
    await client.from('accounts').insert(_accountToSupabase(account));
    await repo.updateSyncLog('accounts');
  }

  @override
  Future<void> updateAccount(Account account) async {
    _requireAuth();
    repo.log('Updating account: ${account.id} for user: $currentUserId');
    await client
        .from('accounts')
        .update(_accountToSupabase(account))
        .eq('id', account.id)
        .eq('user_id', currentUserId!);
    await repo.updateSyncLog('accounts');
  }

  @override
  Future<void> updateAccountSortOrder(String id, int sortOrder) async {
    _requireAuth();
    repo.log('Updating account sort order: $id -> $sortOrder');
    try {
      final response = await client
          .from('accounts')
          .update({'sort_order': sortOrder})
          .eq('id', id)
          .eq('user_id', currentUserId!)
          .select();

      if ((response as List).isEmpty) {
        throw Exception(
          'Failed to update account sort order: No rows affected',
        );
      }
      repo.log('Updated account sort order successfully: $id');
      await repo.updateSyncLog('accounts');
    } catch (e) {
      repo.logError('Error updating account sort order', e);
      rethrow;
    }
  }

  @override
  Future<void> deleteAccount(String id) async {
    _requireAuth();
    repo.log('Deleting account: $id for user: $currentUserId');
    await client
        .from('accounts')
        .delete()
        .eq('id', id)
        .eq('user_id', currentUserId!);
    await repo.updateSyncLog('accounts');
  }

  @override
  Future<Set<String>> getExistingAccountIds() async {
    _requireAuth();
    final response = await client
        .from('accounts')
        .select('id')
        .eq('user_id', currentUserId!);
    return (response as List).map((r) => r['id'] as String).toSet();
  }

  @override
  Future<void> bulkInsertAccounts(List<Account> accounts) async {
    _requireAuth();
    repo.log(
      'Bulk inserting ${accounts.length} accounts for user: $currentUserId',
    );

    final ids = accounts.map((a) => a.id).toList();
    final uniqueIds = ids.toSet();
    if (ids.length != uniqueIds.length) {
      repo.log(
        'WARNING: Found ${ids.length - uniqueIds.length} duplicate IDs in accounts list',
      );
      repo.log(
        'Duplicate IDs: ${ids.where((id) => ids.where((x) => x == id).length > 1).toSet()}',
      );
    }

    repo.log('Sample IDs to insert: ${ids.take(5).toList()}');
    repo.log(
      'Sample account names: ${accounts.take(5).map((a) => '${a.id.substring(0, 8)}:${a.name}').toList()}',
    );

    await repo.batchInsert(
      'accounts',
      accounts.map((a) => _accountToSupabase(a)).toList(),
    );
  }
}
