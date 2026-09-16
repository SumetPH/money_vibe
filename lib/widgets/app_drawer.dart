import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../providers/settings_provider.dart';
import '../services/reinstall_reminder_service.dart';

class AppDrawer extends StatelessWidget {
  final String currentRoute;

  const AppDrawer({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, _) {
        final isDarkMode = settingsProvider.isDarkMode;
        final themeColor = settingsProvider.themeColor;
        final drawerColor = isDarkMode
            ? AppColors.darkBackground
            : AppColors.background;
        final drawerItemSecondaryColor = isDarkMode
            ? AppColors.darkTextSecondary
            : AppColors.textSecondary;
        final selectedColor = AppColors.accentFor(isDarkMode, themeColor);
        final selectedTileColor = isDarkMode
            ? AppColors.darkSurface
            : AppColors.surface;
        final dividerColor = isDarkMode
            ? AppColors.darkDivider
            : AppColors.divider;
        final textColor = isDarkMode
            ? AppColors.darkTextPrimary
            : AppColors.textPrimary;

        return Drawer(
          width: MediaQuery.sizeOf(context).width * 0.78,
          backgroundColor: drawerColor,
          shape: const RoundedRectangleBorder(),
          child: Column(
            children: [
              Container(
                color: drawerColor,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: selectedTileColor,
                            borderRadius: BorderRadius.circular(
                              AppRadii.xLarge,
                            ),
                          ),
                          child: Icon(
                            Icons.account_balance_wallet_outlined,
                            color: selectedColor,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Money Vibe',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'กระเป๋าของคุณ',
                                style: TextStyle(
                                  color: drawerItemSecondaryColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Divider(height: 1, color: dividerColor),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
                  children: [
                    _DrawerSectionLabel(
                      label: 'ภาพรวม',
                      color: drawerItemSecondaryColor,
                    ),
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
                    _DrawerItem(
                      icon: Icons.receipt_long_outlined,
                      label: 'รายการ',
                      selected: currentRoute == '/transactions',
                      onTap: () => _navigate(context, '/transactions'),
                      selectedColor: selectedColor,
                      unselectedColor: drawerItemSecondaryColor,
                      selectedTileColor: selectedTileColor,
                      isDarkMode: isDarkMode,
                    ),
                    _DrawerSectionLabel(
                      label: 'วางแผน',
                      color: drawerItemSecondaryColor,
                    ),
                    _DrawerItem(
                      icon: Icons.savings_outlined,
                      label: 'งบประมาณ',
                      selected: currentRoute == '/budgets',
                      onTap: () => _navigate(context, '/budgets'),
                      selectedColor: selectedColor,
                      unselectedColor: drawerItemSecondaryColor,
                      selectedTileColor: selectedTileColor,
                      isDarkMode: isDarkMode,
                    ),
                    _DrawerItem(
                      icon: Icons.sync_alt,
                      label: 'รายการประจำ',
                      selected: currentRoute == '/recurring',
                      onTap: () => _navigate(context, '/recurring'),
                      selectedColor: selectedColor,
                      unselectedColor: drawerItemSecondaryColor,
                      selectedTileColor: selectedTileColor,
                      isDarkMode: isDarkMode,
                    ),
                    _DrawerSectionLabel(
                      label: 'ข้อมูลเชิงลึก',
                      color: drawerItemSecondaryColor,
                    ),
                    _DrawerItem(
                      icon: Icons.query_stats,
                      label: 'สถิติ',
                      selected: currentRoute == '/statistics',
                      onTap: () => _navigate(context, '/statistics'),
                      selectedColor: selectedColor,
                      unselectedColor: drawerItemSecondaryColor,
                      selectedTileColor: selectedTileColor,
                      isDarkMode: isDarkMode,
                    ),
                    _DrawerItem(
                      icon: Icons.trending_up,
                      label: 'บันทึกการลงทุน',
                      selected: currentRoute == '/trade-tracker',
                      onTap: () => _navigate(context, '/trade-tracker'),
                      selectedColor: selectedColor,
                      unselectedColor: drawerItemSecondaryColor,
                      selectedTileColor: selectedTileColor,
                      isDarkMode: isDarkMode,
                    ),
                    _DrawerSectionLabel(
                      label: 'จัดการ',
                      color: drawerItemSecondaryColor,
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
        if (context.mounted) {
          Router.neglect(context, () => context.go(route));
        }
      });
    }
  }
}

class _DrawerSectionLabel extends StatelessWidget {
  final String label;
  final Color color;

  const _DrawerSectionLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
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
    final reinstallReminder = context.watch<ReinstallReminderService>();
    final showReinstallBadge =
        icon == Icons.settings_outlined && reinstallReminder.needsExpiredBadge;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final iconBackground = selected
        ? selectedColor.withValues(alpha: 0.18)
        : (isDarkMode ? AppColors.darkSurface : AppColors.surface);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(AppRadii.large),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(icon, color: selected ? selectedColor : unselectedColor),
              if (showReinstallBadge)
                Positioned(
                  right: 2,
                  top: 2,
                  child: Container(
                    width: 14,
                    height: 14,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.expense,
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      '!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        title: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
        trailing: selected
            ? null
            : Icon(Icons.chevron_right, size: 18, color: unselectedColor),
        selected: selected,
        selectedTileColor: selectedTileColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xLarge),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        mouseCursor: SystemMouseCursors.click,
        visualDensity: VisualDensity.comfortable,
        minLeadingWidth: 42,
        onTap: onTap,
      ),
    );
  }
}
