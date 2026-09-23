import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../services/reinstall_reminder_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

class AppDrawer extends StatelessWidget {
  final String currentRoute;
  final ValueChanged<String>? onSelectTab;

  const AppDrawer({super.key, required this.currentRoute, this.onSelectTab});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final isDarkMode = settingsProvider.isDarkMode;
    final themeColor = settingsProvider.themeColor;

    final drawerColor = isDarkMode
        ? AppColors.darkBackground
        : AppColors.background;
    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final textPrimary = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final textSecondary = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;
    final accent = AppColors.accentFor(isDarkMode, themeColor);

    final drawerWidth = (MediaQuery.sizeOf(context).width * 0.82).clamp(
      280.0,
      340.0,
    );

    return Drawer(
      width: drawerWidth,
      backgroundColor: drawerColor,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(
          right: Radius.circular(AppRadii.sheet),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // iOS-style Top App Header
          _buildHeader(
            context,
            isDarkMode: isDarkMode,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            dividerColor: dividerColor,
            accent: accent,
          ),

          // Menu Sections (iOS Inset Grouped)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 20),
              children: [
                _buildSectionTitle('หน้าหลัก', textSecondary),
                _buildGroupedCard(
                  surfaceColor: surfaceColor,
                  dividerColor: dividerColor,
                  children: [
                    _DrawerRowItem(
                      icon: Icons.account_balance_wallet_rounded,
                      label: 'บัญชี',
                      isSelected: currentRoute == '/accounts',
                      onTap: () => _navigate(context, '/accounts'),
                      accent: accent,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      isDarkMode: isDarkMode,
                    ),
                    _buildInnerDivider(isDarkMode),
                    _DrawerRowItem(
                      icon: Icons.donut_large_rounded,
                      label: 'งบประมาณ',
                      isSelected: currentRoute == '/budgets',
                      onTap: () => _navigate(context, '/budgets'),
                      accent: accent,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      isDarkMode: isDarkMode,
                    ),
                    _buildInnerDivider(isDarkMode),
                    _DrawerRowItem(
                      icon: Icons.receipt_long_rounded,
                      label: 'รายการ',
                      isSelected: currentRoute == '/transactions',
                      onTap: () => _navigate(context, '/transactions'),
                      accent: accent,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      isDarkMode: isDarkMode,
                    ),
                    _buildInnerDivider(isDarkMode),
                    _DrawerRowItem(
                      icon: Icons.query_stats_rounded,
                      label: 'สถิติ',
                      isSelected: currentRoute == '/statistics',
                      onTap: () => _navigate(context, '/statistics'),
                      accent: accent,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      isDarkMode: isDarkMode,
                    ),
                  ],
                ),

                _buildSectionTitle('วางแผน', textSecondary),
                _buildGroupedCard(
                  surfaceColor: surfaceColor,
                  dividerColor: dividerColor,
                  children: [
                    _DrawerRowItem(
                      icon: Icons.sync_alt_rounded,
                      label: 'รายการประจำ',
                      isSelected: currentRoute == '/recurring',
                      onTap: () => _navigate(context, '/recurring'),
                      accent: accent,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      isDarkMode: isDarkMode,
                    ),
                  ],
                ),

                _buildSectionTitle('ข้อมูลเชิงลึก', textSecondary),
                _buildGroupedCard(
                  surfaceColor: surfaceColor,
                  dividerColor: dividerColor,
                  children: [
                    _DrawerRowItem(
                      icon: Icons.trending_up_rounded,
                      label: 'บันทึกการลงทุน',
                      isSelected: currentRoute == '/trade-tracker',
                      onTap: () => _navigate(context, '/trade-tracker'),
                      accent: accent,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      isDarkMode: isDarkMode,
                    ),
                  ],
                ),

                _buildSectionTitle('จัดการ', textSecondary),
                _buildGroupedCard(
                  surfaceColor: surfaceColor,
                  dividerColor: dividerColor,
                  children: [
                    _DrawerRowItem(
                      icon: Icons.category_rounded,
                      label: 'หมวดหมู่',
                      isSelected: currentRoute == '/categories',
                      onTap: () => _navigate(context, '/categories'),
                      accent: accent,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      isDarkMode: isDarkMode,
                    ),
                    _buildInnerDivider(isDarkMode),
                    _DrawerRowItem(
                      icon: Icons.settings_rounded,
                      label: 'การตั้งค่า',
                      isSelected: currentRoute == '/settings',
                      onTap: () => _navigate(context, '/settings'),
                      accent: accent,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      isDarkMode: isDarkMode,
                      showBadge: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context, {
    required bool isDarkMode,
    required Color textPrimary,
    required Color textSecondary,
    required Color dividerColor,
    required Color accent,
  }) {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: dividerColor.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadii.large),
              ),
              child: Icon(
                Icons.account_balance_wallet_rounded,
                color: accent,
                size: 24,
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
                      color: textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'กระเป๋าของคุณ',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildGroupedCard({
    required Color surfaceColor,
    required Color dividerColor,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppRadii.xLarge),
        border: Border.all(
          color: dividerColor.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }

  Widget _buildInnerDivider(bool isDarkMode) {
    return Divider(
      height: 1,
      thickness: 1,
      endIndent: 0,
      color: AppColors.listDividerFor(isDarkMode),
    );
  }

  void _navigate(BuildContext context, String route) {
    Navigator.pop(context);
    if (onSelectTab != null &&
        (route == '/accounts' ||
            route == '/budgets' ||
            route == '/transactions' ||
            route == '/statistics')) {
      onSelectTab!(route);
      return;
    }
    if (currentRoute != route) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Router.neglect(context, () => context.go(route));
        }
      });
    }
  }
}

class _DrawerRowItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final bool isDarkMode;
  final bool showBadge;

  const _DrawerRowItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.isDarkMode,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final reinstallReminder = context.watch<ReinstallReminderService>();
    final hasWarningBadge = showBadge && reinstallReminder.needsExpiredBadge;
    final iconBgColor = isSelected
        ? accent.withValues(alpha: 0.18)
        : (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.05);

    final iconColor = isSelected ? accent : textPrimary;
    final rowTextColor = isSelected ? accent : textPrimary;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            // Icon container with squircle shape
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(AppRadii.medium),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                if (hasWarningBadge)
                  Positioned(
                    right: -3,
                    top: -3,
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
            const SizedBox(width: 14),

            // Item Label
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: rowTextColor,
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),

            // Trailing Chevron or Selected Indicator
            if (isSelected)
              Icon(Icons.check_rounded, size: 18, color: accent)
            else
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: textSecondary.withValues(alpha: 0.5),
              ),
          ],
        ),
      ),
    );
  }
}
