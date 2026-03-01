import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';
import 'backup_restore_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ตั้งค่า'),
      ),
      drawer: const AppDrawer(currentRoute: '/settings'),
      body: ListView(
        children: [
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
            subtitle: const Text('Backup/Restore ด้วย CSV'),
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
