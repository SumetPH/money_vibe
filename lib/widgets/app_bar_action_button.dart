import 'package:flutter/material.dart';
import 'package:money_vibe/theme/app_radii.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';

class AppBarActionButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool isLoading;
  final bool disableWhenLoading;
  final Widget? loadingIcon;

  const AppBarActionButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.isLoading = false,
    this.disableWhenLoading = true,
    this.loadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<SettingsProvider>().isDarkMode;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: isDarkMode ? AppColors.darkSurface : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.full),
          side: BorderSide(color: AppColors.borderFor(isDarkMode), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          tooltip: tooltip,
          onPressed: isLoading && disableWhenLoading ? null : onPressed,
          icon: isLoading
              ? loadingIcon ??
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
              : icon,
        ),
      ),
    );
  }
}
