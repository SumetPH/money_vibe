import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../../models/fixed_cash_flow_item.dart';
import '../../models/planned_purchase.dart';
import '../../providers/cash_flow_forecast_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_inset_card.dart';
import 'cash_flow_section.dart';
import 'fixed_cash_flow_item_form_screen.dart';
import 'planned_purchase_form_screen.dart';

/// ลิสต์จำลองเงินเข้าออกของงวด [period] พร้อมแถวเพิ่มรายการ
/// ([isReorderMode] แสดง handle สำหรับลากเรียงลำดับ)
List<Widget> cashFlowItemSections(
  List<FixedCashFlowItem> items,
  CashFlowPeriod period,
  bool isDarkMode, {
  bool isReorderMode = false,
}) => [
  ...cashFlowSection(
    title: 'เงินเข้าออก (ติ๊กเมื่อเกิดขึ้นแล้ว)',
    emptyText: '',
    rows: [
      if (items.isNotEmpty)
        _ReorderableRows(
          ids: [for (final item in items) item.id],
          isDarkMode: isDarkMode,
          onReorder: (context, oldIndex, newIndex) => context
              .read<CashFlowForecastProvider>()
              .reorderItems(period, oldIndex, newIndex),
          rowBuilder: (index) =>
              _itemRow(items[index], index, period, isDarkMode, isReorderMode),
        ),
      _AddRow(
        label: 'เพิ่มรายการเงินเข้าออก',
        isDarkMode: isDarkMode,
        onTap: (context) =>
            _push(context, FixedCashFlowItemFormScreen(initialPeriod: period)),
      ),
    ],
    isDarkMode: isDarkMode,
  ),
  cashFlowNote(
    'ลิสต์จำลองของ${period.label} เพิ่ม ลบ แก้ได้เอง และไม่เลื่อนตามเมื่อผ่านวันเคลียร์ยอด',
    isDarkMode,
  ),
];

/// ลิสต์อยากซื้อของงวด [period] พร้อมแถวเพิ่มรายการ
List<Widget> purchaseSections(
  List<PlannedPurchase> purchases,
  double purchaseTotal,
  CashFlowPeriod period,
  bool isDarkMode, {
  bool isReorderMode = false,
}) => [
  ...cashFlowSection(
    title:
        'อยากซื้อ · ${formatAmount(-purchaseTotal, showSign: true)} บาท (ติ๊กเพื่อนำมาคำนวณ)',
    emptyText: '',
    rows: [
      if (purchases.isNotEmpty)
        _ReorderableRows(
          ids: [for (final purchase in purchases) purchase.id],
          isDarkMode: isDarkMode,
          onReorder: (context, oldIndex, newIndex) => context
              .read<CashFlowForecastProvider>()
              .reorderPlannedPurchases(period, oldIndex, newIndex),
          rowBuilder: (index) => _purchaseRow(
            purchases[index],
            index,
            period,
            isDarkMode,
            isReorderMode,
          ),
        ),
      _AddRow(
        label: 'เพิ่มรายการอยากซื้อ',
        isDarkMode: isDarkMode,
        onTap: (context) =>
            _push(context, PlannedPurchaseFormScreen(initialPeriod: period)),
      ),
    ],
    isDarkMode: isDarkMode,
  ),
  cashFlowNote(
    'ไม่ติ๊กคือจดไว้เฉย ๆ ติ๊กเพื่อลองดูผลถ้าซื้อ${period.label} '
    'ซื้อจริงแล้วให้ลบหรือเอาติ๊กออก เพราะยอดในบัญชีหรือบัตรลดลงแล้ว',
    isDarkMode,
  ),
];

Widget _itemRow(
  FixedCashFlowItem item,
  int index,
  CashFlowPeriod period,
  bool isDarkMode,
  bool isReorderMode,
) => _TickRow(
  name: item.name,
  signedAmount: item.signedAmount,
  isChecked: item.isDone,
  isCounted: !item.isDone,
  checkTooltip: 'ติ๊กว่าเกิดขึ้นแล้ว',
  reorderIndex: isReorderMode ? index : null,
  isDarkMode: isDarkMode,
  onToggle: (context) => context.read<CashFlowForecastProvider>().updateItem(
    item.copyWith(isDone: !item.isDone),
  ),
  onTap: (context) => _push(
    context,
    FixedCashFlowItemFormScreen(item: item, initialPeriod: period),
  ),
);

Widget _purchaseRow(
  PlannedPurchase purchase,
  int index,
  CashFlowPeriod period,
  bool isDarkMode,
  bool isReorderMode,
) => _TickRow(
  name: purchase.name,
  signedAmount: -purchase.amount,
  isChecked: purchase.isIncluded,
  isCounted: purchase.isIncluded,
  checkTooltip: 'นำมาคำนวณ',
  reorderIndex: isReorderMode ? index : null,
  isDarkMode: isDarkMode,
  onToggle: (context) =>
      context.read<CashFlowForecastProvider>().updatePlannedPurchase(
        purchase.copyWith(isIncluded: !purchase.isIncluded),
      ),
  onTap: (context) => _push(
    context,
    PlannedPurchaseFormScreen(purchase: purchase, initialPeriod: period),
  ),
);

void _push(BuildContext context, Widget screen) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
}

/// แถวในการ์ดที่ลากเรียงลำดับได้ด้วย handle ท้ายแถว (ไม่ scroll เอง เพราะอยู่ใน ListView ของหน้า)
class _ReorderableRows extends StatelessWidget {
  final List<String> ids;
  final bool isDarkMode;
  final Future<void> Function(BuildContext context, int oldIndex, int newIndex)
  onReorder;
  final Widget Function(int index) rowBuilder;

  const _ReorderableRows({
    required this.ids,
    required this.isDarkMode,
    required this.onReorder,
    required this.rowBuilder,
  });

  Future<void> _reorder(
    BuildContext context,
    int oldIndex,
    int newIndex,
  ) async {
    try {
      await onReorder(context, oldIndex, newIndex);
    } catch (e) {
      debugPrint('CashFlowPeriodList: reorder error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('บันทึกลำดับไม่สำเร็จ')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => ReorderableListView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    padding: EdgeInsets.zero,
    buildDefaultDragHandles: false,
    itemCount: ids.length,
    onReorderItem: (oldIndex, newIndex) =>
        _reorder(context, oldIndex, newIndex),
    proxyDecorator: (child, index, animation) => Material(
      elevation: 6,
      color: AppColors.surfaceFor(isDarkMode),
      child: child,
    ),
    itemBuilder: (context, index) => Column(
      key: ValueKey(ids[index]),
      mainAxisSize: MainAxisSize.min,
      children: [if (index > 0) const AppCardDivider(), rowBuilder(index)],
    ),
  );
}

/// แถวที่ติ๊กได้ แถวที่ไม่นับในการคาดการณ์ ([isCounted] = false) แสดงเป็นสีจาง
/// และขีดฆ่าเมื่อเป็นเพราะติ๊กว่าเกิดขึ้นแล้ว
class _TickRow extends StatelessWidget {
  final String name;
  final double signedAmount;
  final bool isChecked;
  final bool isCounted;
  final String checkTooltip;

  /// ตำแหน่งสำหรับ handle ลาก; null เมื่อไม่ได้อยู่ในโหมดจัดเรียง
  final int? reorderIndex;
  final bool isDarkMode;
  final Future<void> Function(BuildContext context) onToggle;
  final void Function(BuildContext context) onTap;

  const _TickRow({
    required this.name,
    required this.signedAmount,
    required this.isChecked,
    required this.isCounted,
    required this.checkTooltip,
    this.reorderIndex,
    required this.isDarkMode,
    required this.onToggle,
    required this.onTap,
  });

  Future<void> _toggle(BuildContext context) async {
    try {
      await onToggle(context);
    } catch (e) {
      debugPrint('CashFlowPeriodList: toggle error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('บันทึกสถานะไม่สำเร็จ')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textSecondary = AppColors.textSecondaryFor(isDarkMode);
    final mutedColor = textSecondary.withValues(alpha: 0.6);
    final index = reorderIndex;
    final isReorderMode = index != null;
    final decoration = isChecked && !isCounted
        ? TextDecoration.lineThrough
        : null;
    return InkWell(
      // โหมดจัดเรียงปิดการแตะแก้ไขและติ๊ก เพื่อไม่ให้เปลี่ยนข้อมูลโดยไม่ตั้งใจ
      onTap: isReorderMode ? null : () => onTap(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 16, 6),
        child: Row(
          children: [
            IconButton(
              tooltip: isChecked ? 'ยกเลิกการติ๊ก' : checkTooltip,
              onPressed: isReorderMode ? null : () => _toggle(context),
              icon: Icon(
                isChecked
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isChecked ? AppColors.incomeFor(isDarkMode) : mutedColor,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isCounted
                      ? AppColors.textPrimaryFor(isDarkMode)
                      : textSecondary,
                  decoration: decoration,
                ),
              ),
            ),
            Text(
              formatAmount(signedAmount, showSign: true),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isCounted
                    ? AppColors.amountColor(
                        signedAmount,
                        isDarkMode: isDarkMode,
                      )
                    : mutedColor,
                decoration: decoration,
              ),
            ),
            if (index != null)
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    color: AppColors.borderFor(isDarkMode),
                    size: 20,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AddRow extends StatelessWidget {
  final String label;
  final bool isDarkMode;
  final void Function(BuildContext context) onTap;

  const _AddRow({
    required this.label,
    required this.isDarkMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => onTap(context),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(
            Icons.add_rounded,
            size: 20,
            color: AppColors.textSecondaryFor(isDarkMode),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimaryFor(isDarkMode),
            ),
          ),
        ],
      ),
    ),
  );
}
