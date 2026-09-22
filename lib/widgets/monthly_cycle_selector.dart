import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../theme/app_radii.dart';
import '../utils/monthly_cycle.dart';

class MonthlyCycleSelector extends StatelessWidget {
  final DateTime selectedMonth;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final Color surfaceColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color dividerColor;

  const MonthlyCycleSelector({
    super.key,
    required this.selectedMonth,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.surfaceColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.dividerColor,
  });

  String _periodLabel(BuildContext context) {
    const thaiMonths = [
      'ม.ค.',
      'ก.พ.',
      'มี.ค.',
      'เม.ย.',
      'พ.ค.',
      'มิ.ย.',
      'ก.ค.',
      'ส.ค.',
      'ก.ย.',
      'ต.ค.',
      'พ.ย.',
      'ธ.ค.',
    ];
    final period = monthlyCyclePeriod(
      selectedMonth,
      context.read<SettingsProvider>().monthlyCycleStartDay,
    );
    final end = period.endExclusive.subtract(const Duration(days: 1));
    final startYear = period.start.year == end.year
        ? ''
        : ' ${period.start.year}';
    return '${period.start.day} ${thaiMonths[period.start.month - 1]}$startYear - '
        '${end.day} ${thaiMonths[end.month - 1]} ${end.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppRadii.xLarge),
        border: Border.all(color: dividerColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          _ArrowButton(
            icon: Icons.chevron_left_rounded,
            color: textPrimary,
            onPressed: onPrevMonth,
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 13,
                  color: textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  _periodLabel(context),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
          ),
          _ArrowButton(
            icon: Icons.chevron_right_rounded,
            color: textPrimary,
            onPressed: onNextMonth,
          ),
        ],
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _ArrowButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    shape: const CircleBorder(),
    clipBehavior: Clip.antiAlias,
    child: IconButton(
      icon: Icon(icon, size: 22),
      color: color,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    ),
  );
}
