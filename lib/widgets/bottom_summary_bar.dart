import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class BottomSummaryBar extends StatelessWidget {
  final BottomSummaryValue left;
  final BottomSummaryValue right;
  final VoidCallback onAdd;
  final bool isDarkMode;
  final Color? addIconColor;

  const BottomSummaryBar({
    super.key,
    required this.left,
    required this.right,
    required this.onAdd,
    required this.isDarkMode,
    this.addIconColor,
  });

  @override
  Widget build(BuildContext context) {
    final headerColor = isDarkMode ? AppColors.darkHeader : AppColors.header;
    final fabColor = isDarkMode ? AppColors.darkFabYellow : AppColors.fabYellow;

    return Container(
      color: headerColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(child: _BottomSummaryText(value: left)),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: fabColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add,
                  color: addIconColor ?? Colors.white,
                  size: 28,
                ),
              ),
            ),
            Expanded(child: _BottomSummaryText(value: right, isTrailing: true)),
          ],
        ),
      ),
    );
  }
}

class BottomSummaryValue {
  final String label;
  final String value;
  final Color color;

  const BottomSummaryValue({
    required this.label,
    required this.value,
    required this.color,
  });
}

class _BottomSummaryText extends StatelessWidget {
  final BottomSummaryValue value;
  final bool isTrailing;

  const _BottomSummaryText({required this.value, this.isTrailing = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isTrailing
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          value.label,
          style: TextStyle(fontSize: 13, color: AppColors.darkTextPrimary),
        ),
        Text(
          value.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: value.color,
          ),
        ),
      ],
    );
  }
}
