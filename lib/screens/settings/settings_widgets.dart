import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/theme_color_option.dart';
import '../../widgets/app_switch.dart';

class SettingsThemeColorSwatch extends StatelessWidget {
  final ThemeColorOption option;
  final bool isDarkMode;
  final bool selected;

  const SettingsThemeColorSwatch({
    super.key,
    required this.option,
    required this.isDarkMode,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final header = AppColors.headerFor(isDarkMode, option);
    final accent = AppColors.accentFor(isDarkMode, option);
    final fab = AppColors.fabFor(isDarkMode, option);

    return Container(
      width: 44,
      height: 28,
      padding: const EdgeInsets.all(3),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.darkSurfaceVariant : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected
              ? accent
              : (isDarkMode ? AppColors.darkDivider : AppColors.divider),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: header,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(4),
                ),
              ),
            ),
          ),
          Expanded(child: ColoredBox(color: accent)),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: fab,
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsGroup extends StatelessWidget {
  final bool isDarkMode;
  final Widget child;

  const SettingsGroup({
    super.key,
    required this.isDarkMode,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Theme(
        data: Theme.of(context).copyWith(
          splashFactory: NoSplash.splashFactory,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
        ),
        child: Material(
          color: surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.xLarge),
            side: BorderSide(color: dividerColor.withValues(alpha: 0.4)),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListTileTheme(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            minVerticalPadding: 10,
            child: child,
          ),
        ),
      ),
    );
  }
}

class SettingsIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const SettingsIcon({super.key, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.large),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class SettingsToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool isDarkMode;

  const SettingsToggleTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final textSecondary = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SettingsIcon(icon: icon, color: textSecondary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: textPrimary, fontSize: 16)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          AppSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
