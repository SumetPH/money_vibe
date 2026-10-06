import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../../models/category.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../widgets/app_inset_card.dart';
import '../../widgets/app_modal_bottom_sheet.dart';

class CategoryListItem extends StatelessWidget {
  final Category category;
  final String? parentCategoryName;
  final double total;
  final bool isReorderMode;
  final int? reorderIndex;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;
  final VoidCallback onTapEdit;
  final bool isDarkMode;

  const CategoryListItem({
    super.key,
    required this.category,
    this.parentCategoryName,
    required this.total,
    this.isReorderMode = false,
    this.reorderIndex,
    this.isFirst = false,
    this.isLast = false,
    required this.onTap,
    required this.onTapEdit,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final displayAmount = category.type == CategoryType.expense
        ? -total
        : total;

    final textPrimaryColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final textSecondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(AppRadii.xLarge),
          onTap: isReorderMode ? null : onTap,
          onLongPress: isReorderMode ? null : () => _showCategoryMenu(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(
              children: [
                // Drag handle (visible only in reorder mode)
                if (reorderIndex != null) ...[
                  ReorderableDragStartListener(
                    index: reorderIndex!,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        color: textSecondaryColor,
                        size: 22,
                      ),
                    ),
                  ),
                ],

                // Squircle Icon Container
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: category.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadii.medium),
                  ),
                  child: Icon(category.icon, color: category.color, size: 22),
                ),
                const SizedBox(width: 14),

                // Name and Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: textPrimaryColor,
                        ),
                      ),
                      if (parentCategoryName != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.subdirectory_arrow_right_rounded,
                              size: 12,
                              color: textSecondaryColor,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              parentCategoryName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: textSecondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ] else if (category.note != null &&
                          category.note!.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          category.note!.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: textSecondaryColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Total Amount display
                if (total > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${formatAmount(displayAmount)} ฿',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.getAmountColor(
                        displayAmount,
                        isDarkMode,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(height: 1, color: AppColors.listDividerFor(isDarkMode)),
      ],
    );
  }

  void _showCategoryMenu(BuildContext context) {
    showAppModalBottomSheet(
      context: context,
      builder: (_) => Consumer<SettingsProvider>(
        builder: (context, settingsProvider, _) {
          final isDark = settingsProvider.isDarkMode;
          final textColor = isDark
              ? AppColors.darkTextPrimary
              : AppColors.textPrimary;
          final textSecondary = isDark
              ? AppColors.darkTextSecondary
              : AppColors.textSecondary;
          final dividerColor = isDark
              ? AppColors.darkDivider
              : AppColors.divider;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppModalBottomSheetHeader(title: category.name),
                  const SizedBox(height: 8),
                  Material(
                    color: isDark
                        ? AppColors.darkSurfaceVariant
                        : AppColors.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.xLarge),
                      side: BorderSide(
                        color: dividerColor.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        ListTile(
                          leading: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: category.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(
                                AppRadii.medium,
                              ),
                            ),
                            child: Icon(
                              Icons.receipt_long_rounded,
                              color: category.color,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            'ดูรายการธุรกรรม',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            'แสดงรายการทั้งหมดที่บันทึกในหมวดหมู่นี้',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right_rounded,
                            color: textSecondary,
                            size: 20,
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            onTap();
                          },
                        ),
                        const AppCardDivider(),
                        ListTile(
                          leading: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color:
                                  (isDark
                                          ? AppColors.darkFabYellow
                                          : AppColors.fabYellow)
                                      .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(
                                AppRadii.medium,
                              ),
                            ),
                            child: Icon(
                              Icons.edit_outlined,
                              color: isDark
                                  ? AppColors.darkFabYellow
                                  : AppColors.fabYellow,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            'แก้ไขหมวดหมู่',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            'แก้ไขชื่อ ไอคอน สี หรือหมวดหมู่หลัก',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right_rounded,
                            color: textSecondary,
                            size: 20,
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            onTapEdit();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
