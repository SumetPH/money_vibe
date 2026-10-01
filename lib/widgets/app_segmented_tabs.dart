import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

/// หนึ่งช่องของ [AppSegmentedTabs]
class AppSegment {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const AppSegment({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
}

/// แถบเลือกประเภทบนการ์ด (เช่น รายจ่าย/รายรับ/โอน ในฟอร์มรายการประจำ)
class AppSegmentedTabs extends StatelessWidget {
  final List<AppSegment> segments;

  const AppSegmentedTabs({super.key, required this.segments});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.select<SettingsProvider, bool>(
      (s) => s.isDarkMode,
    );

    return Material(
      color: AppColors.surfaceFor(isDarkMode),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.xLarge),
        side: BorderSide(color: AppColors.borderFor(isDarkMode), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          spacing: 4,
          children: [
            for (final segment in segments)
              Expanded(child: _segment(segment, isDarkMode)),
          ],
        ),
      ),
    );
  }

  Widget _segment(AppSegment segment, bool isDarkMode) => Material(
    color: segment.isSelected
        ? AppColors.selectedSegmentFor(isDarkMode)
        : Colors.transparent,
    borderRadius: BorderRadius.circular(AppRadii.large),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: segment.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Text(
          segment.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: segment.isSelected
                ? AppColors.textPrimaryFor(isDarkMode)
                : AppColors.textSecondaryFor(isDarkMode),
            fontSize: 14,
            fontWeight: segment.isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    ),
  );
}
