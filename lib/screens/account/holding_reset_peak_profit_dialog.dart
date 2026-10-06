import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';

/// ถามว่าจะรีเซ็ตกำไรสูงสุด (peak profit) หรือไม่ เมื่อฐานต้นทุนของหุ้นเปลี่ยน
Future<bool?> showResetPeakProfitDialog(BuildContext context) {
  final isDarkMode = context.read<SettingsProvider>().isDarkMode;
  final backgroundColor = isDarkMode
      ? AppColors.darkSurface
      : AppColors.surface;
  final textColor = isDarkMode
      ? AppColors.darkTextPrimary
      : AppColors.textPrimary;
  final primaryColor = isDarkMode ? AppColors.darkIncome : AppColors.income;

  return showDialog<bool>(
    context: context,
    // design-check: allow input or multi-choice dialog
    builder: (dialogContext) => AlertDialog(
      backgroundColor: backgroundColor,
      title: Text('รีเซ็ต Peak ไหม?', style: TextStyle(color: textColor)),
      content: Text(
        'จำนวนหุ้นหรือราคาทุนเปลี่ยนจากเดิม ต้องการเริ่มนับ Peak Profit ใหม่จากสถานะล่าสุดหรือคงค่าเดิมไว้?',
        style: TextStyle(color: textColor),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text('ยกเลิก', style: TextStyle(color: textColor)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text('คงค่าเดิม', style: TextStyle(color: textColor)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: TextButton.styleFrom(foregroundColor: primaryColor),
          child: const Text('รีเซ็ต'),
        ),
      ],
    ),
  );
}
