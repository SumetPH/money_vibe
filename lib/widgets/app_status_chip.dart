import 'package:flutter/material.dart';

import '../theme/app_radii.dart';

/// แคปซูลสถานะพื้น tint ~12%
class AppStatusChip extends StatelessWidget {
  static const double _tintAlpha = 0.12;

  final String label;
  final Color color;

  const AppStatusChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: _tintAlpha),
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
