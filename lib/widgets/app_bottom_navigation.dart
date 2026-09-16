import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

class AppBottomNavigation extends StatelessWidget {
  final String currentRoute;
  final VoidCallback onAdd;
  final VoidCallback onOpenDrawer;

  const AppBottomNavigation({
    super.key,
    required this.currentRoute,
    required this.onAdd,
    required this.onOpenDrawer,
  });

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final isDarkMode = settingsProvider.isDarkMode;
    final accent = AppColors.accentFor(isDarkMode, settingsProvider.themeColor);
    final inactive = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final surface = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final fabColor = AppColors.fabFor(isDarkMode, settingsProvider.themeColor);
    final onFab = AppColors.onFabFor(isDarkMode, settingsProvider.themeColor);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: surface,
        borderRadius: BorderRadius.circular(AppRadii.sheet),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: _item(
                  icon: Icons.account_balance_wallet,
                  label: 'บัญชี',
                  selected: currentRoute == '/accounts',
                  accent: accent,
                  inactive: inactive,
                  onTap: () => _navigate(context, '/accounts'),
                ),
              ),
              Expanded(
                child: _item(
                  icon: Icons.donut_large_outlined,
                  label: 'แผน',
                  selected: currentRoute == '/budgets',
                  accent: accent,
                  inactive: inactive,
                  onTap: () => _navigate(context, '/budgets'),
                ),
              ),
              Expanded(
                child: SizedBox(
                  height: 64,
                  child: Center(
                    child: Material(
                      color: fabColor,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: IconButton(
                        tooltip: 'เพิ่มรายการ',
                        onPressed: onAdd,
                        icon: Icon(Icons.add, color: onFab, size: 32),
                        constraints: const BoxConstraints.tightFor(
                          width: 58,
                          height: 58,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _item(
                  icon: Icons.receipt_long_outlined,
                  label: 'รายการ',
                  selected: currentRoute == '/transactions',
                  accent: accent,
                  inactive: inactive,
                  onTap: () => _navigate(context, '/transactions'),
                ),
              ),
              Expanded(
                child: _item(
                  icon: Icons.menu,
                  label: 'เมนู',
                  selected: false,
                  accent: accent,
                  inactive: inactive,
                  onTap: onOpenDrawer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigate(BuildContext context, String route) {
    if (currentRoute == route) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      return;
    }
    if (Navigator.canPop(context)) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
    context.go(route);
  }

  Widget _item({
    required IconData icon,
    required String label,
    required bool selected,
    required Color accent,
    required Color inactive,
    required VoidCallback onTap,
  }) {
    final color = selected ? accent : inactive;
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 23),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
