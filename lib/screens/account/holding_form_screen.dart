import 'package:flutter/cupertino.dart' show CupertinoSwitch;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/stock_holding.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';

TextInputFormatter _decimalInputFormatter(int maxDecimals) =>
    TextInputFormatter.withFunction((oldValue, newValue) {
      final text = newValue.text;
      if (text.isEmpty) return newValue;

      final match = RegExp('^\\d+(\\.\\d{0,$maxDecimals})?\$').hasMatch(text);
      return match ? newValue : oldValue;
    });

final _twoDecimalInputFormatter = _decimalInputFormatter(2);
final _fourDecimalInputFormatter = _decimalInputFormatter(
  stockHoldingCostBasisDecimalPlaces,
);
final _sevenDecimalInputFormatter = _decimalInputFormatter(
  stockHoldingSharesDecimalPlaces,
);

class HoldingFormScreen extends StatefulWidget {
  final String portfolioId;
  final String currencyCode;
  final StockHolding? existing;
  final Future<void> Function(StockHolding holding) onSave;
  final Future<double?> Function(String ticker)? fetchCurrentPrice;
  final Future<void> Function()? onDelete;
  final String Function() generateId;

  const HoldingFormScreen({
    super.key,
    required this.portfolioId,
    required this.currencyCode,
    required this.existing,
    required this.onSave,
    required this.generateId,
    this.fetchCurrentPrice,
    this.onDelete,
  });

  @override
  State<HoldingFormScreen> createState() => _HoldingFormScreenState();
}

class _HoldingFormScreenState extends State<HoldingFormScreen> {
  final _tickerController = TextEditingController();
  final _groupController = TextEditingController();
  final _sharesController = TextEditingController();
  final _priceController = TextEditingController();
  final _costController = TextEditingController();
  final _takeProfitController = TextEditingController();
  final _trailingStopController = TextEditingController();
  final _stopLossController = TextEditingController();
  final _peakProfitController = TextEditingController();
  final _sharesFocusNode = FocusNode();
  final _priceFocusNode = FocusNode();
  final _costFocusNode = FocusNode();
  final _takeProfitFocusNode = FocusNode();
  final _trailingStopFocusNode = FocusNode();
  final _stopLossFocusNode = FocusNode();
  final _peakProfitFocusNode = FocusNode();
  bool _isSaving = false;
  bool _sellPlanEnabled = false;
  bool _manualPeakProfitEnabled = false;
  String? _takeProfitError;
  String? _trailingStopError;
  String? _stopLossError;
  String? _peakProfitError;
  String? _sellPlanError;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final holding = widget.existing;
    if (holding != null) {
      _tickerController.text = holding.ticker;
      _groupController.text = holding.portfolioGroup;
      _sharesController.text = formatStockHoldingEditableNumber(
        holding.shares,
        scale: stockHoldingSharesDecimalPlaces,
      );
      _priceController.text = formatStockHoldingEditableNumber(
        holding.priceUsd,
        scale: stockHoldingPriceDecimalPlaces,
      );
      if (holding.costBasisUsd > 0) {
        _costController.text = formatStockHoldingEditableNumber(
          holding.costBasisUsd,
          scale: stockHoldingCostBasisDecimalPlaces,
        );
      }
      _sellPlanEnabled = holding.sellPlanEnabled;
      if (holding.sellPlanEnabled) {
        _takeProfitController.text = formatStockHoldingEditableNumber(
          holding.takeProfitPct,
          scale: 2,
        );
      }
      if (holding.trailingStopPct > 0) {
        _trailingStopController.text = formatStockHoldingEditableNumber(
          holding.trailingStopPct,
          scale: 2,
        );
      }
      if (holding.stopLossPct > 0) {
        _stopLossController.text = formatStockHoldingEditableNumber(
          holding.stopLossPct,
          scale: 2,
        );
      }
      if (holding.peakProfitPct != null) {
        _peakProfitController.text = _formatPct(holding.peakProfitPct!);
      }
    } else {
      _sellPlanEnabled = true;
      _takeProfitController.text = '10';
      _trailingStopController.text = '5';
      _stopLossController.text = '5';
    }
  }

  @override
  void dispose() {
    _sharesFocusNode.dispose();
    _priceFocusNode.dispose();
    _costFocusNode.dispose();
    _takeProfitFocusNode.dispose();
    _trailingStopFocusNode.dispose();
    _stopLossFocusNode.dispose();
    _peakProfitFocusNode.dispose();
    _tickerController.dispose();
    _groupController.dispose();
    _sharesController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _takeProfitController.dispose();
    _trailingStopController.dispose();
    _stopLossController.dispose();
    _peakProfitController.dispose();
    super.dispose();
  }

  String _formatPct(double value) => value.toStringAsFixed(2);

  double _roundPct(double value) => double.parse(value.toStringAsFixed(2));

  Future<void> _save() async {
    if (_isSaving) return;

    final ticker = _tickerController.text.trim().toUpperCase();
    if (ticker.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณากรอก Ticker')));
      return;
    }

    final group = _groupController.text.trim();
    final shares = double.tryParse(_sharesController.text.trim()) ?? 0;
    var price = double.tryParse(_priceController.text.trim()) ?? 0;
    final cost = double.tryParse(_costController.text.trim()) ?? 0;
    final takeProfit = double.tryParse(_takeProfitController.text.trim()) ?? 0;
    final trailingStop =
        double.tryParse(_trailingStopController.text.trim()) ?? 0;
    final stopLoss = double.tryParse(_stopLossController.text.trim()) ?? 0;
    final peakProfitText = _peakProfitController.text.trim();
    final manualPeakProfit = peakProfitText.isEmpty
        ? null
        : double.tryParse(peakProfitText);
    final effectiveManualPeakProfit = _manualPeakProfitEnabled
        ? manualPeakProfit
        : null;

    setState(() {
      _takeProfitError = null;
      _trailingStopError = null;
      _stopLossError = null;
      _peakProfitError = null;
      _sellPlanError = null;
    });

    if (_sellPlanEnabled) {
      var hasError = false;
      if (cost <= 0) {
        _sellPlanError = 'ต้องมีราคาทุนมากกว่า 0 เพื่อใช้แผนขาย';
        hasError = true;
      }
      if (takeProfit < 0) {
        _takeProfitError = 'Take Profit % ต้องไม่ติดลบ';
        hasError = true;
      }
      if (trailingStop <= 0) {
        _trailingStopError = 'กรุณากรอก Trailing Stop %';
        hasError = true;
      }
      if (stopLoss <= 0) {
        _stopLossError = 'กรุณากรอก Stop Loss %';
        hasError = true;
      }
      if (_manualPeakProfitEnabled && peakProfitText.isEmpty) {
        _peakProfitError = 'กรุณากรอกกำไรสูงสุด %';
        hasError = true;
      } else if (_manualPeakProfitEnabled && manualPeakProfit == null) {
        _peakProfitError = 'กรุณากรอกกำไรสูงสุด % ให้ถูกต้อง';
        hasError = true;
      } else if (effectiveManualPeakProfit != null &&
          effectiveManualPeakProfit < takeProfit) {
        _peakProfitError = 'กำไรสูงสุด % ต้องมากกว่าหรือเท่ากับ Take Profit %';
        hasError = true;
      }
      if (hasError) {
        setState(() {});
        return;
      }
    }

    final resetPeakProfit = await _confirmResetPeakProfitIfNeeded(
      shares: shares,
      costBasisUsd: cost,
      usesManualPeakProfit: effectiveManualPeakProfit != null,
    );
    if (resetPeakProfit == null) return;

    setState(() => _isSaving = true);
    try {
      final currentPrice = await _fetchCurrentPrice(ticker);
      if (currentPrice != null) {
        price = currentPrice;
        _priceController.text = formatStockHoldingEditableNumber(
          currentPrice,
          scale: stockHoldingPriceDecimalPlaces,
        );
      }

      final peakProfitPct = _resolvePeakProfitPct(
        shares: shares,
        priceUsd: price,
        costBasisUsd: cost,
        sellPlanEnabled: _sellPlanEnabled,
        takeProfitPct: takeProfit,
        manualPeakProfitPct: effectiveManualPeakProfit,
        resetPeakProfit: resetPeakProfit,
      );

      final holding = StockHolding(
        id: widget.existing?.id ?? widget.generateId(),
        portfolioId: widget.portfolioId,
        ticker: ticker,
        name: widget.existing?.name ?? '',
        shares: shares,
        priceUsd: price,
        costBasisUsd: cost,
        logoUrl: widget.existing?.logoUrl ?? '',
        sortOrder: widget.existing?.sortOrder ?? 0,
        sellPlanEnabled: _sellPlanEnabled,
        takeProfitPct: _sellPlanEnabled
            ? takeProfit
            : (widget.existing?.takeProfitPct ?? takeProfit),
        trailingStopPct: _sellPlanEnabled
            ? trailingStop
            : (widget.existing?.trailingStopPct ?? trailingStop),
        stopLossPct: _sellPlanEnabled
            ? stopLoss
            : (widget.existing?.stopLossPct ?? stopLoss),
        peakProfitPct: _sellPlanEnabled
            ? peakProfitPct
            : widget.existing?.peakProfitPct,
        portfolioGroup: group,
      );

      await widget.onSave(holding);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'เกิดข้อผิดพลาดในการบันทึก: $e',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<double?> _fetchCurrentPrice(String ticker) async {
    final fetchCurrentPrice = widget.fetchCurrentPrice;
    if (fetchCurrentPrice == null) return null;

    final price = await fetchCurrentPrice(ticker);
    if (price == null || price <= 0) return null;
    return price;
  }

  double _calculatePnlPct({
    required double shares,
    required double priceUsd,
    required double costBasisUsd,
  }) {
    final totalCostUsd = shares * costBasisUsd;
    if (totalCostUsd <= 0) return 0;
    final unrealizedPnlUsd = (shares * priceUsd) - totalCostUsd;
    return (unrealizedPnlUsd / totalCostUsd) * 100;
  }

  double? _resolvePeakProfitPct({
    required double shares,
    required double priceUsd,
    required double costBasisUsd,
    required bool sellPlanEnabled,
    required double takeProfitPct,
    required double? manualPeakProfitPct,
    required bool resetPeakProfit,
  }) {
    final existing = widget.existing;
    if (!sellPlanEnabled) {
      return existing?.peakProfitPct;
    }

    if (manualPeakProfitPct != null) {
      return _roundPct(manualPeakProfitPct);
    }

    final currentPnlPct = _calculatePnlPct(
      shares: shares,
      priceUsd: priceUsd,
      costBasisUsd: costBasisUsd,
    );

    if (existing == null) {
      return _shouldTrackPeakProfit(
            currentPnlPct: currentPnlPct,
            takeProfitPct: takeProfitPct,
          )
          ? _roundPct(currentPnlPct)
          : null;
    }

    // Buying more or selling part of a position changes the investment basis.
    // Let the edit flow decide whether to reset or carry the previous peak.
    final basisChanged = StockHolding(
      id: existing.id,
      portfolioId: existing.portfolioId,
      ticker: existing.ticker,
      name: existing.name,
      shares: shares,
      priceUsd: priceUsd,
      costBasisUsd: costBasisUsd,
      logoUrl: existing.logoUrl,
      sortOrder: existing.sortOrder,
      sellPlanEnabled: sellPlanEnabled,
      takeProfitPct: takeProfitPct,
      trailingStopPct: existing.trailingStopPct,
      stopLossPct: existing.stopLossPct,
      peakProfitPct: existing.peakProfitPct,
    ).hasInvestmentBasisChangedFrom(existing);
    if (basisChanged || !existing.sellPlanEnabled) {
      if (!resetPeakProfit && existing.sellPlanEnabled) {
        final previousPeak = existing.peakProfitPct;
        if (previousPeak == null) {
          return null;
        }
        if (currentPnlPct > previousPeak) {
          return _roundPct(currentPnlPct);
        }
        return _roundPct(previousPeak);
      }

      return _shouldTrackPeakProfit(
            currentPnlPct: currentPnlPct,
            takeProfitPct: takeProfitPct,
          )
          ? _roundPct(currentPnlPct)
          : null;
    }

    final previousPeak = existing.peakProfitPct;
    if (previousPeak == null &&
        !_shouldTrackPeakProfit(
          currentPnlPct: currentPnlPct,
          takeProfitPct: takeProfitPct,
        )) {
      return null;
    }
    if (previousPeak == null || currentPnlPct > previousPeak) {
      return _roundPct(currentPnlPct);
    }
    return _roundPct(previousPeak);
  }

  Future<bool?> _confirmResetPeakProfitIfNeeded({
    required double shares,
    required double costBasisUsd,
    required bool usesManualPeakProfit,
  }) async {
    final existing = widget.existing;
    if (existing == null ||
        !_sellPlanEnabled ||
        usesManualPeakProfit ||
        !existing.sellPlanEnabled) {
      return true;
    }

    final basisChanged = existing
        .copyWith(shares: shares, costBasisUsd: costBasisUsd)
        .hasInvestmentBasisChangedFrom(existing);
    if (!basisChanged) return true;

    final isDarkMode = context.read<SettingsProvider>().isDarkMode;
    final backgroundColor = isDarkMode
        ? AppColors.darkSurface
        : AppColors.surface;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final primaryColor = isDarkMode ? AppColors.darkIncome : AppColors.income;

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: backgroundColor,
        title: Text('รีเซ็ต Peak ไหม?', style: TextStyle(color: textColor)),
        content: Text(
          'จำนวนหุ้นหรือราคาทุนเปลี่ยนจากเดิม ต้องการเริ่มนับ Peak Profit ใหม่จากสถานะล่าสุดหรือคงค่าเดิมไว้?',
          style: TextStyle(color: textColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('ยกเลิก', style: TextStyle(color: textColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('คงค่าเดิม', style: TextStyle(color: textColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: primaryColor),
            child: const Text('รีเซ็ต'),
          ),
        ],
      ),
    );
  }

  bool _shouldTrackPeakProfit({
    required double currentPnlPct,
    required double takeProfitPct,
  }) {
    if (takeProfitPct <= 0) {
      return currentPnlPct > 0;
    }
    return currentPnlPct >= takeProfitPct;
  }

  Future<void> _delete() async {
    if (widget.onDelete == null) return;

    final isDarkMode = context.read<SettingsProvider>().isDarkMode;
    final backgroundColor = isDarkMode
        ? AppColors.darkSurface
        : AppColors.surface;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final expenseColor = isDarkMode ? AppColors.darkExpense : AppColors.expense;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: backgroundColor,
        title: Text('ยืนยันการลบหุ้น', style: TextStyle(color: textColor)),
        content: Text(
          'คุณต้องการลบ ${widget.existing!.ticker} ใช่หรือไม่?',
          style: TextStyle(color: textColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('ยกเลิก', style: TextStyle(color: textColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: expenseColor),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);
    try {
      await widget.onDelete!();
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการลบ: $e'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<SettingsProvider>().isDarkMode;
    final bgColor = isDarkMode
        ? AppColors.darkBackground
        : AppColors.background;
    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final secondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;
    final accentColor = isDarkMode ? AppColors.darkIncome : AppColors.income;
    final expenseColor = isDarkMode ? AppColors.darkExpense : AppColors.expense;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leadingWidth: 64,
        leading: Center(
          child: Material(
            color: surfaceColor,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: IconButton(
              icon: Icon(Icons.close, size: 20, color: textColor),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
              onPressed: _isSaving ? null : () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text(
          _isEditing ? 'แก้ไขหุ้น' : 'เพิ่มหุ้น',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        actions: [
          if (_isEditing && widget.onDelete != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Material(
                color: expenseColor.withValues(alpha: 0.12),
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: expenseColor,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 38,
                    minHeight: 38,
                  ),
                  onPressed: _isSaving ? null : _delete,
                  tooltip: 'ลบหุ้น',
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton(
              onPressed: _isSaving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: isDarkMode ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                shape: const StadiumBorder(),
                elevation: 0,
                minimumSize: const Size(64, 36),
              ),
              child: _isSaving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(
                          isDarkMode ? Colors.black : Colors.white,
                        ),
                      ),
                    )
                  : const Text(
                      'บันทึก',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _isSaving,
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: ListView(
            padding: const EdgeInsets.only(top: 4, bottom: 40),
            children: [
              _buildSectionHeader('ข้อมูลหุ้น', secondaryColor),
              _buildInsetCard(
                surfaceColor: surfaceColor,
                dividerColor: dividerColor,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 140,
                          child: Text(
                            'Ticker',
                            style: TextStyle(
                              fontSize: 15,
                              color: secondaryColor,
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _tickerController,
                            textCapitalization: TextCapitalization.characters,
                            textAlign: TextAlign.right,
                            autofocus: false,
                            decoration: InputDecoration(
                              hintText: 'เช่น AAPL',
                              hintStyle: TextStyle(
                                color: secondaryColor.withValues(alpha: 0.6),
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              focusedErrorBorder: InputBorder.none,
                              filled: false,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                            ),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildCardDivider(isDarkMode),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 140,
                          child: Text(
                            'กลุ่ม / พอร์ต',
                            style: TextStyle(
                              fontSize: 15,
                              color: secondaryColor,
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _groupController,
                            textAlign: TextAlign.right,
                            autofocus: false,
                            decoration: InputDecoration(
                              hintText: 'ทั่วไป',
                              hintStyle: TextStyle(
                                color: secondaryColor.withValues(alpha: 0.6),
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              focusedErrorBorder: InputBorder.none,
                              filled: false,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                            ),
                            style: TextStyle(fontSize: 15, color: textColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildCardDivider(isDarkMode),
                  _HoldingNumberFieldRow(
                    label: 'จำนวนหุ้น',
                    controller: _sharesController,
                    focusNode: _sharesFocusNode,
                    hintText: '0',
                    isDarkMode: isDarkMode,
                    inputFormatters: [_sevenDecimalInputFormatter],
                  ),
                  _buildCardDivider(isDarkMode),
                  _HoldingNumberFieldRow(
                    label: 'ราคาทุน (${widget.currencyCode})',
                    controller: _costController,
                    focusNode: _costFocusNode,
                    hintText: '0.00',
                    isDarkMode: isDarkMode,
                    inputFormatters: [_fourDecimalInputFormatter],
                  ),
                  _buildCardDivider(isDarkMode),
                  _HoldingNumberFieldRow(
                    label: 'ราคาปัจจุบัน (${widget.currencyCode})',
                    controller: _priceController,
                    focusNode: _priceFocusNode,
                    hintText: '0.00',
                    isDarkMode: isDarkMode,
                  ),
                ],
              ),
              _buildSectionHeader('แผนการขาย (SELL PLAN)', secondaryColor),
              _buildInsetCard(
                surfaceColor: surfaceColor,
                dividerColor: dividerColor,
                children: [
                  _HoldingSwitchRow(
                    title: 'เปิดแผนขาย',
                    subtitle:
                        'ตั้ง Take Profit %, Trailing Stop % และ Stop Loss %',
                    value: _sellPlanEnabled,
                    activeColor: accentColor,
                    isDarkMode: isDarkMode,
                    textColor: textColor,
                    secondaryColor: secondaryColor,
                    onChanged: (value) {
                      setState(() {
                        _sellPlanEnabled = value;
                        _takeProfitError = null;
                        _trailingStopError = null;
                        _stopLossError = null;
                        _peakProfitError = null;
                        _sellPlanError = null;
                      });
                    },
                  ),
                  if (_sellPlanEnabled) ...[
                    _buildCardDivider(isDarkMode),
                    _HoldingNumberFieldRow(
                      label: 'Take Profit %',
                      controller: _takeProfitController,
                      focusNode: _takeProfitFocusNode,
                      hintText: '0.00',
                      isDarkMode: isDarkMode,
                      errorText: _takeProfitError,
                    ),
                    _buildCardDivider(isDarkMode),
                    _HoldingNumberFieldRow(
                      label: 'Trailing Stop %',
                      controller: _trailingStopController,
                      focusNode: _trailingStopFocusNode,
                      hintText: '0.00',
                      isDarkMode: isDarkMode,
                      errorText: _trailingStopError,
                    ),
                    _buildCardDivider(isDarkMode),
                    _HoldingNumberFieldRow(
                      label: 'Stop Loss %',
                      controller: _stopLossController,
                      focusNode: _stopLossFocusNode,
                      hintText: '0.00',
                      isDarkMode: isDarkMode,
                      errorText: _stopLossError,
                    ),
                    _buildCardDivider(isDarkMode),
                    _HoldingSwitchRow(
                      title: 'กำหนดกำไรสูงสุดเอง',
                      subtitle: _peakProfitStatusText(),
                      value: _manualPeakProfitEnabled,
                      activeColor: accentColor,
                      isDarkMode: isDarkMode,
                      textColor: textColor,
                      secondaryColor: secondaryColor,
                      onChanged: (value) {
                        setState(() {
                          _manualPeakProfitEnabled = value;
                          _peakProfitError = null;
                        });
                        if (!value) {
                          _peakProfitFocusNode.unfocus();
                        }
                      },
                    ),
                    if (_manualPeakProfitEnabled) ...[
                      _buildCardDivider(isDarkMode),
                      _HoldingNumberFieldRow(
                        label: 'กำไรสูงสุด %',
                        controller: _peakProfitController,
                        focusNode: _peakProfitFocusNode,
                        hintText: '0.00',
                        isDarkMode: isDarkMode,
                        errorText: _peakProfitError,
                        inputFormatters: [_twoDecimalInputFormatter],
                      ),
                    ],
                    if (_sellPlanError != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                        child: Text(
                          _sellPlanError!,
                          style: TextStyle(fontSize: 12, color: expenseColor),
                          textAlign: TextAlign.right,
                        ),
                      ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInsetCard({
    required Color surfaceColor,
    required Color dividerColor,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppRadii.xLarge),
        border: Border.all(
          color: dividerColor.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildCardDivider(bool isDarkMode) {
    return Divider(
      height: 1,
      indent: 16,
      endIndent: 0,
      color: isDarkMode
          ? AppColors.darkDivider.withValues(alpha: 0.3)
          : AppColors.divider.withValues(alpha: 0.4),
    );
  }

  String _peakProfitStatusText() {
    if (_manualPeakProfitEnabled) {
      return 'ใช้ค่าที่กรอกเอง';
    }

    final value = widget.existing?.peakProfitPct;
    if (value == null) {
      return 'อัตโนมัติ';
    }
    return 'อัตโนมัติ • ปัจจุบัน ${_formatPct(value)}%';
  }
}

class _HoldingNumberFieldRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final bool isDarkMode;
  final String? errorText;
  final List<TextInputFormatter>? inputFormatters;

  const _HoldingNumberFieldRow({
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.isDarkMode,
    this.errorText,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 140,
                child: Text(
                  label,
                  style: TextStyle(fontSize: 15, color: labelColor),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters:
                      inputFormatters ??
                      [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: TextStyle(
                      color: labelColor.withValues(alpha: 0.6),
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          if (errorText != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  errorText!,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode
                        ? AppColors.darkExpense
                        : AppColors.expense,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HoldingSwitchRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;
  final bool isDarkMode;
  final Color textColor;
  final Color secondaryColor;

  const _HoldingSwitchRow({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    required this.activeColor,
    required this.isDarkMode,
    required this.textColor,
    required this.secondaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(fontSize: 12, color: secondaryColor),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: activeColor,
            inactiveTrackColor: isDarkMode
                ? const Color(0xFF39393D)
                : const Color(0xFFE9E9EA),
          ),
        ],
      ),
    );
  }
}
