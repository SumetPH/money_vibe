import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/app_drawer.dart';
import 'backup_restore_screen.dart';
import 'api_key_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ตั้งค่า')),
      drawer: const AppDrawer(currentRoute: '/settings'),
      body: ListView(
        children: [
          // Appearance Section
          const ListTile(
            title: Text(
              'ลักษณะ',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Consumer<SettingsProvider>(
            builder: (context, settingsProvider, _) {
              return SwitchListTile(
                secondary: const Icon(Icons.dark_mode_outlined),
                title: const Text('โหมดมืด'),
                subtitle: const Text('ใช้ธีมสีเข้ม'),
                value: settingsProvider.isDarkMode,
                onChanged: (value) {
                  settingsProvider.setDarkMode(value);
                },
              );
            },
          ),
          const Divider(),

          // Finnhub API Key Section
          const ListTile(
            title: Text('API', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.api),
            title: const Text('Finnhub API Key'),
            subtitle: const Text('ตั้งค่า API key สำหรับดึงราคาหุ้น'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ApiKeySettingsScreen(),
                ),
              );
            },
          ),
          const Divider(),

          // Backup/Restore Section
          const ListTile(
            title: Text(
              'ข้อมูล',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('สำรองและกู้คืนข้อมูล'),
            subtitle: const Text('Backup/Restore ด้วย SQL'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BackupRestoreScreen(),
                ),
              );
            },
          ),
          const Divider(),
        ],
      ),
    );
  }
}
