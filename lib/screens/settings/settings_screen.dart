import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/recurring_transaction_provider.dart';
import '../../repositories/database_repository.dart';
import '../../services/database_manager.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_drawer.dart';
import '../auth/auth_screen.dart';
import 'api_key_settings_screen.dart';
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
                // Account Section (สำหรับ Supabase mode)
                if (dbManager.currentMode == DatabaseMode.supabase) ...[
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
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AuthScreen(),
                              ),
                            );
                          },
                        );
                      }
                    },
                  ),
                  Divider(color: dividerColor),
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
                        builder: (context) => const ApiKeySettingsScreen(),
                      ),
                    );
                  },
                ),
                Divider(color: dividerColor),

                // Data Management Section
                _buildSectionHeader('ข้อมูล', textColor),
                ListTile(
                  leading: Icon(
                    dbManager.isSqliteMode ? Icons.storage : Icons.cloud,
                    color: dbManager.isSqliteMode ? Colors.orange : Colors.blue,
                  ),
                  title: Text(
                    'จัดการข้อมูล',
                    style: TextStyle(color: textColor),
                  ),
                  subtitle: Text(
                    dbManager.isSqliteMode
                        ? 'ฐานข้อมูล: SQLite (Local) - แตะเพื่อตั้งค่า'
                        : 'ฐานข้อมูล: Supabase (Cloud) - แตะเพื่อตั้งค่า',
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

              // Logout
              await context.read<AuthProvider>().signOut();

              // Clear all providers (ข้อมูลเก่าของ user ก่อนหน้า)
              if (context.mounted) {
                await _clearAllProviders(context);
              }

              // Switch back to SQLite mode (ไม่บังคับ login)
              final dbManager = DatabaseManager();
              await dbManager.switchMode(DatabaseMode.sqlite);
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
