import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';

import '../../services/database_manager.dart';
import '../../theme/app_colors.dart';
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

    final isLargeScreen = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        leading: isLargeScreen ? null : null,
        backgroundColor: AppColors.header,
        foregroundColor: textColor,
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
                  leading: const Icon(Icons.storage, color: Colors.teal),
                  title: Text(
                    'จัดการข้อมูล',
                    style: TextStyle(color: textColor),
                  ),
                  subtitle: Text(
                    'ฐานข้อมูล: ภายในเครื่อง (SQLite)',
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
}
