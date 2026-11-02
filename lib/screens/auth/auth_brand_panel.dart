import 'package:flutter/material.dart';

import '../../theme/app_brand.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';

/// แผงแบรนด์ฝั่งซ้ายของหน้า auth บน web จอกว้าง (layout 2 คอลัมน์)
///
/// ใช้พื้น surface แบบเดียวกับการ์ดในแอป และใช้สีธีมเป็น accent เฉพาะจุด
/// (โลโก้, ไอคอน feature) แทนการระบายพื้นทั้งแผง
class AuthBrandPanel extends StatelessWidget {
  static const _features = [
    (Icons.account_balance_wallet_outlined, 'รวมทุกบัญชีและหนี้สินไว้ที่เดียว'),
    (Icons.pie_chart_outline, 'ตั้งงบประมาณและติดตามรายจ่าย'),
    (Icons.trending_up, 'ดูพอร์ตลงทุนและกระแสเงินสดล่วงหน้า'),
  ];

  final bool isDarkMode;
  final Color accentColor;
  final Color fabColor;
  final Color onFabColor;

  const AuthBrandPanel({
    super.key,
    required this.isDarkMode,
    required this.accentColor,
    required this.fabColor,
    required this.onFabColor,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.textPrimaryFor(isDarkMode);
    final secondaryTextColor = AppColors.textSecondaryFor(isDarkMode);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(isDarkMode),
        border: Border(
          right: BorderSide(color: AppColors.borderFor(isDarkMode)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(56),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: fabColor,
                    borderRadius: BorderRadius.circular(AppRadii.large),
                  ),
                  child: Icon(AppBrand.logo, size: 24, color: onFabColor),
                ),
                const SizedBox(width: 12),
                Text(
                  'Money Vibe',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'จัดการเงินของคุณ\n'),
                  TextSpan(
                    text: 'ให้ชัดเจนในที่เดียว',
                    style: TextStyle(color: accentColor),
                  ),
                ],
              ),
              style: TextStyle(
                fontSize: 36,
                height: 1.3,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'บันทึกรายรับรายจ่าย วางแผนงบ และติดตามความมั่งคั่งได้ทุกอุปกรณ์',
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: secondaryTextColor,
              ),
            ),
            const SizedBox(height: 36),
            for (final (icon, label) in _features)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(AppRadii.medium),
                      ),
                      child: Icon(icon, size: 20, color: accentColor),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(fontSize: 15, color: textColor),
                      ),
                    ),
                  ],
                ),
              ),
            const Spacer(),
            Text(
              '© Money Vibe',
              style: TextStyle(fontSize: 13, color: secondaryTextColor),
            ),
          ],
        ),
      ),
    );
  }
}
