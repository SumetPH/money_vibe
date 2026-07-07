import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../main.dart';
import '../../models/account.dart';
import '../../models/investment_plan.dart';
import '../../models/stock_holding.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';

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
    final headerColor = widget.isDarkMode
        ? AppColors.darkSectionHeader
        : AppColors.sectionHeader;
    final enabledCount = analysis.rows.where((row) => row.isEnabled).length;

    if (widget.holdings.isEmpty) {
      return Container(
        color: backgroundColor,
        child: Center(
          child: Text(
            'ยังไม่มีหุ้นสำหรับวางแผน',
            style: TextStyle(color: secondaryColor),
          ),
        ),
      );
    }

    return Container(
      color: backgroundColor,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          _Section(
            title: 'DCA เดือนนี้',
            isDarkMode: widget.isDarkMode,
            child: _buildDcaChecklist(
              textColor: textColor,
              secondaryColor: secondaryColor,
              dividerColor: dividerColor,
            ),
          ),
          const SizedBox(height: 12),
          _Section(
            title: 'สัดส่วนเป้าหมาย',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TargetTotalBadge(
                  total: analysis.targetPercentTotal,
                  isBalanced: analysis.isTargetBalanced,
                  isDarkMode: widget.isDarkMode,
                ),
              ],
            ),
            isDarkMode: widget.isDarkMode,
            child: _buildTargetEditor(
              analysis: analysis,
              enabledCount: enabledCount,
              headerColor: headerColor,
              textColor: textColor,
              secondaryColor: secondaryColor,
              dividerColor: dividerColor,
            ),
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 12),
          _Section(
            title: 'ลองซื้อเพิ่ม',
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
    );
  }

  Widget _buildDcaChecklist({
    required Color textColor,
    required Color secondaryColor,
    required Color dividerColor,
  }) {
    final monthLabel = _formatMonthLabel(currentInvestmentMonthKey());
    return Column(
      children: [
        SwitchListTile(
          value: widget.dcaCompleted,
          onChanged: widget.onDcaChanged,
          title: Text(
            'DCA $monthLabel',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          subtitle: Text(
            widget.dcaCompleted
                ? 'ซื้อครบตามแผนแล้ว'
                : 'ยังไม่ได้ติ๊กว่าซื้อครบ',
            style: TextStyle(fontSize: 13, color: secondaryColor),
          ),
          secondary: Icon(
            widget.dcaCompleted
                ? Icons.check_circle
                : Icons.radio_button_unchecked,
            color: widget.dcaCompleted
                ? (widget.isDarkMode ? AppColors.darkIncome : AppColors.income)
                : secondaryColor,
          ),
        ),
        Divider(height: 1, color: dividerColor),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: secondaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'สถานะนี้เป็น checklist รายเดือนของพอร์ตนี้เท่านั้น',
                  style: TextStyle(fontSize: 12, color: secondaryColor),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTargetEditor({
    required AllocationAnalysis analysis,
    required int enabledCount,
    required Color headerColor,
    required Color textColor,
    required Color secondaryColor,
    required Color dividerColor,
  }) {
    final activeRows = analysis.rows.where((row) => row.isEnabled).toList();

    return Column(
      children: [
        if (activeRows.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  style: TextStyle(fontSize: 13, color: secondaryColor),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _showStockSelectionSheet,
                  icon: const Icon(Icons.tune),
                  label: const Text('เลือกหุ้นในแผน'),
                ),
              ],
            ),
          )
        else if (!analysis.isTargetBalanced)
          Container(
            color: headerColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.warning_amber, size: 18, color: _warningColor()),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'รวมเป้าหมายควรเป็น 100% ก่อนใช้เป็นแผนจริง',
                    style: TextStyle(
                      fontSize: 13,
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (activeRows.isNotEmpty)
          Container(
            color: headerColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.checklist, size: 16, color: secondaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'แสดง $enabledCount จาก ${widget.holdings.length} ตัว',
                    style: TextStyle(fontSize: 13, color: secondaryColor),
                  ),
                ),
                GestureDetector(
                  onTap: _showStockSelectionSheet,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text(
                      'แก้ไข',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        for (var i = 0; i < activeRows.length; i++) ...[
          if (i > 0 || !analysis.isTargetBalanced || activeRows.isNotEmpty)
            Divider(height: 1, color: dividerColor),
          _buildTargetRow(
            holding: _holdingForRow(activeRows[i]),
            row: activeRows[i],
            textColor: textColor,
            secondaryColor: secondaryColor,
          ),
        ],
      ],
    );
  }

  Widget _buildTargetRow({
    required StockHolding holding,
    required AllocationAnalysisRow row,
    required Color textColor,
    required Color secondaryColor,
  }) {
    final controller = _targetControllers.putIfAbsent(
      holding.id,
      () => TextEditingController(text: _formatEditablePct(row.targetPercent)),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
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
                Text(
                  'ตอนนี้ ${row.currentPercent.toStringAsFixed(2)}%',
                  style: TextStyle(fontSize: 12, color: secondaryColor),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 92,
            child: TextField(
              controller: controller,
              enabled: row.isEnabled,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 14, color: textColor),
              decoration: InputDecoration(
                isDense: true,
                suffixText: '%',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                ),
              ),
              onChanged: (_) =>
                  _scheduleTargetSave(holding, enabled: row.isEnabled),
              onSubmitted: (_) =>
                  _saveTargetNow(holding, enabled: row.isEnabled),
              onTapOutside: (_) => _dismissKeyboard(),
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
    final surfaceColor = widget.isDarkMode
        ? AppColors.darkSurface
        : AppColors.surface;
    final dividerColor = widget.isDarkMode
        ? AppColors.darkDivider
        : AppColors.divider;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.sheet),
        ),
      ),
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
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(top: 10, bottom: 12),
                      decoration: BoxDecoration(
                        color: dividerColor,
                        borderRadius: BorderRadius.circular(AppRadii.full),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 8, 12),
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
                          IconButton(
                            tooltip: 'ปิด',
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: dividerColor),
                    Expanded(
                      child: ListView.separated(
                        itemCount: widget.holdings.length,
                        separatorBuilder: (_, _) =>
                            Divider(height: 1, color: dividerColor),
                        itemBuilder: (context, index) {
                          final holding = widget.holdings[index];
                          final enabled = localEnabled[holding.id] ?? false;
                          final target = _targetFor(holding);

                          return SwitchListTile(
                            value: enabled,
                            onChanged: (value) async {
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
                            },
                            title: Text(
                              holding.ticker,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                            subtitle: Text(
                              target != null
                                  ? 'เป้า ${target.targetPercent.toStringAsFixed(2)}%'
                                  : 'ยังไม่ได้ตั้งเป้า',
                              style: TextStyle(
                                fontSize: 12,
                                color: secondaryColor,
                              ),
                            ),
                            secondary: Icon(
                              enabled
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: enabled
                                  ? (widget.isDarkMode
                                        ? AppColors.darkIncome
                                        : AppColors.income)
                                  : secondaryColor,
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
        padding: const EdgeInsets.all(16),
        child: Text(
          'เปิดหุ้นในแผนและใส่เปอร์เซ็นต์เป้าหมายเพื่อดูบาลานซ์',
          style: TextStyle(color: secondaryColor),
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) Divider(height: 1, color: dividerColor),
          _RebalanceRow(
            row: rows[i],
            currencyCode: widget.account.currencyCodeLabel,
            isDarkMode: widget.isDarkMode,
            textColor: textColor,
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: TextField(
            controller: _buyAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              labelText: 'ถ้าซื้อเพิ่ม',
              suffixText: widget.account.currencyCodeLabel,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.medium),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _buyAmount = double.tryParse(value.trim()) ?? 0;
              });
              _saveBuyAmount(value);
            },
            onTapOutside: (_) => _dismissKeyboard(),
          ),
        ),
        if (_buyAmount <= 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'กรอกจำนวนเงินเพื่อดูว่าควรเติมหุ้นตัวไหน',
                style: TextStyle(fontSize: 13, color: secondaryColor),
              ),
            ),
          )
        else if (recommendedRows.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'ยังไม่มีหุ้นที่ขาดจากเป้าหมายสำหรับจำนวนนี้',
                style: TextStyle(fontSize: 13, color: secondaryColor),
              ),
            ),
          )
        else ...[
          Divider(height: 1, color: dividerColor),
          for (var i = 0; i < recommendedRows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: dividerColor),
            _RecommendationRow(
              row: recommendedRows[i],
              plannedTotalAfterBuy:
                  analysis.totalCurrentValue + analysis.buyAmount,
              currencyCode: widget.account.currencyCodeLabel,
              textColor: textColor,
              secondaryColor: secondaryColor,
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
    final headerColor = isDarkMode
        ? AppColors.darkSectionHeader
        : AppColors.sectionHeader;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;

    return Container(
      color: surfaceColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: headerColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ),
                if (trailing case final Widget trailingWidget) trailingWidget,
              ],
            ),
          ),
          child,
        ],
      ),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isBalanced ? Icons.check_circle : Icons.warning_amber,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          '${total.toStringAsFixed(2)}%',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _RebalanceRow extends StatelessWidget {
  final AllocationAnalysisRow row;
  final String currencyCode;
  final bool isDarkMode;
  final Color textColor;

  const _RebalanceRow({
    required this.row,
    required this.currencyCode,
    required this.isDarkMode,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.full),
                  color: statusColor.withValues(alpha: 0.14),
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
          const SizedBox(height: 8),
          Wrap(
            runSpacing: 8,
            spacing: 12,
            children: [
              _Metric(
                label: 'เป้า',
                value: '${row.targetPercent.toStringAsFixed(2)}%',
              ),
              _Metric(
                label: 'ตอนนี้',
                value: '${row.currentPercent.toStringAsFixed(2)}%',
              ),
              _Metric(
                label: 'ต่าง',
                value:
                    '${row.diffPercent >= 0 ? '+' : ''}${row.diffPercent.toStringAsFixed(2)}%',
              ),
              _Metric(
                label: 'มูลค่าเป้า',
                value: '${formatAmount(row.targetValue)} $currencyCode',
              ),
              _Metric(
                label: 'มูลค่าตอนนี้',
                value: '${formatAmount(row.currentValue)} $currencyCode',
              ),
              _Metric(
                label: 'ขาด/เกิน',
                value:
                    '${row.diffAmount >= 0 ? '+' : ''}${formatAmount(row.diffAmount)} $currencyCode',
              ),
            ],
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
  final Color textColor;
  final Color secondaryColor;

  const _RecommendationRow({
    required this.row,
    required this.plannedTotalAfterBuy,
    required this.currencyCode,
    required this.textColor,
    required this.secondaryColor,
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
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
              Text(
                '${formatAmount(row.buyAmount)} $currencyCode',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'หลังซื้อประมาณ ${row.projectedPercent.toStringAsFixed(2)}%',
            style: TextStyle(fontSize: 12, color: secondaryColor),
          ),
          Text(
            'ขาดจากเป้า ${formatAmount(gapBeforeBuy)} $currencyCode',
            style: TextStyle(fontSize: 12, color: secondaryColor),
          ),
          Text(
            'หลังซื้อยังขาด ${formatAmount(gapAfterBuy)} $currencyCode',
            style: TextStyle(fontSize: 12, color: secondaryColor),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final secondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;

    return SizedBox(
      width: 146,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: secondaryColor)),
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
      ),
    );
  }
}
