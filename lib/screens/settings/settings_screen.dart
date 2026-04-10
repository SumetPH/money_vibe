import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:money_vibe/screens/settings/llm_api_key_settings_screen.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/recurring_transaction_provider.dart';

import '../../services/database_manager.dart';
import '../../services/app_refresh_reminder_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_drawer.dart';
import 'finnhubapi_key_settings_screen.dart';
import 'data_management_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<SettingsProvider>().isDarkMode;
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

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.header,
        foregroundColor: textColor,
        title: Text('ตั้งค่า'),
        elevation: 0,
      ),
      drawer: const AppDrawer(currentRoute: '/settings'),
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
                      'ไปที่จัดการข้อมูลเพื่อตั้งค่า',
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

                // API Section
                _buildSectionHeader('API', textColor),
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

                // App Section
                _buildSectionHeader('แอป', textColor),
                FutureBuilder<String>(
                  future: AppRefreshReminderService.instance
                      .getReminderStatusLabel(),
                  builder: (context, snapshot) {
                    final statusLabel = snapshot.data ?? 'กำลังโหลด...';

                    return ListTile(
                      leading: Icon(
                        Icons.notifications_active_outlined,
                        color: secondaryTextColor,
                      ),
                      title: Text(
                        'เตือน build ใหม่',
                        style: TextStyle(color: textColor),
                      ),
                      subtitle: Text(
                        statusLabel,
                        style: TextStyle(color: secondaryTextColor),
                      ),
                      // isThreeLine: true,
                    );
                  },
                ),
                Divider(color: dividerColor),

                // Data Management Section
                _buildSectionHeader('ข้อมูล', textColor),
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
                        ? 'ฐานข้อมูล: Supabase (Cloud) - แตะเพื่อตั้งค่า'
                        : 'ฐานข้อมูล: ยังไม่ได้ตั้งค่า - แตะเพื่อตั้งค่า',
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
            ),
          );
        },
      ),
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

  Widget _buildSectionHeader(String title, Color textColor) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
      ),
    );
  }
}
