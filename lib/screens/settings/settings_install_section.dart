import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'settings_widgets.dart';

/// หมวด "การติดตั้ง" สำหรับ build ที่ sideload บน iOS (provisioning มีอายุจำกัด)
class SettingsInstallSection extends StatelessWidget {
  final bool isDarkMode;
  final bool isExpired;
  final String remainingLabel;
  final bool isNotificationEnabled;
  final ValueChanged<bool> onNotificationChanged;

  const SettingsInstallSection({
    super.key,
    required this.isDarkMode,
    required this.isExpired,
    required this.remainingLabel,
    required this.isNotificationEnabled,
    required this.onNotificationChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.textPrimaryFor(isDarkMode);
    final secondaryTextColor = AppColors.textSecondaryFor(isDarkMode);

    return Column(
      children: [
        ListTile(
          leading: SettingsIcon(
            icon: isExpired ? Icons.error_outline : Icons.timer_outlined,
            color: isExpired
                ? AppColors.expenseFor(isDarkMode)
                : secondaryTextColor,
          ),
          title: Text('สถานะการติดตั้ง', style: TextStyle(color: textColor)),
          subtitle: Text(
            isExpired
                ? 'หมดอายุแล้ว กรุณาติดตั้งใหม่'
                : 'เหลือ $remainingLabel',
            style: TextStyle(color: secondaryTextColor),
          ),
        ),
        Divider(height: 1, color: AppColors.listDividerFor(isDarkMode)),
        SettingsToggleTile(
          icon: Icons.notifications_outlined,
          title: 'แจ้งเตือนติดตั้งใหม่',
          subtitle: isNotificationEnabled
              ? 'แจ้งเตือนเมื่อครบ 5 วัน'
              : 'ปิดการแจ้งเตือนแล้ว',
          isDarkMode: isDarkMode,
          value: isNotificationEnabled,
          onChanged: onNotificationChanged,
        ),
      ],
    );
  }
}
