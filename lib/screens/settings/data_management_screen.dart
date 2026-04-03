import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/account_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/recurring_transaction_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../services/csv_service.dart';
import '../../services/database_manager.dart';
import '../../theme/app_colors.dart';

class DataManagementScreen extends StatefulWidget {
  const DataManagementScreen({super.key});

  @override
  State<DataManagementScreen> createState() => _DataManagementScreenState();
}

class _DataManagementScreenState extends State<DataManagementScreen> {
  final _urlController = TextEditingController();
  final _keyController = TextEditingController();
  bool _isTestingConnection = false;
  String? _connectionStatus;

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
    // Read providers before any await
    final authProvider = context.read<AuthProvider>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: const Text(
          'ต้องการลบการตั้งค่า Supabase ใช่หรือไม่?\n'
          'แอพจะไม่สามารถใช้งานได้จนกว่าจะตั้งค่าใหม่',
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

    // Sign out first
    await authProvider.signOut();

    // Clear Supabase config
    final dbManager = DatabaseManager();
    await dbManager.clearSupabaseConfig();

    _urlController.clear();
    _keyController.clear();

    scaffoldMessenger.showSnackBar(
      const SnackBar(content: Text('ลบการตั้งค่าเรียบร้อย')),
    );

    if (mounted) {
      context.go('/setup');
    }
  }

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

      if (result.hasData) {
        await Future.wait([
          context.read<AccountProvider>().reload(),
          context.read<CategoryProvider>().reload(),
          context.read<TransactionProvider>().reload(),
          context.read<BudgetProvider>().reload(),
          context.read<RecurringTransactionProvider>().reload(),
        ]);
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
    // Read providers first (before any await)
    final accountProvider = context.read<AccountProvider>();
    final budgetProvider = context.read<BudgetProvider>();
    final categoryProvider = context.read<CategoryProvider>();
    final transactionProvider = context.read<TransactionProvider>();
    final recurringProvider = context.read<RecurringTransactionProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการล้างข้อมูล'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('คุณต้องการล้างข้อมูลทั้งหมดใน Supabase หรือไม่?'),
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
      final dbManager = DatabaseManager();
      await dbManager.repository.clearAllData();

      if (!mounted) return;

      await Future.wait([
        accountProvider.reload(),
        budgetProvider.reload(),
        categoryProvider.reload(),
        transactionProvider.reload(),
        recurringProvider.reload(),
      ]);

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
                // ========== SECTION: SUPABASE CONFIG ==========
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
                      Row(
                        children: [
                          Icon(
                            Icons.cloud,
                            color: dbManager.isConfigured
                                ? Colors.blue
                                : Colors.grey,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Supabase (Cloud)',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                Text(
                                  dbManager.isConfigured
                                      ? 'เชื่อมต่อแล้ว'
                                      : 'ยังไม่ได้ตั้งค่า',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: dbManager.isConfigured
                                        ? AppColors.income
                                        : secondaryTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
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
                      if (dbManager.isConfigured) ...[
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

                // ========== SECTION: BACKUP/RESTORE ==========
                _buildSectionTitle(
                  'สำรองและกู้คืน',
                  textColor,
                  secondaryTextColor,
                ),
                const SizedBox(height: 8),

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
                              icon: const Icon(Icons.upload, size: 18),
                              label: const Text('Export'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _importData,
                              icon: const Icon(Icons.download, size: 18),
                              label: const Text('Import'),
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
                        icon: Icons.cloud,
                        title: 'Supabase',
                        description:
                            'เก็บข้อมูลบน Cloud ตรงกันทุกอุปกรณ์ ต้องมี internet',
                        textColor: textColor,
                        secondaryTextColor: secondaryTextColor,
                      ),
                      Divider(color: dividerColor, height: 24),
                      _buildInfoItem(
                        icon: Icons.help_outline,
                        title: 'CSV Export/Import',
                        description:
                            'ใช้สำหรับสำรองข้อมูลส่วนตัว หรือย้ายข้อมูลระหว่างบัญชี',
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
