import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

class AppBottomNavigation extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelectTab;
  final VoidCallback onAdd;

  const AppBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelectTab,
    required this.onAdd,
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
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;
    final fabColor = AppColors.fabFor(isDarkMode, settingsProvider.themeColor);
    final onFab = AppColors.onFabFor(isDarkMode, settingsProvider.themeColor);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(AppRadii.xLarge),
          border: Border.all(
            color: dividerColor.withValues(alpha: 0.35),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDarkMode ? 0.35 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
            child: Row(
              children: [
                Expanded(
                  child: _item(
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'บัญชี',
                    selected: selectedIndex == 0,
                    accent: accent,
                    inactive: inactive,
                    onTap: () => onSelectTab(0),
                  ),
                ),
                Expanded(
                  child: _item(
                    icon: Icons.donut_large_rounded,
                    label: 'แผน',
                    selected: selectedIndex == 1,
                    accent: accent,
                    inactive: inactive,
                    onTap: () => onSelectTab(1),
                  ),
                ),
                Expanded(
                  child: SizedBox(
                    height: 60,
                    child: Center(
                      child: Material(
                        color: fabColor,
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: IconButton(
                          tooltip: 'เพิ่มรายการ',
                          onPressed: onAdd,
                          icon: Icon(Icons.add_rounded, color: onFab, size: 30),
                          constraints: const BoxConstraints.tightFor(
                            width: 54,
                            height: 54,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _item(
                    icon: Icons.receipt_long_rounded,
                    label: 'รายการ',
                    selected: selectedIndex == 2,
                    accent: accent,
                    inactive: inactive,
                    onTap: () => onSelectTab(2),
                  ),
                ),
                Expanded(
                  child: _item(
                    icon: Icons.query_stats_rounded,
                    label: 'สถิติ',
                    selected: selectedIndex == 3,
                    accent: accent,
                    inactive: inactive,
                    onTap: () => onSelectTab(3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
      borderRadius: BorderRadius.circular(AppRadii.xLarge),
      child: SizedBox(
        height: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 23),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
