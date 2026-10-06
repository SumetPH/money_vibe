import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';

/// คู่ label/ค่าตัวเลขขนาดเล็กใน metric grid (label 11sp w600, ค่า 13sp w700)
class AppMetricText extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  /// ค่าเริ่มต้นคือ `AppColors.textSecondaryFor`
  final Color? labelColor;
  final bool alignEnd;

  const AppMetricText({
    super.key,
    required this.label,
    required this.value,
    required this.valueColor,
    this.labelColor,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.select<SettingsProvider, bool>(
      (s) => s.isDarkMode,
    );

    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: labelColor ?? AppColors.textSecondaryFor(isDarkMode),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
