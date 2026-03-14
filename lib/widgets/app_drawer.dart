import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../providers/settings_provider.dart';

class AppDrawer extends StatelessWidget {
  final String currentRoute;

  const AppDrawer({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, _) {
        final isDarkMode = settingsProvider.isDarkMode;
        final drawerHeaderColor = isDarkMode
            ? AppColors.darkHeader
            : AppColors.header;
        final drawerItemSecondaryColor = isDarkMode
            ? AppColors.darkTextSecondary
            : AppColors.textSecondary;
        final selectedColor = isDarkMode
            ? AppColors.darkIncome
            : AppColors.header;
        final selectedTileColor =
            (isDarkMode ? AppColors.darkHeader : AppColors.header).withValues(
              alpha: 0.08,
            );

        return Drawer(
          child: Column(
            children: [
              DrawerHeader(
                decoration: BoxDecoration(color: drawerHeaderColor),
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
                        'Money Vibe',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Text(
                        'การเงินส่วนบุคคล',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
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
                      icon: Icons.account_balance_wallet,
                      label: 'บัญชี',
                      selected: currentRoute == '/accounts',
                      onTap: () => _navigate(context, '/accounts'),
                      selectedColor: selectedColor,
                      unselectedColor: drawerItemSecondaryColor,
                      selectedTileColor: selectedTileColor,
                      isDarkMode: isDarkMode,
                    ),
                    Divider(
                      color: isDarkMode
                          ? AppColors.darkDivider
                          : AppColors.divider,
                    ),
                    _DrawerItem(
                      icon: Icons.receipt_long,
                      label: 'รายการ',
                      selected: currentRoute == '/transactions',
                      onTap: () => _navigate(context, '/transactions'),
                      selectedColor: selectedColor,
                      unselectedColor: drawerItemSecondaryColor,
                      selectedTileColor: selectedTileColor,
                      isDarkMode: isDarkMode,
                    ),
                    Divider(
                      color: isDarkMode
                          ? AppColors.darkDivider
                          : AppColors.divider,
                    ),
                    _DrawerItem(
                      icon: Icons.account_balance_outlined,
                      label: 'งบประมาณ',
                      selected: currentRoute == '/budgets',
                      onTap: () => _navigate(context, '/budgets'),
                      selectedColor: selectedColor,
                      unselectedColor: drawerItemSecondaryColor,
                      selectedTileColor: selectedTileColor,
                      isDarkMode: isDarkMode,
                    ),
                    Divider(
                      color: isDarkMode
                          ? AppColors.darkDivider
                          : AppColors.divider,
                    ),
                    _DrawerItem(
                      icon: Icons.repeat,
                      label: 'รายการประจำ',
                      selected: currentRoute == '/recurring',
                      onTap: () => _navigate(context, '/recurring'),
                      selectedColor: selectedColor,
                      unselectedColor: drawerItemSecondaryColor,
                      selectedTileColor: selectedTileColor,
                      isDarkMode: isDarkMode,
                    ),
                    Divider(
                      color: isDarkMode
                          ? AppColors.darkDivider
                          : AppColors.divider,
                    ),
                    _DrawerItem(
                      icon: Icons.category_outlined,
                      label: 'หมวดหมู่',
                      selected: currentRoute == '/categories',
                      onTap: () => _navigate(context, '/categories'),
                      selectedColor: selectedColor,
                      unselectedColor: drawerItemSecondaryColor,
                      selectedTileColor: selectedTileColor,
                      isDarkMode: isDarkMode,
                    ),
                    Divider(
                      color: isDarkMode
                          ? AppColors.darkDivider
                          : AppColors.divider,
                    ),
                    _DrawerItem(
                      icon: Icons.pie_chart_outline,
                      label: 'สถิติ',
                      selected: currentRoute == '/statistics',
                      onTap: () => _navigate(context, '/statistics'),
                      selectedColor: selectedColor,
                      unselectedColor: drawerItemSecondaryColor,
                      selectedTileColor: selectedTileColor,
                      isDarkMode: isDarkMode,
                    ),
                    Divider(
                      color: isDarkMode
                          ? AppColors.darkDivider
                          : AppColors.divider,
                    ),
                    _DrawerItem(
                      icon: Icons.settings_outlined,
                      label: 'การตั้งค่า',
                      selected: currentRoute == '/settings',
                      onTap: () => _navigate(context, '/settings'),
                      selectedColor: selectedColor,
                      unselectedColor: drawerItemSecondaryColor,
                      selectedTileColor: selectedTileColor,
                      isDarkMode: isDarkMode,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _navigate(BuildContext context, String route) {
    Navigator.pop(context);
    if (currentRoute != route) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, route);
      });
    }
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedColor;
  final Color unselectedColor;
  final Color selectedTileColor;
  final bool isDarkMode;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.selectedColor,
    required this.unselectedColor,
    required this.selectedTileColor,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: selected ? selectedColor : unselectedColor),
      title: Text(
        label,
        style: TextStyle(
          color: selected
              ? selectedColor
              : (isDarkMode
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary),
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: selected,
      selectedTileColor: selectedTileColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      mouseCursor: SystemMouseCursors.click,
      visualDensity: VisualDensity.comfortable,
      minLeadingWidth: 24,
      onTap: onTap,
    );
  }
}
