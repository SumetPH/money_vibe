import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';

class SidebarItemData {
  final IconData icon;
  final String label;
  final String route;

  const SidebarItemData({
    required this.icon,
    required this.label,
    required this.route,
  });
}

class AppSidebar extends StatelessWidget {
  final String currentRoute;
  final ValueChanged<String>? onNavigate;

  const AppSidebar({super.key, required this.currentRoute, this.onNavigate});

  static const List<SidebarItemData> _items = [
    SidebarItemData(
      icon: Icons.account_balance_wallet,
      label: 'บัญชี',
      route: '/accounts',
    ),
    SidebarItemData(
      icon: Icons.receipt_long,
      label: 'รายการ',
      route: '/transactions',
    ),
    SidebarItemData(
      icon: Icons.account_balance_outlined,
      label: 'งบประมาณ',
      route: '/budgets',
    ),
    SidebarItemData(
      icon: Icons.repeat,
      label: 'รายการประจำ',
      route: '/recurring',
    ),
    SidebarItemData(
      icon: Icons.category_outlined,
      label: 'หมวดหมู่',
      route: '/categories',
    ),
    SidebarItemData(
      icon: Icons.pie_chart_outline,
      label: 'สถิติ',
      route: '/statistics',
    ),
    SidebarItemData(
      icon: Icons.show_chart,
      label: 'บันทึกการเทรด',
      route: '/trade-tracker',
    ),
    SidebarItemData(
      icon: Icons.settings_outlined,
      label: 'การตั้งค่า',
      route: '/settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final isDarkMode = settingsProvider.isDarkMode;

    final sidebarBgColor = isDarkMode
        ? AppColors.darkSurface
        : AppColors.surface;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;
    final headerTextColor = isDarkMode ? Colors.white : AppColors.textPrimary;

    return Material(
      color: sidebarBgColor,
      child: Container(
        width: 260,
        height: double.infinity,
        decoration: BoxDecoration(
          color: sidebarBgColor,
          border: Border(right: BorderSide(color: dividerColor, width: 1)),
        ),
        child: Column(
          children: [
            // Sidebar Header
            SafeArea(
              bottom: false,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: Row(
                  children: [
                    // Logo container with custom gradient
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Color(0xFF2C333A),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet,
                        color: Color(0xFFE3E3E3),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Money Vibe',
                            style: TextStyle(
                              color: headerTextColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'การเงินส่วนบุคคล',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Divider(color: dividerColor, height: 1),
            const SizedBox(height: 16),
            // Sidebar Navigation List
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  // Check if currentRoute matches item.route as a prefix (handling subroutes)
                  final isSelected =
                      currentRoute == item.route ||
                      (item.route != '/' &&
                          currentRoute.startsWith(item.route));

                  return _SidebarItemTile(
                    item: item,
                    isSelected: isSelected,
                    isDarkMode: isDarkMode,
                    onTap: () {
                      if (currentRoute != item.route) {
                        if (onNavigate != null) {
                          onNavigate!(item.route);
                        } else {
                          Router.neglect(context, () => context.go(item.route));
                        }
                      }
                    },
                  );
                },
              ),
            ),
            // Sidebar Footer
            _SidebarFooter(isDarkMode: isDarkMode, onNavigate: onNavigate),
          ],
        ),
      ),
    );
  }
}

class _SidebarItemTile extends StatelessWidget {
  final SidebarItemData item;
  final bool isSelected;
  final bool isDarkMode;
  final VoidCallback onTap;

  const _SidebarItemTile({
    required this.item,
    required this.isSelected,
    required this.isDarkMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selectedColor = isDarkMode ? AppColors.darkIncome : AppColors.header;
    final selectedTileColor =
        (isDarkMode ? AppColors.darkHeader : AppColors.background).withValues(
          alpha: 0.8,
        );
    final unselectedColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final hoverColor = (isDarkMode ? Colors.white : Colors.black).withValues(
      alpha: 0.04,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: isSelected ? selectedTileColor : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          hoverColor: hoverColor,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  color: isSelected ? selectedColor : unselectedColor,
                  size: 22,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: isSelected
                          ? (isDarkMode ? Colors.white : AppColors.textPrimary)
                          : (isDarkMode
                                ? AppColors.darkTextPrimary
                                : AppColors.textPrimary),
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarFooter extends StatelessWidget {
  final bool isDarkMode;
  final ValueChanged<String>? onNavigate;

  const _SidebarFooter({required this.isDarkMode, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    if (!authProvider.isLoggedIn) return const SizedBox.shrink();

    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final secondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;
    final email = authProvider.userEmail ?? 'ผู้ใช้';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: dividerColor, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    email.split('@').first,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    email,
                    style: TextStyle(color: secondaryColor, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
