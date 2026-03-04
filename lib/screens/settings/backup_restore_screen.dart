import 'package:flutter/material.dart';
import 'package:money_flutter/database/database_helper.dart';
import 'package:provider/provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/recurring_transaction_provider.dart';
import '../../services/csv_service.dart';
import '../../services/database_backup_service.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  Future<void> _exportData() async {
    try {
      final RenderBox? box = context.findRenderObject() as RenderBox?;
      final Rect sharePositionOrigin = box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : Rect.zero;

      await CsvService.instance.exportToCsv(
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('ส่งออกไม่สำเร็จ: $e')));
      }
    }
  }

  Future<void> _backupDatabase() async {
    try {
      final result = await DatabaseBackupService.instance.backupDatabase(
        context: context,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('สำรองข้อมูลไม่สำเร็จ: $e')));
      }
    }
  }

  Future<void> _restoreDatabase() async {
    try {
      final result = await DatabaseBackupService.instance.restoreDatabase(
        context: context,
      );

      if (!mounted) return;

      if (result.canceled) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? Colors.green : Colors.red,
          duration: Duration(seconds: result.success ? 2 : 5),
        ),
      );

      // Reload all providers after successful restore
      if (result.success) {
        final accountProvider = Provider.of<AccountProvider>(
          context,
          listen: false,
        );
        final budgetProvider = Provider.of<BudgetProvider>(
          context,
          listen: false,
        );
        final categoryProvider = Provider.of<CategoryProvider>(
          context,
          listen: false,
        );
        final transactionProvider = Provider.of<TransactionProvider>(
          context,
          listen: false,
        );
        final recurringProvider = Provider.of<RecurringTransactionProvider>(
          context,
          listen: false,
        );
        await accountProvider.reload();
        await budgetProvider.reload();
        await categoryProvider.reload();
        await transactionProvider.reload();
        await recurringProvider.reload();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('กู้คืนข้อมูลไม่สำเร็จ: $e')));
      }
    }
  }

  Future<void> _importData() async {
    try {
      final ImportResult result = await CsvService.instance.importFromCsv();

      if (!mounted) return;

      if (result.canceled) return;

      // Reload all providers after import
      debugPrint('BackupRestore: result.hasData = ${result.hasData}');
      debugPrint(
        'BackupRestore: result.categoriesCount = ${result.categoriesCount}',
      );
      if (result.hasData) {
        debugPrint('BackupRestore: Reloading providers...');
        final accountProvider = Provider.of<AccountProvider>(
          context,
          listen: false,
        );
        final categoryProvider = Provider.of<CategoryProvider>(
          context,
          listen: false,
        );
        final transactionProvider = Provider.of<TransactionProvider>(
          context,
          listen: false,
        );
        final budgetProvider = Provider.of<BudgetProvider>(
          context,
          listen: false,
        );
        final recurringProvider = Provider.of<RecurringTransactionProvider>(
          context,
          listen: false,
        );
        await accountProvider.reload();
        await budgetProvider.reload();
        await categoryProvider.reload();
        await transactionProvider.reload();
        await recurringProvider.reload();
        debugPrint('BackupRestore: Providers reloaded');
      } else {
        debugPrint('BackupRestore: No data to reload');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.summary),
          duration: Duration(seconds: result.hasError ? 5 : 2),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('นำเข้าไม่สำเร็จ: $e')));
      }
    }
  }

  Future<void> _clearData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการล้างข้อมูล'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('คุณต้องการล้างข้อมูลทั้งหมดหรือไม่?'),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ข้อมูลที่จะถูกลบ:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• บัญชีทั้งหมด\n'
                    '• งบประมาณทั้งหมด\n'
                    '• หมวดหมู่ทั้งหมด\n'
                    '• ธุรกรรมทั้งหมด\n'
                    '• หลักทรัพย์ทั้งหมด',
                    style: TextStyle(color: Colors.red.shade900),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '⚠️ การกระทำนี้ไม่สามารถย้อนกลับได้',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red.shade800,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ล้างข้อมูล'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      debugPrint('BackupRestore: Starting clear data...');
      await DatabaseHelper.instance.clearDatabase();
      debugPrint('BackupRestore: Database cleared');

      if (!mounted) return;

      // Reload all providers
      debugPrint('BackupRestore: Reloading providers...');
      final accountProvider = Provider.of<AccountProvider>(
        context,
        listen: false,
      );
      final budgetProvider = Provider.of<BudgetProvider>(
        context,
        listen: false,
      );
      final categoryProvider = Provider.of<CategoryProvider>(
        context,
        listen: false,
      );
      final transactionProvider = Provider.of<TransactionProvider>(
        context,
        listen: false,
      );
      final recurringProvider = Provider.of<RecurringTransactionProvider>(
        context,
        listen: false,
      );

      debugPrint('BackupRestore: Reloading accountProvider...');
      await accountProvider.reload();
      debugPrint('BackupRestore: accountProvider reloaded');

      debugPrint('BackupRestore: Reloading budgetProvider...');
      await budgetProvider.reload();
      debugPrint('BackupRestore: budgetProvider reloaded');

      debugPrint('BackupRestore: Reloading categoryProvider...');
      await categoryProvider.reload();
      debugPrint('BackupRestore: categoryProvider reloaded');

      debugPrint('BackupRestore: Reloading transactionProvider...');
      await transactionProvider.reload();
      debugPrint('BackupRestore: transactionProvider reloaded');

      debugPrint('BackupRestore: Reloading recurringProvider...');
      await recurringProvider.reload();
      debugPrint('BackupRestore: recurringProvider reloaded');

      debugPrint('BackupRestore: All providers reloaded');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ล้างข้อมูลเรียบร้อยแล้ว'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('ล้างข้อมูลไม่สำเร็จ: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('สำรองและกู้คืนข้อมูล'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _clearData,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // SQLite Backup Section (New)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.storage,
                        color: Theme.of(context).colorScheme.primary,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'สำรองฐานข้อมูล (SQLite)',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'สำรองฐานข้อมูลทั้งไฟล์ (ไม่รองรับข้าม Platform)',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _backupDatabase,
                          icon: const Icon(Icons.backup),
                          label: const Text('Backup'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _restoreDatabase,
                          icon: const Icon(Icons.restore),
                          label: const Text('Restore'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // CSV Backup/Restore Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.insert_drive_file,
                        color: Theme.of(context).colorScheme.primary,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ส่งออก/นำเข้าข้อมูล (CSV)',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ส่งออกและนำเข้าข้อมูลเป็นไฟล์ CSV (รองรับข้าม Platform)',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _exportData,
                          icon: const Icon(Icons.backup),
                          label: const Text('Backup'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _importData,
                          icon: const Icon(Icons.restore),
                          label: const Text('Restore'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Warning
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange.shade800),
                    const SizedBox(width: 8),
                    Text(
                      'คำเตือน',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'SQLite Backup/Restore:\n'
                  '• สำรอง/กู้คืนฐานข้อมูลทั้งไฟล์\n'
                  '• ❌ ไม่รองรับข้าม Platform (Android ↔ iOS)\n'
                  '• ✅ รวดเร็วและได้ข้อมูลครบถ้วน\n\n'
                  'CSV Export/Import:\n'
                  '• ส่งออก/นำเข้าข้อมูลเป็นไฟล์ CSV\n'
                  '• ✅ รองรับข้าม Platform\n'
                  '• อ่านข้อมูลด้วยมนุษย์ได้',
                  style: TextStyle(fontSize: 13, color: Colors.orange.shade900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
