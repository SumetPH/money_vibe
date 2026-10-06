import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';

// ── Supporting widgets ────────────────────────────────────────────────────────

class RecurringDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color textPrimary;
  final Color textSecondary;

  const RecurringDetailRow({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: iconColor),
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
      ],
    );
  }
}

class RecurringDetailTypeBadge extends StatelessWidget {
  final String label;
  final Color color;

  const RecurringDetailTypeBadge({
    super.key,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class RecurringDetailEmptyState extends StatelessWidget {
  final String message;
  final bool isDark;

  const RecurringDetailEmptyState({
    super.key,
    required this.message,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_note_outlined,
            size: 64,
            color: textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(fontSize: 16, color: textSecondary)),
        ],
      ),
    );
  }
}
