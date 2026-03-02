import 'package:flutter/material.dart';
import 'package:money_flutter/database/database_helper.dart';
import 'package:provider/provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../services/csv_service.dart';

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
        await accountProvider.reload();
        await categoryProvider.reload();
        await transactionProvider.reload();
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
      await DatabaseHelper.instance.clearDatabase();

      if (!mounted) return;

      // Reload all providers
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
      await accountProvider.reload();
      await categoryProvider.reload();
      await transactionProvider.reload();

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
      appBar: AppBar(title: const Text('สำรองและกู้คืนข้อมูล')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Export Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.upload_file,
                        color: Theme.of(context).colorScheme.primary,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ส่งออกข้อมูล',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ส่งออกข้อมูลทั้งหมดเป็นไฟล์ CSV 4',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _exportData,
                      icon: const Icon(Icons.backup),
                      label: const Text('Backup'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Import Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.download,
                        color: Theme.of(context).colorScheme.secondary,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'นำเข้าข้อมูล',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'นำเข้าข้อมูลจากไฟล์ CSV ที่ส่งออกไว้',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
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
            ),
          ),

          const SizedBox(height: 16),

          // Clear Data Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ล้างข้อมูล',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ลบข้อมูลทั้งหมดออกจากฐานข้อมูล',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _clearData,
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('ล้างข้อมูล'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Warning
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
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
                  '• การนำเข้าข้อมูลจะแทนที่ข้อมูลที่มีอยู่ถ้า ID ซ้ำกัน\n'
                  '• ควรส่งออกข้อมูลสำรองก่อนนำเข้าข้อมูลใหม่\n'
                  '• รองรับการ Backup/Restore ข้ามอุปกรณ์ (Android ↔ iOS)',
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
