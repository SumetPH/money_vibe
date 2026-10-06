import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import 'budget_menu_sheet.dart';

class BudgetEmptyState extends StatelessWidget {
  final Color surfaceColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color dividerColor;
  final bool isDarkMode;

  const BudgetEmptyState({
    super.key,
    required this.surfaceColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.dividerColor,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(AppRadii.xLarge),
            border: Border.all(color: dividerColor.withValues(alpha: 0.4)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color:
                      (isDarkMode
                              ? AppColors.darkFabYellow
                              : AppColors.fabYellow)
                          .withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.savings_outlined,
                  size: 32,
                  color: isDarkMode
                      ? AppColors.darkFabYellow
                      : AppColors.fabYellow,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'ยังไม่มีงบประมาณ',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'เริ่มต้นวางแผนการเงินและควบคุมรายจ่าย\nโดยสร้างงบประมาณแรกของคุณ',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: isDarkMode
                      ? AppColors.darkFabYellow
                      : AppColors.fabYellow,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.full),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 11,
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  'เพิ่มงบประมาณ',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                onPressed: () => openBudgetForm(context, null),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
