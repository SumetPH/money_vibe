import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/database_manager.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_drawer.dart';
import 'backup_restore_screen.dart';
import 'api_key_settings_screen.dart';
import 'database_settings_screen.dart';

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
        backgroundColor: surfaceColor,
        foregroundColor: textColor,
        title: Text('ตั้งค่า', style: TextStyle(color: textColor)),
        elevation: 0,
      ),
      drawer: const AppDrawer(currentRoute: '/settings'),
      body: Consumer<DatabaseManager>(
        builder: (context, dbManager, _) {
          return ListView(
            children: [
              // Appearance Section
              _buildSectionHeader('ลักษณะ', textColor),
              Consumer<SettingsProvider>(
                builder: (context, settingsProvider, _) {
                  return SwitchListTile(
                    secondary: Icon(
                      Icons.dark_mode_outlined,
                      color: secondaryTextColor,
                    ),
                    title: Text('โหมดมืด', style: TextStyle(color: textColor)),
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
                trailing: Icon(Icons.chevron_right, color: secondaryTextColor),
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

              // Database Section
              _buildSectionHeader('ฐานข้อมูล', textColor),
              ListTile(
                leading: Icon(
                  dbManager.isSqliteMode ? Icons.storage : Icons.cloud,
                  color: dbManager.isSqliteMode ? Colors.orange : Colors.blue,
                ),
                title: Text(
                  'ตั้งค่า Database',
                  style: TextStyle(color: textColor),
                ),
                subtitle: Text(
                  dbManager.isSqliteMode
                      ? 'SQLite (Local) - แตะเพื่อเปลี่ยน'
                      : 'Supabase (Cloud) - แตะเพื่อเปลี่ยน',
                  style: TextStyle(color: secondaryTextColor),
                ),
                trailing: Icon(Icons.chevron_right, color: secondaryTextColor),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DatabaseSettingsScreen(),
                    ),
                  );
                },
              ),
              Divider(color: dividerColor),

              // Backup/Restore Section
              _buildSectionHeader('ข้อมูล', textColor),
              ListTile(
                leading: Icon(Icons.backup_outlined, color: secondaryTextColor),
                title: Text(
                  'สำรองและกู้คืนข้อมูล',
                  style: TextStyle(color: textColor),
                ),
                subtitle: Text(
                  'Backup/Restore',
                  style: TextStyle(color: secondaryTextColor),
                ),
                trailing: Icon(Icons.chevron_right, color: secondaryTextColor),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BackupRestoreScreen(),
                    ),
                  );
                },
              ),
              Divider(color: dividerColor),
            ],
          );
        },
      ),
    );
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
