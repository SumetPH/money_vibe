import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';

/// ปุ่มลบรายการท้ายฟอร์มแก้ไข (iOS Settings pattern)
class TransactionDeleteButton extends StatelessWidget {
  final bool isDarkMode;
  final VoidCallback? onPressed;

  const TransactionDeleteButton({
    super.key,
    required this.isDarkMode,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final expenseColor = AppColors.expenseFor(isDarkMode);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(isDarkMode),
        borderRadius: BorderRadius.circular(AppRadii.xLarge),
        border: Border.all(color: AppColors.borderFor(isDarkMode), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.xLarge),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.delete_outline_rounded, size: 20, color: expenseColor),
              const SizedBox(width: 8),
              Text(
                'ลบรายการนี้',
                style: TextStyle(
                  color: expenseColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
