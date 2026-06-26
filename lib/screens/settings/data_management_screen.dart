import 'package:flutter/material.dart';
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
  bool _isTestingConnection = false;
  String? _connectionStatus;

  Future<void> _testConnection() async {
    setState(() {
      _isTestingConnection = true;
      _connectionStatus = null;
    });

    final dbManager = DatabaseManager();
    bool success = false;
    String? errorMessage;

    try {
      success = await dbManager.testSupabaseConnection();
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
    final authProvider = context.watch<AuthProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final isDarkMode = settingsProvider.isDarkMode;
    final themeColor = settingsProvider.themeColor;
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
        backgroundColor: AppColors.headerFor(isDarkMode, themeColor),
        foregroundColor: Colors.white,
        title: const Text('จัดการข้อมูล'),
        elevation: 0,
      ),
      body: Consumer<DatabaseManager>(
        builder: (context, dbManager, _) {
          final showBuildDetails = dbManager.config?.isProduction == false;

          return SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionTitle(
                  'ฐานข้อมูล',
                  textColor,
                  secondaryTextColor,
                  AppColors.accentFor(isDarkMode, themeColor),
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
                      if (showBuildDetails) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? AppColors.darkBackground
                                : AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: dividerColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildConfigRow(
                                label: 'Environment',
                                value: dbManager.config?.environmentName ?? '-',
                                textColor: textColor,
                                secondaryTextColor: secondaryTextColor,
                              ),
                              Divider(color: dividerColor, height: 20),
                              _buildConfigRow(
                                label: 'Project',
                                value:
                                    dbManager.config?.maskedSupabaseUrl ??
                                    'ไม่ได้ตั้งค่า',
                                textColor: textColor,
                                secondaryTextColor: secondaryTextColor,
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (dbManager.error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.expense.withAlpha(18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            dbManager.error!,
                            style: TextStyle(
                              color: AppColors.expense,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed:
                              dbManager.isConfigured && !_isTestingConnection
                              ? _testConnection
                              : null,
                          icon: _isTestingConnection
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.network_check, size: 18),
                          label: const Text('ทดสอบการเชื่อมต่อ'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textColor,
                          ),
                        ),
                      ),
                      if (!dbManager.isConfigured) ...[
                        const SizedBox(height: 8),
                        Text(
                          'ค่า Supabase ต้องมากับ build เท่านั้น ผู้ใช้ไม่สามารถแก้จากในแอปได้',
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
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
                    ],
                  ),
                ),

                if (authProvider.isLoggedIn) ...[
                  const SizedBox(height: 24),

                  // ========== SECTION: BACKUP/RESTORE ==========
                  _buildSectionTitle(
                    'สำรองและกู้คืน',
                    textColor,
                    secondaryTextColor,
                    AppColors.accentFor(isDarkMode, themeColor),
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
                              color: AppColors.income,
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
                                  backgroundColor: AppColors.transfer,
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
                  _buildSectionTitle(
                    'ล้างข้อมูล',
                    textColor,
                    secondaryTextColor,
                    AppColors.accentFor(isDarkMode, themeColor),
                  ),
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
                              Icon(
                                Icons.warning_amber,
                                color: AppColors.expense,
                              ),
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
                ],

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
    Color accentColor,
  ) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: accentColor,
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

  Widget _buildConfigRow({
    required String label,
    required String value,
    required Color textColor,
    required Color secondaryTextColor,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: secondaryTextColor, fontSize: 12),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
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
