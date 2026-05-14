import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/transaction.dart';
import '../database_repository.dart';
import '../supabase_repository.dart';

/// Adapter สำหรับจัดการข้อมูลธุรกรรม (Transaction) บน Supabase
class SupabaseTransactionAdapter implements TransactionRepositoryInterface {
  final SupabaseRepository repo;

  SupabaseTransactionAdapter(this.repo);

  SupabaseClient get client => repo.client;
  String? get currentUserId => repo.currentUserId;

  void _requireAuth() {
    if (currentUserId == null) {
      throw StateError('User not authenticated. Please login first.');
    }
  }

  Map<String, dynamic> _transactionToSupabase(AppTransaction transaction) {
    return {
      'id': transaction.id,
      'user_id': currentUserId,
      'type': transaction.type.name,
      'amount': transaction.amount,
      'account_id': transaction.accountId,
      'category_id': transaction.categoryId,
      'to_account_id': transaction.toAccountId,
      'date_time': transaction.dateTime.toIso8601String(),
      'note': transaction.note,
      'to_amount': transaction.toAmount, // cross-currency transfer amount
    };
  }

  AppTransaction _transactionFromSupabase(Map<String, dynamic> row) {
    final normalized = repo.normalizeRow(row);
    return AppTransaction.fromMap(normalized);
  }

  @override
  Future<List<AppTransaction>> getTransactions() async {
    _requireAuth();
    repo.log('Fetching transactions for user: $currentUserId');
    final allTransactions = <AppTransaction>[];
    int offset = 0;
    const int pageSize = 1000;

    while (true) {
      final response = await client
          .from('transactions')
          .select()
          .eq('user_id', currentUserId!)
          .order('date_time', ascending: false)
          .range(offset, offset + pageSize - 1);

      final batch = (response as List)
          .map((row) => _transactionFromSupabase(row))
          .toList();

      if (batch.isEmpty) {
        break;
      }

      allTransactions.addAll(batch);

      if (batch.length < pageSize) {
        break;
      }

      offset += pageSize;
    }

    repo.log('Fetched ${allTransactions.length} transactions total');
    return allTransactions;
  }

  @override
  Future<void> insertTransaction(AppTransaction transaction) async {
    _requireAuth();
    repo.log(
      'Inserting transaction: ${transaction.id} for user: $currentUserId',
    );
    await client
        .from('transactions')
        .insert(_transactionToSupabase(transaction));
  }

  @override
  Future<void> updateTransaction(AppTransaction transaction) async {
    _requireAuth();
    repo.log(
      'Updating transaction: ${transaction.id} for user: $currentUserId',
    );
    await client
        .from('transactions')
        .update(_transactionToSupabase(transaction))
        .eq('id', transaction.id)
        .eq('user_id', currentUserId!);
  }

  @override
  Future<void> deleteTransaction(String id) async {
    _requireAuth();
    repo.log('Deleting transaction: $id for user: $currentUserId');
    await client
        .from('transactions')
        .delete()
        .eq('id', id)
        .eq('user_id', currentUserId!);
  }

  @override
  Future<Set<String>> getExistingTransactionIds() async {
    _requireAuth();
    final response = await client
        .from('transactions')
        .select('id')
        .eq('user_id', currentUserId!);
    return (response as List).map((r) => r['id'] as String).toSet();
  }

  @override
  Future<void> bulkInsertTransactions(List<AppTransaction> transactions) async {
    _requireAuth();
    repo.log(
      'Bulk inserting ${transactions.length} transactions for user: $currentUserId',
    );
    await repo.batchInsert(
      'transactions',
      transactions.map((t) => _transactionToSupabase(t)).toList(),
    );
  }
}
