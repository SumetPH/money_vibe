import 'dart:async';

import 'package:flutter/material.dart';
import 'package:money_vibe/providers/settings_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../main.dart';
import '../../models/account.dart';
import '../../models/investment_plan.dart';
import '../../models/stock_holding.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../widgets/app_modal_bottom_sheet.dart';
import '../../widgets/app_switch.dart';
import '../../widgets/app_confirm_dialog.dart';

class PortfolioInvestmentPlanScreen extends StatefulWidget {
  final Account account;
  final List<StockHolding> holdings;
  final List<PortfolioAllocationTarget> targets;
  final bool dcaCompleted;
  final ValueChanged<bool> onDcaChanged;
  final Future<void> Function({
    required StockHolding holding,
    required double targetPercent,
    required bool isEnabled,
  })
  onTargetChanged;
  final bool isDarkMode;

  const PortfolioInvestmentPlanScreen({
    super.key,
    required this.account,
    required this.holdings,
    required this.targets,
    required this.dcaCompleted,
    required this.onDcaChanged,
    required this.onTargetChanged,
    required this.isDarkMode,
  });

  @override
  State<PortfolioInvestmentPlanScreen> createState() =>
      _PortfolioInvestmentPlanScreenState();
}

class _PortfolioInvestmentPlanScreenState
    extends State<PortfolioInvestmentPlanScreen> {
  final TextEditingController _buyAmountController = TextEditingController();
  final Map<String, TextEditingController> _targetControllers = {};
  final Map<String, Timer> _targetSaveDebounceTimers = {};
  double _buyAmount = 0;

  @override
  void initState() {
    super.initState();
    _syncTargetControllers();
    _loadBuyAmount();
  }

  @override
  void didUpdateWidget(covariant PortfolioInvestmentPlanScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTargetControllers();
  }

  @override
  void dispose() {
    _buyAmountController.dispose();
    for (final timer in _targetSaveDebounceTimers.values) {
      timer.cancel();
    }
    for (final controller in _targetControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final analysis = buildAllocationAnalysis(
      holdings: widget.holdings,
      targets: widget.targets,
      buyAmount: _buyAmount,
    );
    final backgroundColor = widget.isDarkMode
        ? AppColors.darkBackground
        : AppColors.background;
    final textColor = widget.isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final secondaryColor = widget.isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final dividerColor = widget.isDarkMode
        ? AppColors.darkDivider
        : AppColors.divider;
    final enabledCount = analysis.rows.where((row) => row.isEnabled).length;
    final activeColor = AppColors.accentFor(
      widget.isDarkMode,
      context.read<SettingsProvider>().themeColor,
    );

    if (widget.holdings.isEmpty) {
      return Container(
        color: backgroundColor,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: widget.isDarkMode
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.04),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.pie_chart_outline_rounded,
                  size: 28,
                  color: secondaryColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'ยังไม่มีหุ้นสำหรับวางแผน',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: secondaryColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'เพิ่มหุ้นในพอร์ตก่อนเพื่อเริ่มตั้งสัดส่วนเป้าหมาย',
                style: TextStyle(
                  fontSize: 13,
                  color: secondaryColor.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 96),
        child: Column(
          children: [
            _Section(
              title: 'DCA เดือนนี้',
              isDarkMode: widget.isDarkMode,
              child: _buildDcaChecklist(
                textColor: textColor,
                secondaryColor: secondaryColor,
                dividerColor: dividerColor,
                activeColor: activeColor,
              ),
            ),
            _Section(
              title: 'สัดส่วนเป้าหมาย',
              trailing: _TargetTotalBadge(
                total: analysis.targetPercentTotal,
                isBalanced: analysis.isTargetBalanced,
                isDarkMode: widget.isDarkMode,
              ),
              isDarkMode: widget.isDarkMode,
              child: _buildTargetEditor(
                analysis: analysis,
                enabledCount: enabledCount,
                textColor: textColor,
                secondaryColor: secondaryColor,
                dividerColor: dividerColor,
              ),
            ),
            _Section(
              title: 'บาลานซ์ปัจจุบัน',
              isDarkMode: widget.isDarkMode,
              child: _buildRebalanceRows(
                analysis: analysis,
                textColor: textColor,
                secondaryColor: secondaryColor,
                dividerColor: dividerColor,
              ),
            ),
            _Section(
              title: 'จำลองซื้อเพิ่ม',
              isDarkMode: widget.isDarkMode,
              child: _buildBuyRecommendation(
                analysis: analysis,
                textColor: textColor,
                secondaryColor: secondaryColor,
                dividerColor: dividerColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDcaChecklist({
    required Color textColor,
    required Color secondaryColor,
    required Color dividerColor,
    required Color activeColor,
  }) {
    final monthLabel = _formatMonthLabel(currentInvestmentMonthKey());

    return Column(
      children: [
        InkWell(
          onTap: () => _handleDcaChanged(!widget.dcaCompleted),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: widget.dcaCompleted
                        ? activeColor.withValues(alpha: 0.15)
                        : (widget.isDarkMode
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.04)),
                    borderRadius: BorderRadius.circular(AppRadii.medium),
                  ),
                  child: Icon(
                    widget.dcaCompleted
                        ? Icons.check_circle_rounded
                        : Icons.calendar_month_rounded,
                    color: widget.dcaCompleted ? activeColor : secondaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DCA $monthLabel',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.dcaCompleted
                            ? 'ซื้อครบตามแผนแล้ว'
                            : 'ยังไม่ได้ติ๊กว่าซื้อครบ',
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.dcaCompleted
                              ? activeColor
                              : secondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                AppSwitch(
                  value: widget.dcaCompleted,
                  onChanged: _handleDcaChanged,
                ),
              ],
            ),
          ),
        ),
        Divider(
          height: 1,
          indent: 16,
          endIndent: 16,
          color: dividerColor.withValues(alpha: 0.4),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 15,
                color: secondaryColor.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'สถานะนี้เป็น checklist รายเดือนของพอร์ตนี้เท่านั้น',
                  style: TextStyle(
                    fontSize: 12,
                    color: secondaryColor.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleDcaChanged(bool completed) async {
    final confirmed = await _confirmDcaChange(completed);
    if (!mounted || confirmed != true) return;

    widget.onDcaChanged(completed);
  }

  Future<bool?> _confirmDcaChange(bool completed) {
    final monthLabel = _formatMonthLabel(currentInvestmentMonthKey());

    return showAppConfirmDialog(
      context: context,
      title: completed ? 'ยืนยัน DCA เดือนนี้' : 'ยกเลิกสถานะ DCA',
      message: completed
          ? 'ต้องการติ๊กว่า DCA $monthLabel ซื้อครบตามแผนแล้วใช่ไหม?'
          : 'ต้องการยกเลิกสถานะซื้อครบของ DCA $monthLabel ใช่ไหม?',
      confirmLabel: completed ? 'ยืนยัน' : 'ยกเลิกสถานะ',
      isDestructive: !completed,
    );
  }

  Widget _buildTargetEditor({
    required AllocationAnalysis analysis,
    required int enabledCount,
    required Color textColor,
    required Color secondaryColor,
    required Color dividerColor,
  }) {
    final activeRows = analysis.rows.where((row) => row.isEnabled).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (activeRows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: widget.isDarkMode
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.04),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    size: 22,
                    color: secondaryColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'ยังไม่ได้เลือกหุ้นในแผน',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'เลือกเฉพาะหุ้นที่อยากจัดสัดส่วน หน้านี้จะแสดงแค่ตัวที่เปิดไว้',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: secondaryColor),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _showStockSelectionSheet,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text(
                    'เลือกหุ้นในแผน',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.raisedFillFor(widget.isDarkMode),
                    foregroundColor: widget.isDarkMode
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.full),
                      side: BorderSide(
                        color: dividerColor.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        else ...[
          if (!analysis.isTargetBalanced)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _warningColor().withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadii.medium),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: _warningColor(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'รวมเป้าหมายควรเป็น 100% ก่อนใช้เป็นแผนจริง',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _warningColor(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Icon(Icons.checklist_rounded, size: 16, color: secondaryColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'แสดง $enabledCount จาก ${widget.holdings.length} ตัว',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: secondaryColor,
                    ),
                  ),
                ),
                InkWell(
                  onTap: _showStockSelectionSheet,
                  borderRadius: BorderRadius.circular(AppRadii.full),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: widget.isDarkMode
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(AppRadii.full),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          size: 13,
                          color: widget.isDarkMode
                              ? AppColors.darkIncome
                              : AppColors.income,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'แก้ไขหุ้น',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: widget.isDarkMode
                                ? AppColors.darkIncome
                                : AppColors.income,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < activeRows.length; i++) ...[
            Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: dividerColor.withValues(alpha: 0.3),
            ),
            _buildTargetRow(
              holding: _holdingForRow(activeRows[i]),
              row: activeRows[i],
              textColor: textColor,
              secondaryColor: secondaryColor,
              dividerColor: dividerColor,
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildTargetRow({
    required StockHolding holding,
    required AllocationAnalysisRow row,
    required Color textColor,
    required Color secondaryColor,
    required Color dividerColor,
  }) {
    final controller = _targetControllers.putIfAbsent(
      holding.id,
      () => TextEditingController(text: _formatEditablePct(row.targetPercent)),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: widget.isDarkMode
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(AppRadii.medium),
            ),
            alignment: Alignment.center,
            child: Text(
              holding.ticker.isNotEmpty ? holding.ticker[0].toUpperCase() : 'S',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  holding.ticker,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'ตอนนี้ ${row.currentPercent.toStringAsFixed(2)}%',
                  style: TextStyle(fontSize: 12, color: secondaryColor),
                ),
              ],
            ),
          ),
          Container(
            width: 88,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.insetFillFor(widget.isDarkMode),
              borderRadius: BorderRadius.circular(AppRadii.medium),
              border: Border.all(color: dividerColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: row.isEnabled,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 8,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      filled: false,
                    ),
                    onChanged: (_) =>
                        _scheduleTargetSave(holding, enabled: row.isEnabled),
                    onSubmitted: (_) =>
                        _saveTargetNow(holding, enabled: row.isEnabled),
                    onTapOutside: (_) => _dismissKeyboard(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8, left: 2),
                  child: Text(
                    '%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: secondaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showStockSelectionSheet() async {
    final localEnabled = {
      for (final holding in widget.holdings)
        holding.id: _targetFor(holding)?.isEnabled ?? false,
    };
    final textColor = widget.isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final secondaryColor = widget.isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final dividerColor = widget.isDarkMode
        ? AppColors.darkDivider
        : AppColors.divider;
    final accentColor = widget.isDarkMode
        ? AppColors.darkIncome
        : AppColors.income;

    await showAppModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final selectedCount = localEnabled.values
                .where((enabled) => enabled)
                .length;

            return SafeArea(
              child: FractionallySizedBox(
                heightFactor: 0.72,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 4, 12, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'เลือกหุ้นในแผน',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'เปิดอยู่ $selectedCount จาก ${widget.holdings.length} ตัว',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: secondaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () => Navigator.pop(sheetContext),
                            borderRadius: BorderRadius.circular(AppRadii.full),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: widget.isDarkMode
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.05),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: secondaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: dividerColor.withValues(alpha: 0.4),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: widget.holdings.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          color: AppColors.listDividerFor(widget.isDarkMode),
                        ),
                        itemBuilder: (context, index) {
                          final holding = widget.holdings[index];
                          final enabled = localEnabled[holding.id] ?? false;
                          final target = _targetFor(holding);

                          Future<void> toggle(bool value) async {
                            setSheetState(() {
                              localEnabled[holding.id] = value;
                            });
                            final saved = await _saveTarget(
                              holding,
                              enabled: value,
                            );
                            if (!saved && mounted) {
                              setSheetState(() {
                                localEnabled[holding.id] = !value;
                              });
                            }
                          }

                          return InkWell(
                            onTap: () => toggle(!enabled),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: enabled
                                          ? accentColor.withValues(alpha: 0.12)
                                          : (widget.isDarkMode
                                                ? Colors.white.withValues(
                                                    alpha: 0.05,
                                                  )
                                                : Colors.black.withValues(
                                                    alpha: 0.04,
                                                  )),
                                      borderRadius: BorderRadius.circular(
                                        AppRadii.medium,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      holding.ticker.isNotEmpty
                                          ? holding.ticker[0].toUpperCase()
                                          : 'S',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: enabled
                                            ? accentColor
                                            : textColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          holding.ticker,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: textColor,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          target != null
                                              ? 'เป้า ${target.targetPercent.toStringAsFixed(2)}%'
                                              : 'ยังไม่ได้ตั้งเป้า',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: secondaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  AppSwitch(value: enabled, onChanged: toggle),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRebalanceRows({
    required AllocationAnalysis analysis,
    required Color textColor,
    required Color secondaryColor,
    required Color dividerColor,
  }) {
    final rows = analysis.rows.where((row) => row.isEnabled).toList();
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Center(
          child: Text(
            'เปิดหุ้นในแผนและใส่เปอร์เซ็นต์เป้าหมายเพื่อดูบาลานซ์',
            textAlign: TextAlign.center,
            style: TextStyle(color: secondaryColor, fontSize: 13),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0)
            Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: dividerColor.withValues(alpha: 0.3),
            ),
          _RebalanceRow(
            row: rows[i],
            currencyCode: widget.account.currencyCodeLabel,
            isDarkMode: widget.isDarkMode,
            textColor: textColor,
            secondaryColor: secondaryColor,
            dividerColor: dividerColor,
          ),
        ],
      ],
    );
  }

  Widget _buildBuyRecommendation({
    required AllocationAnalysis analysis,
    required Color textColor,
    required Color secondaryColor,
    required Color dividerColor,
  }) {
    final recommendedRows = analysis.rows
        .where((row) => row.isEnabled && row.buyAmount > 0.005)
        .toList();

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.insetFillFor(widget.isDarkMode),
            borderRadius: BorderRadius.circular(AppRadii.large),
            border: Border.all(color: dividerColor.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.add_shopping_cart_rounded,
                size: 20,
                color: widget.isDarkMode
                    ? AppColors.darkIncome
                    : AppColors.income,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),
                    TextField(
                      controller: _buyAmountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                      decoration: InputDecoration(
                        hintText: '0.00',
                        hintStyle: TextStyle(
                          color: secondaryColor.withValues(alpha: 0.5),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 6,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        filled: false,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _buyAmount = double.tryParse(value.trim()) ?? 0;
                        });
                        _saveBuyAmount(value);
                      },
                      onTapOutside: (_) => _dismissKeyboard(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_buyAmount <= 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 15,
                  color: secondaryColor.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'กรอกจำนวนเงินเพื่อดูว่าควรเติมหุ้นตัวไหน',
                    style: TextStyle(
                      fontSize: 12,
                      color: secondaryColor.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (recommendedRows.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 15,
                  color: widget.isDarkMode
                      ? AppColors.darkIncome
                      : AppColors.income,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ยังไม่มีหุ้นที่ขาดจากเป้าหมายสำหรับจำนวนนี้',
                    style: TextStyle(fontSize: 12, color: secondaryColor),
                  ),
                ),
              ],
            ),
          )
        else ...[
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: dividerColor.withValues(alpha: 0.4),
          ),
          for (var i = 0; i < recommendedRows.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: dividerColor.withValues(alpha: 0.3),
              ),
            _RecommendationRow(
              row: recommendedRows[i],
              plannedTotalAfterBuy:
                  analysis.totalCurrentValue + analysis.buyAmount,
              currencyCode: widget.account.currencyCodeLabel,
              isDarkMode: widget.isDarkMode,
              textColor: textColor,
              secondaryColor: secondaryColor,
              dividerColor: dividerColor,
            ),
          ],
        ],
      ],
    );
  }

  void _syncTargetControllers() {
    final activeIds = widget.holdings.map((holding) => holding.id).toSet();
    final staleIds = _targetControllers.keys
        .where((id) => !activeIds.contains(id))
        .toList();
    for (final id in staleIds) {
      _targetControllers.remove(id)?.dispose();
      _targetSaveDebounceTimers.remove(id)?.cancel();
    }

    for (final holding in widget.holdings) {
      final target = _targetFor(holding);
      final text = _formatEditablePct(target?.targetPercent ?? 0);
      final controller = _targetControllers[holding.id];
      if (controller == null) {
        _targetControllers[holding.id] = TextEditingController(text: text);
      } else if (!_textEqualsNumber(
        controller.text,
        target?.targetPercent ?? 0,
      )) {
        controller.text = text;
      }
    }
  }

  PortfolioAllocationTarget? _targetFor(StockHolding holding) {
    final ticker = holding.ticker.trim().toUpperCase();
    for (final target in widget.targets) {
      if (target.ticker.trim().toUpperCase() == ticker) return target;
    }
    return null;
  }

  StockHolding _holdingForRow(AllocationAnalysisRow row) {
    return widget.holdings.firstWhere((holding) => holding.id == row.holdingId);
  }

  void _scheduleTargetSave(StockHolding holding, {required bool enabled}) {
    if (!enabled) return;
    _targetSaveDebounceTimers.remove(holding.id)?.cancel();
    _targetSaveDebounceTimers[holding.id] = Timer(
      const Duration(milliseconds: 650),
      () {
        _targetSaveDebounceTimers.remove(holding.id);
        _saveTarget(holding, enabled: enabled);
      },
    );
  }

  Future<bool> _saveTargetNow(StockHolding holding, {required bool enabled}) {
    _targetSaveDebounceTimers.remove(holding.id)?.cancel();
    return _saveTarget(holding, enabled: enabled);
  }

  Future<bool> _saveTarget(
    StockHolding holding, {
    required bool enabled,
  }) async {
    final controller = _targetControllers[holding.id];
    final value = double.tryParse(controller?.text.trim() ?? '') ?? 0;
    try {
      await widget.onTargetChanged(
        holding: holding,
        targetPercent: value,
        isEnabled: enabled,
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('บันทึกแผนไม่ได้: $e')));
      return false;
    }
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  String get _buyAmountStorageKey =>
      'portfolio_investment_plan_buy_amount_${widget.account.id}';

  Future<void> _loadBuyAmount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_buyAmountStorageKey);
      if (saved == null || saved.trim().isEmpty) return;
      final amount = double.tryParse(saved.trim()) ?? 0;
      if (!mounted) return;
      setState(() {
        _buyAmount = amount;
        _buyAmountController.text = saved;
      });
    } catch (_) {}
  }

  Future<void> _saveBuyAmount(String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        await prefs.remove(_buyAmountStorageKey);
      } else {
        await prefs.setString(_buyAmountStorageKey, trimmed);
      }
    } catch (_) {}
  }

  Color _warningColor() =>
      widget.isDarkMode ? AppColors.darkDebtRepay : AppColors.debtRepay;

  String _formatEditablePct(double value) {
    if (value == 0) return '';
    final fixed = value.toStringAsFixed(2);
    return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  bool _textEqualsNumber(String text, double value) {
    final parsed = double.tryParse(text.trim());
    if (parsed == null) return value == 0;
    return (parsed - value).abs() < 0.0001;
  }

  String _formatMonthLabel(String monthKey) {
    final parts = monthKey.split('-');
    if (parts.length != 2) return monthKey;
    const monthNames = [
      '',
      'มกราคม',
      'กุมภาพันธ์',
      'มีนาคม',
      'เมษายน',
      'พฤษภาคม',
      'มิถุนายน',
      'กรกฎาคม',
      'สิงหาคม',
      'กันยายน',
      'ตุลาคม',
      'พฤศจิกายน',
      'ธันวาคม',
    ];
    final month = int.tryParse(parts[1]) ?? 0;
    final year = parts[0];
    if (month < 1 || month > 12) return monthKey;
    return '${monthNames[month]} $year';
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  final bool isDarkMode;

  const _Section({
    required this.title,
    required this.child,
    required this.isDarkMode,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final secondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: secondaryColor,
                  ),
                ),
              ),
              if (trailing case final Widget trailingWidget) trailingWidget,
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(AppRadii.xLarge),
            border: Border.all(
              color: dividerColor.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      ],
    );
  }
}

class _TargetTotalBadge extends StatelessWidget {
  final double total;
  final bool isBalanced;
  final bool isDarkMode;

  const _TargetTotalBadge({
    required this.total,
    required this.isBalanced,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final color = isBalanced
        ? (isDarkMode ? AppColors.darkIncome : AppColors.income)
        : (isDarkMode ? AppColors.darkDebtRepay : AppColors.debtRepay);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isBalanced
                ? Icons.check_circle_rounded
                : Icons.warning_amber_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '${total.toStringAsFixed(2)}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _RebalanceRow extends StatelessWidget {
  final AllocationAnalysisRow row;
  final String currencyCode;
  final bool isDarkMode;
  final Color textColor;
  final Color secondaryColor;
  final Color dividerColor;

  const _RebalanceRow({
    required this.row,
    required this.currencyCode,
    required this.isDarkMode,
    required this.textColor,
    required this.secondaryColor,
    required this.dividerColor,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();
    final diffColor = row.diffPercent > 0
        ? (isDarkMode ? AppColors.darkDebtRepay : AppColors.debtRepay)
        : row.diffPercent < 0
        ? (isDarkMode ? AppColors.darkTransfer : AppColors.transfer)
        : (isDarkMode ? AppColors.darkIncome : AppColors.income);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                ),
                alignment: Alignment.center,
                child: Text(
                  row.ticker.isNotEmpty ? row.ticker[0].toUpperCase() : 'S',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  row.ticker,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.full),
                  color: statusColor.withValues(alpha: 0.12),
                ),
                child: Text(
                  row.statusLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(AppRadii.large),
              border: Border.all(color: dividerColor.withValues(alpha: 0.25)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        label: 'เป้าหมาย',
                        value: '${row.targetPercent.toStringAsFixed(2)}%',
                        textColor: textColor,
                        secondaryColor: secondaryColor,
                      ),
                    ),
                    Expanded(
                      child: _MetricTile(
                        label: 'ปัจจุบัน',
                        value: '${row.currentPercent.toStringAsFixed(2)}%',
                        textColor: textColor,
                        secondaryColor: secondaryColor,
                      ),
                    ),
                    Expanded(
                      child: _MetricTile(
                        label: 'ส่วนต่าง %',
                        value:
                            '${row.diffPercent >= 0 ? '+' : ''}${row.diffPercent.toStringAsFixed(2)}%',
                        textColor: diffColor,
                        secondaryColor: secondaryColor,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Divider(
                    height: 1,
                    color: dividerColor.withValues(alpha: 0.2),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        label: 'มูลค่าเป้า',
                        value: formatAmount(row.targetValue),
                        textColor: textColor,
                        secondaryColor: secondaryColor,
                      ),
                    ),
                    Expanded(
                      child: _MetricTile(
                        label: 'มูลค่าปัจจุบัน',
                        value: formatAmount(row.currentValue),
                        textColor: textColor,
                        secondaryColor: secondaryColor,
                      ),
                    ),
                    Expanded(
                      child: _MetricTile(
                        label: 'ขาด / เกิน',
                        value:
                            '${row.diffAmount >= 0 ? '+' : ''}${formatAmount(row.diffAmount)}',
                        textColor: diffColor,
                        secondaryColor: secondaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor() {
    if (row.isUnderweight) {
      return isDarkMode ? AppColors.darkTransfer : AppColors.transfer;
    }
    if (row.isOverweight) {
      return isDarkMode ? AppColors.darkDebtRepay : AppColors.debtRepay;
    }
    return isDarkMode ? AppColors.darkIncome : AppColors.income;
  }
}

class _RecommendationRow extends StatelessWidget {
  final AllocationAnalysisRow row;
  final double plannedTotalAfterBuy;
  final String currencyCode;
  final bool isDarkMode;
  final Color textColor;
  final Color secondaryColor;
  final Color dividerColor;

  const _RecommendationRow({
    required this.row,
    required this.plannedTotalAfterBuy,
    required this.currencyCode,
    required this.isDarkMode,
    required this.textColor,
    required this.secondaryColor,
    required this.dividerColor,
  });

  @override
  Widget build(BuildContext context) {
    final targetValueAfterBuy = plannedTotalAfterBuy * row.targetPercent / 100;
    final gapBeforeBuy = (targetValueAfterBuy - row.currentValue).clamp(
      0.0,
      double.infinity,
    );
    final gapAfterBuy = (gapBeforeBuy - row.buyAmount).clamp(
      0.0,
      double.infinity,
    );
    final incomeColor = isDarkMode ? AppColors.darkIncome : AppColors.income;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                ),
                alignment: Alignment.center,
                child: Text(
                  row.ticker.isNotEmpty ? row.ticker[0].toUpperCase() : 'S',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  row.ticker,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: incomeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadii.full),
                ),
                child: Text(
                  '+${formatAmount(row.buyAmount)} $currencyCode',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: incomeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(AppRadii.medium),
              border: Border.all(color: dividerColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'หลังซื้อประมาณ',
                        style: TextStyle(fontSize: 11, color: secondaryColor),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${row.projectedPercent.toStringAsFixed(2)}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ขาดจากเป้า',
                        style: TextStyle(fontSize: 11, color: secondaryColor),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatAmount(gapBeforeBuy),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'หลังซื้อยังขาด',
                        style: TextStyle(fontSize: 11, color: secondaryColor),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatAmount(gapAfterBuy),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: gapAfterBuy > 0 ? secondaryColor : incomeColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color textColor;
  final Color secondaryColor;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.textColor,
    required this.secondaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: secondaryColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ],
    );
  }
}
