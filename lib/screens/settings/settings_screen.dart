import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/recurring_transaction_provider.dart';
import '../../providers/cash_flow_forecast_provider.dart';

import '../../services/ai_finance_export_service.dart';
import '../../services/database_manager.dart';
import '../../services/reinstall_reminder_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_modal_bottom_sheet.dart';
import 'finnhubapi_key_settings_screen.dart';
import 'data_management_screen.dart';
import 'llm_api_key_settings_screen.dart';
import '../../widgets/app_inset_card.dart';
import '../../widgets/app_confirm_dialog.dart';
import 'settings_widgets.dart';
import 'settings_sheets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final Future<PackageInfo> _packageInfoFuture;

  @override
  void initState() {
    super.initState();
    _packageInfoFuture = PackageInfo.fromPlatform();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isDarkMode = settings.isDarkMode;
    final backgroundColor = isDarkMode
        ? AppColors.darkBackground
        : AppColors.background;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final secondaryTextColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final reinstallReminder = context.watch<ReinstallReminderService>();

    final isLargeScreen = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 100,
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: isLargeScreen ? 24 : 16,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Money Vibe',
              style: TextStyle(
                color: secondaryTextColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'ตั้งค่า',
              style: TextStyle(
                color: textColor,
                fontSize: 30,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      drawer: isLargeScreen ? null : const AppDrawer(currentRoute: '/settings'),
      body: Consumer<DatabaseManager>(
        builder: (context, dbManager, _) {
          return SafeArea(
            top: false,
            child: ListView(
              children: [
                // Account Section
                AppSectionHeader('บัญชีผู้ใช้'),
                SettingsGroup(
                  isDarkMode: isDarkMode,
                  child: Column(
                    children: [
                      Consumer<AuthProvider>(
                        builder: (context, authProvider, _) {
                          if (authProvider.isLoggedIn) {
                            // แสดงเมื่อ login แล้ว
                            return Column(
                              children: [
                                ListTile(
                                  leading: SettingsIcon(
                                    icon: Icons.person,
                                    color: secondaryTextColor,
                                  ),
                                  title: Text(
                                    authProvider.userEmail ?? 'ผู้ใช้',
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'อีเมลปัจจุบัน',
                                    style: TextStyle(
                                      color: secondaryTextColor,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Divider(
                                  height: 1,
                                  color: AppColors.listDividerFor(isDarkMode),
                                ),
                                ListTile(
                                  leading: SettingsIcon(
                                    icon: Icons.logout,
                                    color: isDarkMode
                                        ? AppColors.darkExpense
                                        : AppColors.expense,
                                  ),
                                  title: Text(
                                    'ออกจากระบบ',
                                    style: TextStyle(
                                      color: isDarkMode
                                          ? AppColors.darkExpense
                                          : AppColors.expense,
                                    ),
                                  ),
                                  onTap: () => _showLogoutDialog(context),
                                ),
                              ],
                            );
                          } else {
                            // แสดงเมื่อยังไม่ได้ login
                            return ListTile(
                              leading: SettingsIcon(
                                icon: Icons.login,
                                color: isDarkMode
                                    ? AppColors.darkIncome
                                    : AppColors.income,
                              ),
                              title: Text(
                                'เข้าสู่ระบบ',
                                style: TextStyle(
                                  color: isDarkMode
                                      ? AppColors.darkIncome
                                      : AppColors.income,
                                ),
                              ),
                              subtitle: Text(
                                'เข้าสู่ระบบเพื่อซิงค์ข้อมูลกับ Supabase',
                                style: TextStyle(color: secondaryTextColor),
                              ),
                              trailing: Icon(
                                Icons.chevron_right,
                                color: secondaryTextColor,
                              ),
                              onTap: () => context.go('/auth'),
                            );
                          }
                        },
                      ),
                      if (!dbManager.isConfigured) ...[
                        ListTile(
                          leading: const SettingsIcon(
                            icon: Icons.cloud_off,
                            color: Colors.orange,
                          ),
                          title: Text(
                            'ยังไม่ได้ตั้งค่า Supabase',
                            style: TextStyle(color: textColor),
                          ),
                          subtitle: Text(
                            'แอปนี้ต้องถูก build พร้อมค่า Supabase',
                            style: TextStyle(color: secondaryTextColor),
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: secondaryTextColor,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const DataManagementScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),

                // Appearance Section
                AppSectionHeader('ลักษณะ'),
                SettingsGroup(
                  isDarkMode: isDarkMode,
                  child: Column(
                    children: [
                      Consumer<SettingsProvider>(
                        builder: (context, settingsProvider, _) {
                          return SettingsToggleTile(
                            icon: Icons.dark_mode_outlined,
                            title: 'โหมดมืด',
                            subtitle: 'ใช้ธีมสีเข้ม',
                            isDarkMode: isDarkMode,
                            value: settingsProvider.isDarkMode,
                            onChanged: settingsProvider.setDarkMode,
                          );
                        },
                      ),
                      Divider(
                        height: 1,
                        color: AppColors.listDividerFor(isDarkMode),
                      ),
                      Consumer<SettingsProvider>(
                        builder: (context, settingsProvider, _) {
                          return ListTile(
                            leading: SettingsIcon(
                              icon: Icons.palette_outlined,
                              color: secondaryTextColor,
                            ),
                            title: Text(
                              'สีธีม',
                              style: TextStyle(color: textColor, fontSize: 16),
                            ),
                            subtitle: Text(
                              settingsProvider.themeColor.label,
                              style: TextStyle(
                                color: secondaryTextColor,
                                fontSize: 13,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SettingsThemeColorSwatch(
                                  option: settingsProvider.themeColor,
                                  isDarkMode: settingsProvider.isDarkMode,
                                  selected: false,
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.chevron_right,
                                  color: secondaryTextColor,
                                ),
                              ],
                            ),
                            onTap: () =>
                                showSettingsThemeColorSheet(this.context),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                AppSectionHeader('รอบคำนวณ'),
                SettingsGroup(
                  isDarkMode: isDarkMode,
                  child: Column(
                    children: [
                      ListTile(
                        leading: SettingsIcon(
                          icon: Icons.calendar_today_outlined,
                          color: secondaryTextColor,
                        ),
                        title: Text(
                          'วันเริ่มรอบรายเดือน',
                          style: TextStyle(color: textColor, fontSize: 16),
                        ),
                        subtitle: Text(
                          'วันที่ ${settings.monthlyCycleStartDay} · ใช้กับงบประมาณและสถิติรายปี',
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 13,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: secondaryTextColor,
                        ),
                        onTap: () =>
                            showSettingsMonthlyCycleStartDaySheet(this.context),
                      ),
                    ],
                  ),
                ),

                // API Section
                AppSectionHeader('API'),
                SettingsGroup(
                  isDarkMode: isDarkMode,
                  child: Column(
                    children: [
                      Consumer<SettingsProvider>(
                        builder: (context, settings, _) {
                          return SettingsToggleTile(
                            icon: Icons.currency_exchange_outlined,
                            title: 'อัตราแลกเปลี่ยนจาก Yahoo',
                            subtitle: settings.useYahooForExchangeRate
                                ? 'ใช้ Yahoo Finance สำหรับ USD/THB'
                                : 'ใช้ Frankfurter สำหรับ USD/THB',
                            isDarkMode: isDarkMode,
                            value: settings.useYahooForExchangeRate,
                            onChanged: (value) =>
                                settings.setExchangeRateSource(
                                  value
                                      ? ExchangeRateSource.yahoo
                                      : ExchangeRateSource.frankfurter,
                                ),
                          );
                        },
                      ),
                      Divider(
                        height: 1,
                        color: AppColors.listDividerFor(isDarkMode),
                      ),

                      Consumer<SettingsProvider>(
                        builder: (context, settings, _) {
                          return SettingsToggleTile(
                            icon: Icons.schedule_outlined,
                            title: 'ราคา Pre/Post จาก Yahoo',
                            subtitle: settings.useYahooExtendedHoursPrice
                                ? 'รวมราคานอกเวลาตลาดเมื่อใช้ Yahoo Finance'
                                : 'ใช้เฉพาะราคาช่วงตลาดปกติเมื่อใช้ Yahoo Finance',
                            isDarkMode: isDarkMode,
                            value: settings.useYahooExtendedHoursPrice,
                            onChanged: (value) =>
                                settings.setUseYahooExtendedHoursPrice(value),
                          );
                        },
                      ),
                      Divider(
                        height: 1,
                        color: AppColors.listDividerFor(isDarkMode),
                      ),

                      Consumer<SettingsProvider>(
                        builder: (context, settings, _) {
                          final finnhubReady = settings.isFinnhubConfigured;

                          return SettingsToggleTile(
                            icon: Icons.toggle_on_outlined,
                            title: 'ราคาจาก Finnhub',
                            subtitle: finnhubReady
                                ? settings.useFinnhubForPrices
                                      ? 'Finnhub API'
                                      : 'Yahoo Finance'
                                : 'ยังไม่ได้ตั้งค่า Finnhub API key',
                            isDarkMode: isDarkMode,
                            value: settings.useFinnhubForPrices,
                            onChanged: finnhubReady
                                ? (value) =>
                                      settings.setUseFinnhubForPrices(value)
                                : null,
                          );
                        },
                      ),
                      Divider(
                        height: 1,
                        color: AppColors.listDividerFor(isDarkMode),
                      ),

                      ListTile(
                        leading: SettingsIcon(
                          icon: Icons.api,
                          color: secondaryTextColor,
                        ),
                        title: Text(
                          'Finnhub API Key',
                          style: TextStyle(color: textColor, fontSize: 16),
                        ),
                        subtitle: Text(
                          'ตั้งค่า API key สำหรับดึงราคาหุ้น',
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 13,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: secondaryTextColor,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const FinnhubApiKeySettingsScreen(),
                            ),
                          );
                        },
                      ),
                      Divider(
                        height: 1,
                        color: AppColors.listDividerFor(isDarkMode),
                      ),

                      ListTile(
                        leading: SettingsIcon(
                          icon: Icons.auto_awesome,
                          color: secondaryTextColor,
                        ),
                        title: Text(
                          'LLM API Key',
                          style: TextStyle(color: textColor, fontSize: 16),
                        ),
                        subtitle: Text(
                          'ตั้งค่า API key สำหรับ LLM',
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 13,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: secondaryTextColor,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const LLMApiKeySettingsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Data Management Section
                AppSectionHeader('ข้อมูล'),
                SettingsGroup(
                  isDarkMode: isDarkMode,
                  child: Column(
                    children: [
                      ListTile(
                        leading: SettingsIcon(
                          icon: Icons.content_copy_outlined,
                          color: secondaryTextColor,
                        ),
                        title: Text(
                          'คัดลอกข้อมูลสำหรับ AI',
                          style: TextStyle(color: textColor, fontSize: 16),
                        ),
                        subtitle: Text(
                          'สรุปข้อมูลการเงินเป็น Markdown สำหรับใช้กับ LLM',
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 13,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: secondaryTextColor,
                        ),
                        onTap: _showAiFinanceExportSheet,
                      ),
                      Divider(
                        height: 1,
                        color: AppColors.listDividerFor(isDarkMode),
                      ),
                      ListTile(
                        leading: SettingsIcon(
                          icon: Icons.cloud,
                          color: dbManager.isConfigured
                              ? Colors.blue
                              : Colors.orange,
                        ),
                        title: Text(
                          'จัดการข้อมูล',
                          style: TextStyle(color: textColor, fontSize: 16),
                        ),
                        subtitle: Text(
                          dbManager.isConfigured
                              ? 'ฐานข้อมูล: Supabase (Cloud)'
                              : 'ฐานข้อมูล: ยังไม่ได้ตั้งค่าจาก build',
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 13,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: secondaryTextColor,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const DataManagementScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                if (reinstallReminder.isSupported &&
                    reinstallReminder.state != null) ...[
                  AppSectionHeader('การติดตั้ง'),
                  SettingsGroup(
                    isDarkMode: isDarkMode,
                    child: Column(
                      children: [
                        ListTile(
                          leading: SettingsIcon(
                            icon: reinstallReminder.needsExpiredBadge
                                ? Icons.error_outline
                                : Icons.timer_outlined,
                            color: reinstallReminder.needsExpiredBadge
                                ? (isDarkMode
                                      ? AppColors.darkExpense
                                      : AppColors.expense)
                                : secondaryTextColor,
                          ),
                          title: Text(
                            'สถานะการติดตั้ง',
                            style: TextStyle(color: textColor),
                          ),
                          subtitle: Text(
                            reinstallReminder.needsExpiredBadge
                                ? 'หมดอายุแล้ว กรุณาติดตั้งใหม่'
                                : 'เหลือ ${reinstallReminder.remainingLabel}',
                            style: TextStyle(color: secondaryTextColor),
                          ),
                        ),
                        Divider(
                          height: 1,
                          color: AppColors.listDividerFor(isDarkMode),
                        ),
                        SettingsToggleTile(
                          icon: Icons.notifications_outlined,
                          title: 'แจ้งเตือนติดตั้งใหม่',
                          subtitle: reinstallReminder.notificationEnabled
                              ? 'แจ้งเตือนเมื่อครบ 5 วัน'
                              : 'ปิดการแจ้งเตือนแล้ว',
                          isDarkMode: isDarkMode,
                          value: reinstallReminder.notificationEnabled,
                          onChanged: reinstallReminder.setNotificationEnabled,
                        ),
                      ],
                    ),
                  ),
                ],

                // About Section
                AppSectionHeader('เกี่ยวกับ'),
                SettingsGroup(
                  isDarkMode: isDarkMode,
                  child: Column(
                    children: [
                      FutureBuilder<PackageInfo>(
                        future: _packageInfoFuture,
                        builder: (context, snapshot) {
                          final versionText = snapshot.hasData
                              ? _formatVersion(snapshot.data!)
                              : 'กำลังโหลด...';

                          return ListTile(
                            leading: SettingsIcon(
                              icon: Icons.info_outline,
                              color: secondaryTextColor,
                            ),
                            title: Text(
                              'เวอร์ชัน',
                              style: TextStyle(color: textColor, fontSize: 16),
                            ),
                            subtitle: Text(
                              versionText,
                              style: TextStyle(
                                color: secondaryTextColor,
                                fontSize: 13,
                              ),
                            ),
                          );
                        },
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

  Future<void> _showLogoutDialog(BuildContext context) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'ออกจากระบบ',
      message: 'คุณต้องการออกจากระบบหรือไม่?',
      confirmLabel: 'ออกจากระบบ',
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) return;

    // Logout - ล้างแค่ login state ไม่ล้าง Supabase config
    await context.read<AuthProvider>().signOut();

    // Clear all providers (ข้อมูลเก่าของ user ก่อนหน้า)
    if (context.mounted) {
      await _clearAllProviders(context);
    }

    // Navigate to login screen and clear navigation stack
    if (context.mounted) {
      context.go('/auth');
    }
  }

  Future<void> _clearAllProviders(BuildContext context) async {
    debugPrint('[SettingsScreen] Clearing all providers...');

    try {
      // Reload providers ด้วยข้อมูลว่าง (SQLite mode หลัง logout)
      await Future.wait([
        context.read<AccountProvider>().reload(),
        context.read<CategoryProvider>().reload(),
        context.read<TransactionProvider>().reload(),
        context.read<BudgetProvider>().reload(),
        context.read<RecurringTransactionProvider>().reload(),
        context.read<CashFlowForecastProvider>().reload(),
      ]);

      debugPrint('[SettingsScreen] Providers cleared and reloaded');
    } catch (e) {
      debugPrint('[SettingsScreen] Error clearing providers: $e');
    }
  }

  Future<void> _showAiFinanceExportSheet() async {
    final scope = await showAppModalBottomSheet<AiFinanceExportScope>(
      context: context,
      builder: (ctx) {
        final isDarkMode = ctx.watch<SettingsProvider>().isDarkMode;
        final textColor = isDarkMode
            ? AppColors.darkTextPrimary
            : AppColors.textPrimary;
        final secondaryTextColor = isDarkMode
            ? AppColors.darkTextSecondary
            : AppColors.textSecondary;

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppModalBottomSheetHeader(title: 'คัดลอกข้อมูลสำหรับ AI'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Text(
                  'ข้อมูลที่คัดลอกจะเป็นสรุป Markdown และไม่รวมหมายเหตุของธุรกรรม',
                  style: TextStyle(color: secondaryTextColor, fontSize: 13),
                ),
              ),
              _buildExportScopeTile(
                context: ctx,
                icon: Icons.auto_awesome_outlined,
                title: 'ภาพรวมทั้งหมด',
                subtitle: 'Net worth, บัญชี, cashflow, budget และพอร์ต',
                scope: AiFinanceExportScope.overview,
                textColor: textColor,
                secondaryTextColor: secondaryTextColor,
              ),
              _buildExportScopeTile(
                context: ctx,
                icon: Icons.account_balance_wallet_outlined,
                title: 'บัญชีและเงินสด',
                subtitle: 'ยอดบัญชี, กลุ่มสินทรัพย์/หนี้สิน และพอร์ต',
                scope: AiFinanceExportScope.accounts,
                textColor: textColor,
                secondaryTextColor: secondaryTextColor,
              ),
              _buildExportScopeTile(
                context: ctx,
                icon: Icons.receipt_long_outlined,
                title: 'รายรับรายจ่าย/งบเดือนนี้',
                subtitle: 'Cashflow, หมวดรายจ่าย และสถานะงบประมาณ',
                scope: AiFinanceExportScope.monthlyCashflow,
                textColor: textColor,
                secondaryTextColor: secondaryTextColor,
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );

    if (scope == null || !mounted) return;
    await _copyAiFinanceSnapshot(scope);
  }

  Future<void> _copyAiFinanceSnapshot(AiFinanceExportScope scope) async {
    try {
      final snapshot = AiFinanceExportService.instance.buildMarkdown(
        scope: scope,
        accountProvider: context.read<AccountProvider>(),
        transactionProvider: context.read<TransactionProvider>(),
        categoryProvider: context.read<CategoryProvider>(),
        budgetProvider: context.read<BudgetProvider>(),
        settingsProvider: context.read<SettingsProvider>(),
      );

      await Clipboard.setData(ClipboardData(text: snapshot));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('คัดลอก${scope.label}เรียบร้อยแล้ว')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('คัดลอกข้อมูลไม่สำเร็จ: $e')));
    }
  }

  String _formatVersion(PackageInfo packageInfo) {
    final buildNumber = packageInfo.buildNumber.trim();
    if (buildNumber.isEmpty) {
      return packageInfo.version;
    }

    return '${packageInfo.version} ($buildNumber)';
  }

  Widget _buildExportScopeTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required AiFinanceExportScope scope,
    required Color textColor,
    required Color secondaryTextColor,
  }) {
    return ListTile(
      tileColor: Colors.transparent,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: SettingsIcon(icon: icon, color: secondaryTextColor),
      title: Text(title, style: TextStyle(color: textColor)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: secondaryTextColor, fontSize: 12),
      ),
      trailing: Icon(Icons.chevron_right, color: secondaryTextColor),
      onTap: () => Navigator.pop(context, scope),
    );
  }
}
