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

import '../../services/ai_finance_export_service.dart';
import '../../services/database_manager.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_color_option.dart';
import '../../widgets/app_drawer.dart';
import 'finnhubapi_key_settings_screen.dart';
import 'data_management_screen.dart';
import 'llm_api_key_settings_screen.dart';

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
    final themeColor = settings.themeColor;
    final backgroundColor = isDarkMode
        ? AppColors.darkBackground
        : AppColors.background;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final secondaryTextColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;

    final isLargeScreen = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        leading: isLargeScreen ? null : null,
        backgroundColor: AppColors.headerFor(isDarkMode, themeColor),
        foregroundColor: Colors.white,
        title: Text('ตั้งค่า'),
        elevation: 0,
      ),
      drawer: isLargeScreen ? null : const AppDrawer(currentRoute: '/settings'),
      body: Consumer<DatabaseManager>(
        builder: (context, dbManager, _) {
          return SafeArea(
            top: false,
            child: ListView(
              children: [
                // Account Section
                _buildSectionHeader('บัญชีผู้ใช้', textColor),
                Consumer<AuthProvider>(
                  builder: (context, authProvider, _) {
                    if (authProvider.isLoggedIn) {
                      // แสดงเมื่อ login แล้ว
                      return Column(
                        children: [
                          ListTile(
                            leading: Icon(
                              Icons.person,
                              color: secondaryTextColor,
                            ),
                            title: Text(
                              authProvider.userEmail ?? 'ผู้ใช้',
                              style: TextStyle(color: textColor),
                            ),
                            subtitle: Text(
                              'อีเมลปัจจุบัน',
                              style: TextStyle(color: secondaryTextColor),
                            ),
                          ),
                          ListTile(
                            leading: Icon(
                              Icons.logout,
                              color: AppColors.expense,
                            ),
                            title: Text(
                              'ออกจากระบบ',
                              style: TextStyle(color: AppColors.expense),
                            ),
                            onTap: () => _showLogoutDialog(context),
                          ),
                        ],
                      );
                    } else {
                      // แสดงเมื่อยังไม่ได้ login
                      return ListTile(
                        leading: Icon(Icons.login, color: AppColors.income),
                        title: Text(
                          'เข้าสู่ระบบ',
                          style: TextStyle(color: AppColors.income),
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
                Divider(color: dividerColor),
                if (!dbManager.isConfigured) ...[
                  ListTile(
                    leading: Icon(Icons.cloud_off, color: Colors.orange),
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
                          builder: (context) => const DataManagementScreen(),
                        ),
                      );
                    },
                  ),
                ],
                Divider(color: dividerColor),

                // Appearance Section
                _buildSectionHeader('ลักษณะ', textColor),
                Consumer<SettingsProvider>(
                  builder: (context, settingsProvider, _) {
                    return SwitchListTile(
                      secondary: Icon(
                        Icons.dark_mode_outlined,
                        color: secondaryTextColor,
                      ),
                      title: Text(
                        'โหมดมืด',
                        style: TextStyle(color: textColor),
                      ),
                      subtitle: Text(
                        'ใช้ธีมสีเข้ม',
                        style: TextStyle(color: secondaryTextColor),
                      ),
                      value: settingsProvider.isDarkMode,
                      onChanged: (value) {
                        settingsProvider.setDarkMode(value);
                      },
                    );
                  },
                ),
                Divider(color: dividerColor),
                Consumer<SettingsProvider>(
                  builder: (context, settingsProvider, _) {
                    return ListTile(
                      leading: Icon(
                        Icons.palette_outlined,
                        color: secondaryTextColor,
                      ),
                      title: Text('สีธีม', style: TextStyle(color: textColor)),
                      subtitle: Text(
                        settingsProvider.themeColor.label,
                        style: TextStyle(color: secondaryTextColor),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ThemeColorSwatch(
                            option: settingsProvider.themeColor,
                            isDarkMode: settingsProvider.isDarkMode,
                            selected: false,
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.chevron_right, color: secondaryTextColor),
                        ],
                      ),
                      onTap: _showThemeColorSheet,
                    );
                  },
                ),
                Divider(color: dividerColor),

                // API Section
                _buildSectionHeader('API', textColor),

                Consumer<SettingsProvider>(
                  builder: (context, settings, _) {
                    return SwitchListTile(
                      secondary: Icon(
                        Icons.currency_exchange_outlined,
                        color: secondaryTextColor,
                      ),
                      title: Text(
                        'อัตราแลกเปลี่ยนจาก Yahoo',
                        style: TextStyle(color: textColor),
                      ),
                      subtitle: Text(
                        settings.useYahooForExchangeRate
                            ? 'ใช้ Yahoo Finance สำหรับ USD/THB'
                            : 'ใช้ Frankfurter สำหรับ USD/THB',
                        style: TextStyle(color: secondaryTextColor),
                      ),
                      value: settings.useYahooForExchangeRate,
                      onChanged: (value) => settings.setExchangeRateSource(
                        value
                            ? ExchangeRateSource.yahoo
                            : ExchangeRateSource.frankfurter,
                      ),
                    );
                  },
                ),
                Divider(color: dividerColor),

                Consumer<SettingsProvider>(
                  builder: (context, settings, _) {
                    return SwitchListTile(
                      secondary: Icon(
                        Icons.schedule_outlined,
                        color: secondaryTextColor,
                      ),
                      title: Text(
                        'ราคา Pre/Post จาก Yahoo',
                        style: TextStyle(color: textColor),
                      ),
                      subtitle: Text(
                        settings.useYahooExtendedHoursPrice
                            ? 'รวมราคานอกเวลาตลาดเมื่อใช้ Yahoo Finance'
                            : 'ใช้เฉพาะราคาช่วงตลาดปกติเมื่อใช้ Yahoo Finance',
                        style: TextStyle(color: secondaryTextColor),
                      ),
                      value: settings.useYahooExtendedHoursPrice,
                      onChanged: (value) =>
                          settings.setUseYahooExtendedHoursPrice(value),
                    );
                  },
                ),
                Divider(color: dividerColor),

                Consumer<SettingsProvider>(
                  builder: (context, settings, _) {
                    final finnhubReady = settings.isFinnhubConfigured;

                    return SwitchListTile(
                      secondary: Icon(
                        Icons.toggle_on_outlined,
                        color: secondaryTextColor,
                      ),
                      title: Text(
                        'ราคาจาก Finnhub',
                        style: TextStyle(color: textColor),
                      ),
                      subtitle: Text(
                        finnhubReady
                            ? settings.useFinnhubForPrices
                                  ? 'Finnhub API'
                                  : 'Yahoo Finance'
                            : 'ยังไม่ได้ตั้งค่า Finnhub API key',
                        style: TextStyle(color: secondaryTextColor),
                      ),
                      value: settings.useFinnhubForPrices,
                      onChanged: finnhubReady
                          ? (value) => settings.setUseFinnhubForPrices(value)
                          : null,
                    );
                  },
                ),
                Divider(color: dividerColor),

                ListTile(
                  leading: Icon(Icons.api, color: secondaryTextColor),
                  title: Text(
                    'Finnhub API Key',
                    style: TextStyle(color: textColor),
                  ),
                  subtitle: Text(
                    'ตั้งค่า API key สำหรับดึงราคาหุ้น',
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
                            const FinnhubApiKeySettingsScreen(),
                      ),
                    );
                  },
                ),
                Divider(color: dividerColor),

                ListTile(
                  leading: Icon(Icons.auto_awesome, color: secondaryTextColor),
                  title: Text(
                    'LLM API Key',
                    style: TextStyle(color: textColor),
                  ),
                  subtitle: Text(
                    'ตั้งค่า API key สำหรับ LLM',
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
                        builder: (context) => const LLMApiKeySettingsScreen(),
                      ),
                    );
                  },
                ),
                Divider(color: dividerColor),

                // Data Management Section
                _buildSectionHeader('ข้อมูล', textColor),
                ListTile(
                  leading: Icon(
                    Icons.content_copy_outlined,
                    color: secondaryTextColor,
                  ),
                  title: Text(
                    'คัดลอกข้อมูลสำหรับ AI',
                    style: TextStyle(color: textColor),
                  ),
                  subtitle: Text(
                    'สรุปข้อมูลการเงินเป็น Markdown สำหรับใช้กับ LLM',
                    style: TextStyle(color: secondaryTextColor),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: secondaryTextColor,
                  ),
                  onTap: _showAiFinanceExportSheet,
                ),
                Divider(color: dividerColor),
                ListTile(
                  leading: Icon(
                    Icons.cloud,
                    color: dbManager.isConfigured ? Colors.blue : Colors.orange,
                  ),
                  title: Text(
                    'จัดการข้อมูล',
                    style: TextStyle(color: textColor),
                  ),
                  subtitle: Text(
                    dbManager.isConfigured
                        ? 'ฐานข้อมูล: Supabase (Cloud)'
                        : 'ฐานข้อมูล: ยังไม่ได้ตั้งค่าจาก build',
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
                        builder: (context) => const DataManagementScreen(),
                      ),
                    );
                  },
                ),
                Divider(color: dividerColor),

                // About Section
                _buildSectionHeader('เกี่ยวกับ', textColor),
                FutureBuilder<PackageInfo>(
                  future: _packageInfoFuture,
                  builder: (context, snapshot) {
                    final versionText = snapshot.hasData
                        ? _formatVersion(snapshot.data!)
                        : 'กำลังโหลด...';

                    return ListTile(
                      leading: Icon(
                        Icons.info_outline,
                        color: secondaryTextColor,
                      ),
                      title: Text(
                        'เวอร์ชัน',
                        style: TextStyle(color: textColor),
                      ),
                      subtitle: Text(
                        versionText,
                        style: TextStyle(color: secondaryTextColor),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showThemeColorSheet() {
    final currentSettings = context.read<SettingsProvider>();
    final sheetColor = currentSettings.isDarkMode
        ? AppColors.darkSurface
        : AppColors.surface;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: sheetColor,
      showDragHandle: true,
      builder: (ctx) {
        final settings = ctx.watch<SettingsProvider>();
        final isDarkMode = settings.isDarkMode;
        final textColor = isDarkMode
            ? AppColors.darkTextPrimary
            : AppColors.textPrimary;
        final secondaryTextColor = isDarkMode
            ? AppColors.darkTextSecondary
            : AppColors.textSecondary;
        final dividerColor = isDarkMode
            ? AppColors.darkDivider
            : AppColors.divider;

        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: ThemeColorOption.values.length + 1,
            separatorBuilder: (_, index) => index == 0
                ? const SizedBox(height: 4)
                : Divider(color: dividerColor, height: 1),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    'สีธีม',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }

              final option = ThemeColorOption.values[index - 1];
              final selected = option.id == settings.themeColor.id;
              return ListTile(
                tileColor: Colors.transparent,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                minLeadingWidth: 44,
                leading: _ThemeColorSwatch(
                  option: option,
                  isDarkMode: isDarkMode,
                  selected: selected,
                ),
                title: Text(option.label, style: TextStyle(color: textColor)),
                subtitle: selected
                    ? Text(
                        'กำลังใช้งาน',
                        style: TextStyle(
                          color: secondaryTextColor,
                          fontSize: 12,
                        ),
                      )
                    : null,
                trailing: selected
                    ? Icon(
                        Icons.check_circle,
                        color: AppColors.accentFor(isDarkMode, option),
                      )
                    : null,
                onTap: () {
                  settings.setThemeColor(option);
                  Navigator.pop(ctx);
                },
              );
            },
          ),
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context) {
    final isDarkMode = context.read<SettingsProvider>().isDarkMode;
    final surfaceColor = isDarkMode ? AppColors.darkSurface : Colors.white;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceColor,
        title: Text('ออกจากระบบ', style: TextStyle(color: textColor)),
        content: Text(
          'คุณต้องการออกจากระบบหรือไม่?',
          style: TextStyle(color: textColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);

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
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.expense,
              foregroundColor: Colors.white,
            ),
            child: Text('ออกจากระบบ'),
          ),
        ],
      ),
    );
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
      ]);

      debugPrint('[SettingsScreen] Providers cleared and reloaded');
    } catch (e) {
      debugPrint('[SettingsScreen] Error clearing providers: $e');
    }
  }

  Future<void> _showAiFinanceExportSheet() async {
    final scope = await showModalBottomSheet<AiFinanceExportScope>(
      context: context,
      showDragHandle: true,
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'คัดลอกข้อมูลสำหรับ AI',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ข้อมูลที่คัดลอกจะเป็นสรุป Markdown และไม่รวมหมายเหตุของธุรกรรม',
                      style: TextStyle(color: secondaryTextColor, fontSize: 13),
                    ),
                  ],
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

  Widget _buildSectionHeader(String title, Color textColor) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
      ),
    );
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
      leading: Icon(icon, color: secondaryTextColor),
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

class _ThemeColorSwatch extends StatelessWidget {
  final ThemeColorOption option;
  final bool isDarkMode;
  final bool selected;

  const _ThemeColorSwatch({
    required this.option,
    required this.isDarkMode,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final header = AppColors.headerFor(isDarkMode, option);
    final accent = AppColors.accentFor(isDarkMode, option);
    final fab = AppColors.fabFor(isDarkMode, option);

    return Container(
      width: 44,
      height: 28,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.darkSurfaceVariant : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected
              ? accent
              : (isDarkMode ? AppColors.darkDivider : AppColors.divider),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: header,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(4),
                ),
              ),
            ),
          ),
          Expanded(child: ColoredBox(color: accent)),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: fab,
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
