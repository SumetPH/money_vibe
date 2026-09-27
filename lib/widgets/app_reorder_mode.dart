import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

Color _reorderAccentFor(bool isDarkMode) =>
    isDarkMode ? AppColors.darkIncome : AppColors.income;

/// Trailing AppBar pill that exits reorder mode. Replaces the other header
/// actions while reorder mode is on.
class AppReorderDoneButton extends StatelessWidget {
  final VoidCallback onPressed;

  const AppReorderDoneButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.select<SettingsProvider, bool>(
      (s) => s.isDarkMode,
    );

    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Center(
        child: Material(
          color: _reorderAccentFor(isDarkMode),
          borderRadius: BorderRadius.circular(AppRadii.full),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_rounded, size: 16, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    'เสร็จสิ้น',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hint banner shown at the top of a list while reorder mode is on.
class AppReorderBanner extends StatelessWidget {
  final String message;

  const AppReorderBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.select<SettingsProvider, bool>(
      (s) => s.isDarkMode,
    );
    final accent = _reorderAccentFor(isDarkMode);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.large),
        border: Border.all(color: accent.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.swap_vert_rounded, color: accent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
