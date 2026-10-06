import 'dart:async';

import 'package:flutter/material.dart';
import 'package:money_vibe/providers/settings_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/account.dart';
import '../../models/investment_plan.dart';
import '../../models/stock_holding.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../widgets/app_inset_card.dart';
import '../../widgets/app_confirm_dialog.dart';
import 'investment_plan_widgets.dart';
import 'investment_plan_stock_selection_sheet.dart';
import 'investment_plan_recommendation_row.dart';
import '../../utils/user_error_message.dart';

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
            InvestmentPlanSection(
              title: 'DCA เดือนนี้',
              isDarkMode: widget.isDarkMode,
              child: buildInvestmentPlanDcaChecklist(
                dcaCompleted: widget.dcaCompleted,
                isDarkMode: widget.isDarkMode,
                onDcaChanged: _handleDcaChanged,
                textColor: textColor,
                secondaryColor: secondaryColor,
                dividerColor: dividerColor,
                activeColor: activeColor,
              ),
            ),
            InvestmentPlanSection(
              title: 'สัดส่วนเป้าหมาย',
              trailing: InvestmentPlanTargetTotalBadge(
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
            InvestmentPlanSection(
              title: 'บาลานซ์ปัจจุบัน',
              isDarkMode: widget.isDarkMode,
              child: buildInvestmentPlanRebalanceRows(
                account: widget.account,
                isDarkMode: widget.isDarkMode,
                analysis: analysis,
                textColor: textColor,
                secondaryColor: secondaryColor,
                dividerColor: dividerColor,
              ),
            ),
            InvestmentPlanSection(
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

  Future<void> _handleDcaChanged(bool completed) async {
    final confirmed = await _confirmDcaChange(completed);
    if (!mounted || confirmed != true) return;

    widget.onDcaChanged(completed);
  }

  Future<bool?> _confirmDcaChange(bool completed) {
    final monthLabel = formatInvestmentMonthLabel(currentInvestmentMonthKey());

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
            const AppCardDivider(),
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
      () => TextEditingController(
        text: formatInvestmentEditablePct(row.targetPercent),
      ),
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
          const AppCardDivider(),
          for (var i = 0; i < recommendedRows.length; i++) ...[
            if (i > 0) const AppCardDivider(),
            InvestmentPlanRecommendationRow(
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

  Future<void> _showStockSelectionSheet() {
    return showInvestmentPlanStockSelectionSheet(
      context,
      holdings: widget.holdings,
      isDarkMode: widget.isDarkMode,
      targetFor: _targetFor,
      saveTarget: _saveTarget,
      isMounted: () => mounted,
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
      final text = formatInvestmentEditablePct(target?.targetPercent ?? 0);
      final controller = _targetControllers[holding.id];
      if (controller == null) {
        _targetControllers[holding.id] = TextEditingController(text: text);
      } else if (!investmentTextEqualsNumber(
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userErrorMessage(e, action: 'บันทึกแผน'))),
      );
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
}
