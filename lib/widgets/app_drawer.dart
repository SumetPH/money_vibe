import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppDrawer extends StatelessWidget {
  final String currentRoute;

  const AppDrawer({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AppColors.header),
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(20),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Money',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Text(
                    'การเงินส่วนบุคคล',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _DrawerItem(
                  icon: Icons.receipt_long,
                  label: 'รายการ',
                  selected: currentRoute == '/',
                  onTap: () => _navigate(context, '/'),
                ),
                _DrawerItem(
                  icon: Icons.account_balance_wallet,
                  label: 'บัญชี',
                  selected: currentRoute == '/accounts',
                  onTap: () => _navigate(context, '/accounts'),
                ),
                _DrawerItem(
                  icon: Icons.category_outlined,
                  label: 'หมวดหมู่',
                  selected: currentRoute == '/categories',
                  onTap: () => _navigate(context, '/categories'),
                ),
                const Divider(),
                _DrawerItem(
                  icon: Icons.pie_chart_outline,
                  label: 'สถิติ',
                  selected: false,
                  onTap: () => Navigator.pop(context),
                ),
                _DrawerItem(
                  icon: Icons.settings_outlined,
                  label: 'การตั้งค่า',
                  selected: currentRoute == '/settings',
                  onTap: () => _navigate(context, '/settings'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigate(BuildContext context, String route) {
    Navigator.pop(context); // close drawer
    if (currentRoute != route) {
      Navigator.pushReplacementNamed(context, route);
    }
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: selected ? AppColors.header : AppColors.textSecondary,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: selected ? AppColors.header : AppColors.textPrimary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: selected,
      selectedTileColor: AppColors.header.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      onTap: onTap,
    );
  }
}
