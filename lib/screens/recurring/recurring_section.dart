import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';

class RecurringSection extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget> trailing;
  final bool inset;

  const RecurringSection({
    super.key,
    required this.title,
    required this.child,
    this.trailing = const [],
    this.inset = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<SettingsProvider>().isDarkMode;
    final surface = isDark ? AppColors.darkSurface : AppColors.surface;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final divider = isDark ? AppColors.darkDivider : AppColors.divider;

    return Padding(
      padding: inset
          ? const EdgeInsets.fromLTRB(16, 10, 16, 0)
          : const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                ...trailing,
              ],
            ),
          ),
          Material(
            color: surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.xLarge),
              side: BorderSide(color: divider.withValues(alpha: 0.4)),
            ),
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
        ],
      ),
    );
  }
}
