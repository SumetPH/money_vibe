import 'package:flutter/material.dart';
import '../../models/budget.dart';
import '../../models/category.dart';
import '../../providers/budget_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../widgets/app_modal_bottom_sheet.dart';

void showBudgetCategoryPicker(
  BuildContext context,
  List<Category> categories,
  BudgetProvider budgetProvider,
  bool isDark, {
  required Set<String> selectedCategoryIds,
  required String? excludingBudgetId,
  required Future<bool> Function(
    BuildContext context, {
    required Category category,
    required Budget sourceBudget,
  })
  confirmCategoryTransfer,
  required bool Function() isMounted,
  required VoidCallback onChanged,
}) {
  final assignedBudgets = budgetProvider.expenseCategoryBudgetMap(
    excludingBudgetId: excludingBudgetId,
  );

  showAppModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => StatefulBuilder(
      builder: (context, setModalState) {
        final textColor = isDark
            ? AppColors.darkTextPrimary
            : AppColors.textPrimary;
        final textSecondary = isDark
            ? AppColors.darkTextSecondary
            : AppColors.textSecondary;
        final dividerColor = isDark ? AppColors.darkDivider : AppColors.divider;
        final selectedColor = isDark ? AppColors.darkIncome : AppColors.income;

        return AppDraggableSheet(
          builder: (_, sc) => Column(
            children: [
              const AppModalBottomSheetHeader(title: 'เลือกหมวดหมู่รายจ่าย'),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    Text(
                      'เลือกหมวดหมู่ที่ต้องการนับรวมในงบนี้',
                      style: TextStyle(fontSize: 13, color: textSecondary),
                    ),
                    const Spacer(),
                    Text(
                      'เลือกแล้ว ${selectedCategoryIds.length}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selectedColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: ListView.separated(
                  controller: sc,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: categories.length,
                  separatorBuilder: (context, i) => Divider(
                    height: 1,
                    color: AppColors.listDividerFor(isDark),
                  ),
                  itemBuilder: (_, i) {
                    final cat = categories[i];
                    final isSelected = selectedCategoryIds.contains(cat.id);
                    final assignedBudget = assignedBudgets[cat.id];

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      leading: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: cat.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadii.medium),
                        ),
                        child: Icon(cat.icon, color: cat.color, size: 20),
                      ),
                      title: Text(
                        cat.name,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: assignedBudget == null
                          ? null
                          : Text(
                              isSelected
                                  ? 'จะย้ายมาจากงบ: ${assignedBudget.name}'
                                  : 'ใช้อยู่ในงบ: ${assignedBudget.name}',
                              style: TextStyle(
                                color: isSelected
                                    ? (isDark
                                          ? AppColors.darkIncome
                                          : AppColors.income)
                                    : textSecondary,
                                fontSize: 12,
                              ),
                            ),
                      trailing: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? selectedColor
                              : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? selectedColor
                                : dividerColor.withValues(alpha: 0.8),
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      onTap: () async {
                        if (!isSelected && assignedBudget != null) {
                          final confirmed = await confirmCategoryTransfer(
                            context,
                            category: cat,
                            sourceBudget: assignedBudget,
                          );
                          if (!confirmed || !isMounted()) return;
                        }

                        setModalState(() {
                          if (isSelected) {
                            selectedCategoryIds.remove(cat.id);
                          } else {
                            selectedCategoryIds.add(cat.id);
                          }
                        });
                        onChanged();
                      },
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: isDark
                            ? AppColors.darkFabYellow
                            : AppColors.fabYellow,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.full),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'เสร็จสิ้น',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
