import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';

/// The app's only toggle: a [CupertinoSwitch] in the theme accent color.
class AppSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const AppSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isDarkMode = settings.isDarkMode;

    return CupertinoSwitch(
      value: value,
      onChanged: onChanged,
      activeTrackColor: AppColors.accentFor(isDarkMode, settings.themeColor),
      inactiveTrackColor: AppColors.switchInactiveFor(isDarkMode),
    );
  }
}
