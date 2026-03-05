import 'package:flutter/material.dart';
import 'package:money_flutter/database/database_helper.dart';
import 'package:provider/provider.dart';

import '../../providers/account_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/recurring_transaction_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../repositories/database_repository.dart';
import '../../repositories/supabase_repository.dart';
import '../../services/csv_service.dart';
import '../../services/database_backup_service.dart';
import '../../services/database_manager.dart';
import '../../theme/app_colors.dart';
import '../auth/auth_screen.dart';

class DataManagementScreen extends StatefulWidget {
  const DataManagementScreen({super.key});

  @override
  State<DataManagementScreen> createState() => _DataManagementScreenState();
}

class _DataManagementScreenState extends State<DataManagementScreen> {
  // Supabase Config
  final _urlController = TextEditingController();
  final _keyController = TextEditingController();
  bool _isTestingConnection = false;
  String? _connectionStatus;

  // Migration
  bool _isMigrating = false;
  double? _migrationProgress;
  String? _migrationStatus;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  void _loadCurrentConfig() {
    final dbManager = DatabaseManager();
    _urlController.text = dbManager.supabaseUrl ?? '';
    _keyController.text = dbManager.supabaseAnonKey ?? '';
  }

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  String _normalizeSupabaseUrl(String url) {
    var normalized = url.trim();
    if (normalized.isEmpty) return normalized;
    if (!normalized.startsWith('http://') &&
        !normalized.startsWith('https://')) {
      normalized = 'https://$normalized';
    }
    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  Future<void> _testConnection() async {
    final url = _normalizeSupabaseUrl(_urlController.text);
    final key = _keyController.text.trim();

    if (url.isEmpty || key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณากรอก URL และ API Key ก่อนทดสอบ'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isTestingConnection = true;
      _connectionStatus = null;
    });

    final dbManager = DatabaseManager();
    bool success = false;
    String? errorMessage;

    try {
      success = await dbManager.testSupabaseConnectionWithCredentials(
        url: url,
        anonKey: key,
      );
    } catch (e) {
      errorMessage = e.toString();
      success = false;
    }

    setState(() {
      _isTestingConnection = false;
      _connectionStatus = success ? 'เชื่อมต่อสำเร็จ' : 'เชื่อมต่อไม่สำเร็จ';
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'เชื่อมต่อ Supabase สำเร็จ!'
                : 'เชื่อมต่อไม่สำเร็จ${errorMessage != null ? ': $errorMessage' : ''}',
          ),
          backgroundColor: success ? AppColors.income : AppColors.expense,
        ),
      );
    }
  }

  Future<void> _saveSupabaseConfig() async {
    final url = _normalizeSupabaseUrl(_urlController.text);
    final key = _keyController.text.trim();

    if (url.isEmpty || key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณากรอก URL และ API Key'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final dbManager = DatabaseManager();
    final success = await dbManager.configureSupabase(url: url, anonKey: key);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'บันทึกการตั้งค่าเรียบร้อย' : 'ไม่สามารถบันทึกได้',
          ),
          backgroundColor: success ? AppColors.income : AppColors.expense,
        ),
      );
    }
  }

  Future<void> _clearSupabaseConfig() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: const Text(
          'ต้องการลบการตั้งค่า Supabase และกลับไปใช้ SQLite ใช่หรือไม่?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('ลบ', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final dbManager = DatabaseManager();
    await dbManager.clearSupabaseConfig();

    _urlController.clear();
    _keyController.clear();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ลบการตั้งค่าเรียบร้อย กลับไปใช้ SQLite')),
      );
    }
  }

  Future<void> _switchMode(DatabaseMode mode) async {
    final dbManager = DatabaseManager();
    final authProvider = context.read<AuthProvider>();

    if (mode == DatabaseMode.supabase && !dbManager.canUseSupabase) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาตั้งค่า Supabase ก่อน'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (mode == DatabaseMode.supabase && !authProvider.isLoggedIn) {
      if (dbManager.supabaseUrl != null && dbManager.supabaseAnonKey != null) {
        try {
          final tempRepo = SupabaseRepository(
            supabaseUrl: dbManager.supabaseUrl!,
            supabaseAnonKey: dbManager.supabaseAnonKey!,
          );
          await tempRepo.init();
          await authProvider.init();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('ไม่สามารถเชื่อมต่อ Supabase ได้: $e'),
                backgroundColor: AppColors.expense,
              ),
            );
          }
          return;
        }
      }

      if (!mounted) return;

      final loginSuccess = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );

      if (!mounted) return;

      if (loginSuccess != true && !authProvider.isLoggedIn) {
        return;
      }
    }

    final success = await dbManager.switchMode(mode);

    if (success) {
      if (mounted) {
        await _reloadAllProviders(context);
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่สามารถสลับโหมดได้'),
          backgroundColor: AppColors.expense,
        ),
      );
    }
  }

  Future<void> _migrateToSupabase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการย้ายข้อมูล'),
        content: const Text(
          'การย้ายข้อมูลจะคัดลอกข้อมูลทั้งหมดจาก SQLite ไปยัง Supabase\n\n'
          'หมายเหตุ: ข้อมูลเดิมใน SQLite จะไม่ถูกลบ',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'ย้ายข้อมูล',
              style: TextStyle(color: Colors.blue),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isMigrating = true;
      _migrationProgress = 0;
      _migrationStatus = 'กำลังเตรียมการ...';
    });

    final dbManager = DatabaseManager();
    try {
      final results = await dbManager.migrateToSupabase(
        onProgress: (status, progress) {
          setState(() {
            _migrationStatus = status;
            _migrationProgress = progress;
          });
        },
      );

      final total = results.values.fold<int>(0, (sum, count) => sum + count);

      if (mounted) {
        await _reloadAllProviders(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ย้ายข้อมูลสำเร็จ! ทั้งหมด $total records'),
            backgroundColor: AppColors.income,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    } finally {
      setState(() {
        _isMigrating = false;
      });
    }
  }

  Future<void> _migrateFromSupabase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการดึงข้อมูล'),
        content: const Text(
          'การดึงข้อมูลจะคัดลอกข้อมูลทั้งหมดจาก Supabase มายัง SQLite\n\n'
          '⚠️ ข้อมูลเดิมใน SQLite จะถูกลบและแทนที่ด้วยข้อมูลจาก Supabase',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'ดึงข้อมูล',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isMigrating = true;
      _migrationProgress = 0;
      _migrationStatus = 'กำลังเตรียมการ...';
    });

    final dbManager = DatabaseManager();
    try {
      final results = await dbManager.migrateFromSupabase(
        onProgress: (status, progress) {
          setState(() {
            _migrationStatus = status;
            _migrationProgress = progress;
          });
        },
      );

      final total = results.values.fold<int>(0, (sum, count) => sum + count);

      if (mounted) {
        await _reloadAllProviders(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ดึงข้อมูลสำเร็จ! ทั้งหมด $total records'),
            backgroundColor: AppColors.income,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    } finally {
      setState(() {
        _isMigrating = false;
      });
    }
  }

  Future<void> _reloadAllProviders(BuildContext context) async {
    final dbManager = DatabaseManager();
    final authProvider = context.read<AuthProvider>();

    if (dbManager.isSupabaseMode && !authProvider.isLoggedIn) {
      return;
    }

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await Future.wait([
        context.read<AccountProvider>().reload(),
        context.read<CategoryProvider>().reload(),
        context.read<TransactionProvider>().reload(),
        context.read<BudgetProvider>().reload(),
        context.read<RecurringTransactionProvider>().reload(),
      ]);

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('โหลดข้อมูลสำเร็จ!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('โหลดข้อมูลไม่สำเร็จ: $e'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    }
  }

  // ========== BACKUP/RESTORE METHODS ==========

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

  Future<void> _backupFromSupabase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการ Backup จาก Supabase'),
        content: const Text(
          'การ Backup จาก Supabase จะ:\n\n'
          '1. ดึงข้อมูลทั้งหมดจาก Supabase มายัง SQLite\n'
          '2. สำรองไฟล์ SQLite เป็น .db\n\n'
          '⚠️ ข้อมูลเดิมใน SQLite จะถูกแทนที่ด้วยข้อมูลจาก Supabase',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Backup', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('กำลังดึงข้อมูลจาก Supabase...'),
          ],
        ),
      ),
    );

    final dbManager = DatabaseManager();
    try {
      await dbManager.migrateFromSupabase(
        onProgress: (status, progress) {
          debugPrint(
            '[BackupFromSupabase] $status - ${(progress * 100).toInt()}%',
          );
        },
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      if (!mounted) return;

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
      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup จาก Supabase ไม่สำเร็จ: $e'),
            backgroundColor: Colors.red,
          ),
        );
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

      if (result.hasData) {
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
    final dbManager = DatabaseManager();
    final canUseSupabase = dbManager.canUseSupabase;

    if (canUseSupabase) {
      final selectedTarget = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('เลือกที่จะล้างข้อมูล'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('คุณต้องการล้างข้อมูลที่ไหน?'),
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
                      '⚠️ คำเตือน:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'การกระทำนี้ไม่สามารถย้อนกลับได้',
                      style: TextStyle(color: Colors.red.shade900),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('ยกเลิก'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, 'sqlite'),
              icon: const Icon(Icons.storage),
              style: FilledButton.styleFrom(backgroundColor: Colors.orange),
              label: const Text('SQLite เท่านั้น'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, 'supabase'),
              icon: const Icon(Icons.cloud),
              style: FilledButton.styleFrom(backgroundColor: Colors.blue),
              label: const Text('Supabase เท่านั้น'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, 'both'),
              icon: const Icon(Icons.delete_forever),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              label: const Text('ทั้งสองที่'),
            ),
          ],
        ),
      );

      if (selectedTarget == null || selectedTarget == 'cancel') return;
      if (!mounted) return;

      final confirmTarget = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('ยืนยันการล้างข้อมูล'),
          content: Text(
            selectedTarget == 'both'
                ? 'คุณต้องการล้างข้อมูลทั้งใน SQLite และ Supabase ใช่หรือไม่?\n\n'
                      'ข้อมูลทั้งหมดจะถูกลบถาวร!'
                : 'คุณต้องการล้างข้อมูลใน ${selectedTarget == 'sqlite' ? 'SQLite' : 'Supabase'} ใช่หรือไม่?\n\n'
                      'ข้อมูลทั้งหมดจะถูกลบถาวร!',
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

      if (confirmTarget != true) return;

      await _executeClearData(selectedTarget);
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('ยืนยันการล้างข้อมูล'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('คุณต้องการล้างข้อมูลทั้งหมดใน SQLite หรือไม่?'),
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

      await _executeClearData('sqlite');
    }
  }

  Future<void> _executeClearData(String target) async {
    try {
      final dbManager = DatabaseManager();

      if (target == 'sqlite' || target == 'both') {
        await DatabaseHelper.instance.clearDatabase();
      }

      if (target == 'supabase' || target == 'both') {
        if (dbManager.canUseSupabase) {
          if (dbManager.currentMode == DatabaseMode.sqlite) {
            final supabaseRepo = SupabaseRepository(
              supabaseUrl: dbManager.supabaseUrl!,
              supabaseAnonKey: dbManager.supabaseAnonKey!,
            );
            await supabaseRepo.init();
            await supabaseRepo.clearAllData();
          } else {
            await dbManager.repository.clearAllData();
          }
        }
      }

      if (!mounted) return;

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
    final isDarkMode = context.watch<SettingsProvider>().isDarkMode;
    final backgroundColor = isDarkMode
        ? AppColors.darkBackground
        : AppColors.background;
    final surfaceColor = isDarkMode ? AppColors.darkSurface : Colors.white;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final secondaryTextColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.header,
        foregroundColor: textColor,
        title: const Text('จัดการข้อมูล'),
        elevation: 0,
      ),
      body: Consumer<DatabaseManager>(
        builder: (context, dbManager, _) {
          return SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ========== SECTION: DATABASE MODE ==========
                _buildSectionTitle('ฐานข้อมูล', textColor, secondaryTextColor),
                const SizedBox(height: 8),
                _buildCard(
                  surfaceColor: surfaceColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            dbManager.isSqliteMode
                                ? Icons.storage
                                : Icons.cloud,
                            color: dbManager.isSqliteMode
                                ? Colors.orange
                                : Colors.blue,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dbManager.isSqliteMode
                                      ? 'SQLite (Local)'
                                      : 'Supabase (Cloud)',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                Text(
                                  dbManager.isSqliteMode
                                      ? 'เก็บข้อมูลในเครื่อง'
                                      : 'เก็บข้อมูลบน Cloud',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: secondaryTextColor,
                                  ),
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
                            child: _buildModeButton(
                              label: 'SQLite',
                              icon: Icons.storage,
                              color: Colors.orange,
                              isActive: dbManager.isSqliteMode,
                              onTap: () => _switchMode(DatabaseMode.sqlite),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildModeButton(
                              label: 'Supabase',
                              icon: Icons.cloud,
                              color: Colors.blue,
                              isActive: dbManager.isSupabaseMode,
                              onTap: () => _switchMode(DatabaseMode.supabase),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ========== SECTION: SUPABASE CONFIG ==========
                // แสดงเสมอเพื่อให้ผู้ใช้สามารถตั้งค่า Supabase ได้แม้ยังไม่มี config
                ...[
                  _buildSectionTitle(
                    'ตั้งค่า Supabase',
                    textColor,
                    secondaryTextColor,
                  ),
                  const SizedBox(height: 8),
                  _buildCard(
                    surfaceColor: surfaceColor,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _urlController,
                          decoration: InputDecoration(
                            labelText: 'Supabase URL',
                            hintText: 'https://your-project.supabase.co',
                            labelStyle: TextStyle(color: secondaryTextColor),
                            hintStyle: TextStyle(
                              color: secondaryTextColor.withAlpha(128),
                            ),
                            border: const OutlineInputBorder(),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: dividerColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: AppColors.header),
                            ),
                          ),
                          style: TextStyle(color: textColor),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _keyController,
                          decoration: InputDecoration(
                            labelText: 'Anon Key',
                            hintText: 'your-anon-key',
                            labelStyle: TextStyle(color: secondaryTextColor),
                            hintStyle: TextStyle(
                              color: secondaryTextColor.withAlpha(128),
                            ),
                            border: const OutlineInputBorder(),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: dividerColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: AppColors.header),
                            ),
                          ),
                          style: TextStyle(color: textColor),
                          obscureText: true,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isTestingConnection
                                    ? null
                                    : _testConnection,
                                icon: _isTestingConnection
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.network_check, size: 18),
                                label: const Text('ทดสอบ'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: textColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _saveSupabaseConfig,
                                icon: const Icon(Icons.save, size: 18),
                                label: const Text('บันทึก'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.header,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_connectionStatus != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _connectionStatus!,
                            style: TextStyle(
                              color: _connectionStatus == 'เชื่อมต่อสำเร็จ'
                                  ? AppColors.income
                                  : AppColors.expense,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        if (dbManager.canUseSupabase) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _clearSupabaseConfig,
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('ลบการตั้งค่า'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.expense,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // ========== SECTION: MIGRATION ==========
                if (dbManager.canUseSupabase) ...[
                  _buildSectionTitle(
                    'ย้ายข้อมูล',
                    textColor,
                    secondaryTextColor,
                  ),
                  const SizedBox(height: 8),
                  _buildCard(
                    surfaceColor: surfaceColor,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isMigrating) ...[
                          LinearProgressIndicator(
                            value: _migrationProgress,
                            backgroundColor: dividerColor,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.header,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _migrationStatus ?? 'กำลังดำเนินการ...',
                            style: TextStyle(
                              fontSize: 12,
                              color: secondaryTextColor,
                            ),
                          ),
                        ] else ...[
                          Text(
                            'SQLite → Supabase',
                            style: TextStyle(
                              fontSize: 14,
                              color: secondaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _migrateToSupabase,
                              icon: const Icon(Icons.cloud_upload),
                              label: const Text('ย้ายข้อมูลไป Supabase'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Divider(color: dividerColor),
                          const SizedBox(height: 16),
                          Text(
                            'Supabase → SQLite',
                            style: TextStyle(
                              fontSize: 14,
                              color: secondaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _migrateFromSupabase,
                              icon: const Icon(Icons.cloud_download),
                              label: const Text('ดึงข้อมูลจาก Supabase'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.orange,
                                side: const BorderSide(color: Colors.orange),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '⚠️ ข้อมูลเดิมใน SQLite จะถูกแทนที่',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.expense,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // ========== SECTION: BACKUP/RESTORE ==========
                _buildSectionTitle(
                  'สำรองและกู้คืน',
                  textColor,
                  secondaryTextColor,
                ),
                const SizedBox(height: 8),

                // SQLite Backup
                _buildCard(
                  surfaceColor: surfaceColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.storage,
                            color: AppColors.header,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'สำรองฐานข้อมูล (SQLite)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: textColor,
                                  ),
                                ),
                                Text(
                                  'สำรองไฟล์ .db (เร็ว แต่ไม่รองรับข้าม Platform)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: secondaryTextColor,
                                  ),
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
                              icon: const Icon(Icons.backup, size: 18),
                              label: const Text('Backup'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _restoreDatabase,
                              icon: const Icon(Icons.restore, size: 18),
                              label: const Text('Restore'),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.teal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // CSV Export/Import
                _buildCard(
                  surfaceColor: surfaceColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.insert_drive_file,
                            color: Colors.green,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ส่งออก/นำเข้า (CSV)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: textColor,
                                  ),
                                ),
                                Text(
                                  'รองรับข้าม Platform (Android ↔ iOS)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: secondaryTextColor,
                                  ),
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
                              icon: const Icon(Icons.cloud_upload, size: 18),
                              label: const Text('Bckup'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _importData,
                              icon: const Icon(Icons.restore, size: 18),
                              label: const Text('Restore'),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.teal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Backup from Supabase
                if (dbManager.canUseSupabase) const SizedBox(height: 12),
                if (dbManager.canUseSupabase)
                  _buildCard(
                    surfaceColor: surfaceColor,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.cloud_download,
                              color: Colors.orange,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Backup จาก Supabase',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: textColor,
                                    ),
                                  ),
                                  Text(
                                    'ดึงจาก Cloud แล้วสำรองเป็นไฟล์',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: secondaryTextColor,
                                    ),
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
                            onPressed: _backupFromSupabase,
                            icon: const Icon(Icons.cloud_download, size: 18),
                            label: const Text('Backup จาก Supabase'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                // ========== SECTION: CLEAR DATA ==========
                _buildSectionTitle('ล้างข้อมูล', textColor, secondaryTextColor),
                const SizedBox(height: 8),
                _buildCard(
                  surfaceColor: surfaceColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.expense.withAlpha(26),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber, color: AppColors.expense),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'การล้างข้อมูลจะลบข้อมูลทั้งหมดอย่างถาวร และไม่สามารถกู้คืนได้',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _clearData,
                          icon: const Icon(Icons.delete_forever, size: 18),
                          label: const Text('ล้างข้อมูลทั้งหมด'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.expense,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ========== INFO SECTION ==========
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? AppColors.darkSurface.withAlpha(128)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'คำแนะนำ',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoItem(
                        icon: Icons.storage,
                        title: 'SQLite',
                        description:
                            'เหมาะสำหรับใช้งานคนเดียว ไม่ต้องการ internet',
                        textColor: textColor,
                        secondaryTextColor: secondaryTextColor,
                      ),
                      Divider(color: dividerColor, height: 24),
                      _buildInfoItem(
                        icon: Icons.cloud,
                        title: 'Supabase',
                        description:
                            'เหมาะสำหรับต้องการ sync ข้อมูลข้ามอุปกรณ์ ต้องมี internet',
                        textColor: textColor,
                        secondaryTextColor: secondaryTextColor,
                      ),
                      Divider(color: dividerColor, height: 24),
                      _buildInfoItem(
                        icon: Icons.help_outline,
                        title: 'Backup vs CSV',
                        description:
                            'Backup (.db) รวดเร็วแต่ใช้ได้เฉพาะ Platform เดียวกัน\nCSV ใช้ข้าม Platform ได้',
                        textColor: textColor,
                        secondaryTextColor: secondaryTextColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(
    String title,
    Color textColor,
    Color secondaryTextColor,
  ) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.header,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required Color surfaceColor, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildModeButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? color.withAlpha(26) : Colors.transparent,
          border: Border.all(
            color: isActive ? color : Colors.grey.shade300,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: isActive ? color : Colors.grey),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? color : Colors.grey,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String description,
    required Color textColor,
    required Color secondaryTextColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: secondaryTextColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.w500, color: textColor),
              ),
              Text(
                description,
                style: TextStyle(fontSize: 12, color: secondaryTextColor),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
