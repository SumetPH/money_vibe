import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

/// ระยะขั้นต่ำจากขอบล่างจอ (เครื่องที่ไม่มี home indicator)
const _minBottomGap = 8.0;

/// ยอมให้ capsule ลงไปในพื้นที่ home indicator กี่ px (ยิ่งมากยิ่งต่ำ)
const _safeAreaOverlap = 8.0;

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

    // ลอยเหนือขอบล่าง: ให้ capsule ลดลงไปทับ safe area (home indicator) ได้
    // บางส่วน แต่ไม่ต่ำกว่า _minBottomGap
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final bottomGap = math.max(_minBottomGap, bottomInset - _safeAreaOverlap);

    return SafeArea(
      top: false,
      bottom: false,
      minimum: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomGap),
        child: Container(
          decoration: BoxDecoration(
            color: surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(AppRadii.xLarge),
            border: Border.all(
              color: dividerColor.withValues(alpha: 0.4),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          // Frosted glass: เบลอเนื้อหาที่เลื่อนอยู่ใต้ capsule (ต้องใช้คู่กับ extendBody)
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Material(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.all(4),
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
                        height: 52,
                        child: Center(
                          child: Material(
                            color: fabColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadii.full,
                              ),
                              side: BorderSide(
                                color: AppColors.borderFor(isDarkMode),
                                width: 1,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: IconButton(
                              tooltip: 'เพิ่มรายการ',
                              onPressed: onAdd,
                              icon: Icon(
                                Icons.add_rounded,
                                color: onFab,
                                size: 26,
                              ),
                              constraints: const BoxConstraints.tightFor(
                                width: 46,
                                height: 46,
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
        height: 52,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
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
