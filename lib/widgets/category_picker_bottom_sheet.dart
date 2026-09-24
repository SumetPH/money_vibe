import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category.dart';
import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import 'app_modal_bottom_sheet.dart';

/// วิดเจ็ตเลือกหมวดหมู่แบบ Bottom Sheet (Deep Module)
/// จัดการดึงข้อมูลและแสดงผลหมวดหมู่ด้วยตัวเอง
/// ลดภาระความซับซ้อนของหน้าจอหลัก (TransactionFormScreen) ให้สั้นและเป็นระเบียบ
class CategoryPickerBottomSheet extends StatelessWidget {
  final String? selectedCategoryId;
  final List<Category> categories;

  const CategoryPickerBottomSheet({
    super.key,
    this.selectedCategoryId,
    required this.categories,
  });

  /// เมธอดสถิตสำหรับเรียกแสดง BottomSheet อย่างสะดวก (Leverage Interface)
  static Future<String?> show(
    BuildContext context, {
    String? selectedCategoryId,
    required List<Category> categories,
  }) {
    return showAppModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CategoryPickerBottomSheet(
        selectedCategoryId: selectedCategoryId,
        categories: categories,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.select<SettingsProvider, bool>(
      (s) => s.isDarkMode,
    );
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 1.0,
      minChildSize: 0.3,
      maxChildSize: 1.0,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          const AppModalBottomSheetHeader(title: 'เลือกหมวดหมู่'),
          Expanded(
            child: ListView.separated(
              controller: scrollController,
              itemCount: categories.length,
              separatorBuilder: (context, i) => Divider(
                height: 1,
                color: AppColors.listDividerFor(isDarkMode),
              ),
              itemBuilder: (_, i) {
                final cat = categories[i];
                final isSelected = selectedCategoryId == cat.id;

                return ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: cat.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadii.medium),
                    ),
                    child: Icon(cat.icon, color: cat.color, size: 20),
                  ),
                  title: Text(
                    cat.name,
                    style: TextStyle(
                      fontSize: 16.0,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isDarkMode
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check, color: colorScheme.primary)
                      : null,
                  onTap: () => Navigator.pop(context, cat.id),
                );
              },
            ),
          ),
          const SafeArea(top: false, child: SizedBox()),
        ],
      ),
    );
  }
}
