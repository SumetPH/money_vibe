import 'package:flutter/material.dart';

import '../../theme/app_brand.dart';
import '../../theme/app_radii.dart';

/// แผงแบรนด์ฝั่งซ้ายของหน้า auth บน web จอกว้าง (layout 2 คอลัมน์)
class AuthBrandPanel extends StatelessWidget {
  static const _features = [
    (Icons.account_balance_wallet_outlined, 'รวมทุกบัญชีและหนี้สินไว้ที่เดียว'),
    (Icons.pie_chart_outline, 'ตั้งงบประมาณและติดตามรายจ่าย'),
    (Icons.trending_up, 'ดูพอร์ตลงทุนและกระแสเงินสดล่วงหน้า'),
  ];

  static const _accentBlend = 0.25;

  final Color headerColor;
  final Color accentColor;
  final Color textColor;

  const AuthBrandPanel({
    super.key,
    required this.headerColor,
    required this.accentColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            headerColor,
            Color.lerp(headerColor, accentColor, _accentBlend) ?? headerColor,
          ],
        ),
      ),
      child: Stack(
        children: [
          // วงกลมโปร่งแสงตกแต่งพื้นหลัง
          Positioned(
            top: -120,
            right: -100,
            child: _Bubble(size: 360, color: textColor),
          ),
          Positioned(
            top: 160,
            right: 80,
            child: _Bubble(size: 90, color: textColor),
          ),
          Positioned(
            bottom: -140,
            left: -80,
            child: _Bubble(size: 300, color: textColor),
          ),
          Positioned.fill(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final mutedTextColor = textColor.withValues(alpha: 0.78);

    return Padding(
      padding: const EdgeInsets.all(56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: textColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadii.large),
                ),
                child: Icon(AppBrand.logo, size: 28, color: textColor),
              ),
              const SizedBox(width: 12),
              Text(
                'Money Vibe',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            'จัดการเงินของคุณ\nให้ชัดเจนในที่เดียว',
            style: TextStyle(
              fontSize: 40,
              height: 1.25,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'บันทึกรายรับรายจ่าย วางแผนงบ และติดตามความมั่งคั่งได้ทุกอุปกรณ์',
            style: TextStyle(fontSize: 16, height: 1.5, color: mutedTextColor),
          ),
          const SizedBox(height: 40),
          for (final (icon, label) in _features)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Icon(icon, size: 22, color: textColor),
                  const SizedBox(width: 12),
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
            style: TextStyle(fontSize: 13, color: mutedTextColor),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final double size;
  final Color color;

  const _Bubble({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.05),
      ),
    );
  }
}
