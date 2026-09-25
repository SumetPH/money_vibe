import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

/// Leading close button for add/edit forms: an `x` on a circular surface.
class AppCloseButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String tooltip;

  const AppCloseButton({
    super.key,
    required this.onPressed,
    this.tooltip = 'ปิด',
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.select<SettingsProvider, bool>(
      (s) => s.isDarkMode,
    );

    return Center(
      child: Material(
        color: AppColors.surfaceFor(isDarkMode),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.full),
          side: BorderSide(color: AppColors.borderFor(isDarkMode)),
        ),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          icon: Icon(
            Icons.close,
            size: 20,
            color: AppColors.textPrimaryFor(isDarkMode),
          ),
          tooltip: tooltip,
          onPressed: onPressed,
        ),
      ),
    );
  }
}

/// Leading back button for secondary screens: a bare back arrow.
class AppBackButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const AppBackButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.select<SettingsProvider, bool>(
      (s) => s.isDarkMode,
    );

    return Center(
      child: IconButton(
        icon: Icon(
          Icons.arrow_back_rounded,
          color: AppColors.textPrimaryFor(isDarkMode),
        ),
        tooltip: 'ย้อนกลับ',
        onPressed: onPressed ?? () => Navigator.maybePop(context),
      ),
    );
  }
}

/// Primary save pill shown as the trailing AppBar action of a form.
class AppSaveButton extends StatelessWidget {
  static const double _spinnerSize = 16;

  final VoidCallback? onPressed;
  final bool isLoading;
  final String label;

  const AppSaveButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.label = 'บันทึก',
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.select<SettingsProvider, bool>(
      (s) => s.isDarkMode,
    );
    const foreground = Colors.black;

    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Center(
        child: Material(
          color: AppColors.saveButtonFor(isDarkMode),
          borderRadius: BorderRadius.circular(AppRadii.full),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: isLoading ? null : onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: isLoading
                  ? const SizedBox(
                      width: _spinnerSize,
                      height: _spinnerSize,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(foreground),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check, size: 16, color: foreground),
                        const SizedBox(width: 4),
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: foreground,
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
