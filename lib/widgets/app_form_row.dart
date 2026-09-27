import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

/// แถวในการ์ดของฟอร์ม: ไอคอน 40px ทางซ้าย + ชื่อ
/// - มี [value]: แสดงค่าใต้ชื่อพร้อม chevron (แถวเลือกค่า)
/// - มี [trailing]: วาง control/ช่องกรอกชิดขวาในแถวเดียวกัน
class AppFormRow extends StatelessWidget {
  static const double _iconBoxSize = 40;
  static const double _iconTintAlpha = 0.12;

  final IconData icon;
  final String label;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  const AppFormRow({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.select<SettingsProvider, bool>(
      (s) => s.isDarkMode,
    );
    final textPrimary = AppColors.textPrimaryFor(isDarkMode);
    final textSecondary = AppColors.textSecondaryFor(isDarkMode);
    final labelText = Text(
      label,
      style: TextStyle(
        fontSize: 15,
        color: textPrimary,
        fontWeight: FontWeight.w600,
      ),
    );

    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: _iconBoxSize,
            height: _iconBoxSize,
            decoration: BoxDecoration(
              color: textSecondary.withValues(alpha: _iconTintAlpha),
              borderRadius: BorderRadius.circular(AppRadii.large),
            ),
            child: Icon(icon, color: textSecondary, size: 20),
          ),
          const SizedBox(width: 14),
          if (trailing != null) ...[
            labelText,
            const SizedBox(width: 12),
            Expanded(
              child: Align(alignment: Alignment.centerRight, child: trailing),
            ),
          ] else
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  labelText,
                  if (value != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      value!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          if (onTap != null && trailing == null) ...[
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: textSecondary, size: 20),
          ],
        ],
      ),
    );

    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}
