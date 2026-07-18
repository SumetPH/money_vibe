import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/stock_holding.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_bar_action_button.dart';

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
    final backgroundColor = isDarkMode ? AppColors.darkSurface : Colors.white;
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
    final backgroundColor = isDarkMode ? AppColors.darkSurface : Colors.white;
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
    final theme = Theme.of(context);
    final labelColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _isSaving ? null : () => Navigator.pop(context),
        ),
        title: Text(_isEditing ? 'แก้ไขหุ้น' : 'เพิ่มหุ้น'),
        actions: [
          if (_isEditing && widget.onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _isSaving ? null : _delete,
              tooltip: 'ลบหุ้น',
            ),
          AppBarActionButton(
            icon: const Icon(Icons.check),
            onPressed: _save,
            tooltip: 'บันทึก',
            isLoading: _isSaving,
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _isSaving,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              color:
                  theme.cardTheme.color ??
                  (isDarkMode ? AppColors.darkSurface : AppColors.surface),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              child: Row(
                children: [
                  SizedBox(
                    width: 150,
                    child: Text(
                      'Ticker',
                      style: TextStyle(fontSize: 15, color: labelColor),
                    ),
                  ),
                  // const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _tickerController,
                      textCapitalization: TextCapitalization.characters,
                      textAlign: TextAlign.right,
                      autofocus: !_isEditing,
                      decoration: InputDecoration(
                        hintText: 'เช่น AAPL',
                        hintStyle: TextStyle(color: labelColor),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                      ),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w300,
                        color: isDarkMode
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _buildDivider(isDarkMode),
            Container(
              color:
                  theme.cardTheme.color ??
                  (isDarkMode ? AppColors.darkSurface : AppColors.surface),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              child: Row(
                children: [
                  SizedBox(
                    width: 150,
                    child: Text(
                      'กลุ่ม / พอร์ต',
                      style: TextStyle(fontSize: 15, color: labelColor),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _groupController,
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        hintText: 'ทั่วไป',
                        hintStyle: TextStyle(color: labelColor),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                      ),
                      style: TextStyle(
                        fontSize: 15,
                        color: isDarkMode
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _HoldingNumberFieldRow(
              label: 'จำนวนหุ้น',
              controller: _sharesController,
              focusNode: _sharesFocusNode,
              hintText: '0',
              isDarkMode: isDarkMode,
              inputFormatters: [_sevenDecimalInputFormatter],
            ),
            _buildDivider(isDarkMode),
            _HoldingNumberFieldRow(
              label: 'ราคาทุน (${widget.currencyCode})',
              controller: _costController,
              focusNode: _costFocusNode,
              hintText: '0.00',
              isDarkMode: isDarkMode,
              inputFormatters: [_fourDecimalInputFormatter],
            ),
            _buildDivider(isDarkMode),
            _HoldingNumberFieldRow(
              label: 'ราคาปัจจุบัน (${widget.currencyCode})',
              controller: _priceController,
              focusNode: _priceFocusNode,
              hintText: '0.00',
              isDarkMode: isDarkMode,
            ),
            const SizedBox(height: 16),
            Container(
              color:
                  theme.cardTheme.color ??
                  (isDarkMode ? AppColors.darkSurface : AppColors.surface),
              child: SwitchListTile(
                value: _sellPlanEnabled,
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
                title: Text(
                  'เปิดแผนขาย',
                  style: TextStyle(
                    fontSize: 15,
                    color: isDarkMode
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  'ตั้ง Take Profit %, Trailing Stop % และ Stop Loss % (Take Profit ใส่ 0 ได้)',
                  style: TextStyle(fontSize: 13, color: labelColor),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
            if (_sellPlanEnabled) ...[
              _buildDivider(isDarkMode),
              _HoldingNumberFieldRow(
                label: 'Take Profit %',
                controller: _takeProfitController,
                focusNode: _takeProfitFocusNode,
                hintText: '0.00',
                isDarkMode: isDarkMode,
                errorText: _takeProfitError,
              ),
              _buildDivider(isDarkMode),
              _HoldingNumberFieldRow(
                label: 'Trailing Stop %',
                controller: _trailingStopController,
                focusNode: _trailingStopFocusNode,
                hintText: '0.00',
                isDarkMode: isDarkMode,
                errorText: _trailingStopError,
              ),
              _buildDivider(isDarkMode),
              _HoldingNumberFieldRow(
                label: 'Stop Loss %',
                controller: _stopLossController,
                focusNode: _stopLossFocusNode,
                hintText: '0.00',
                isDarkMode: isDarkMode,
                errorText: _stopLossError,
              ),
              _buildDivider(isDarkMode),
              Container(
                color:
                    theme.cardTheme.color ??
                    (isDarkMode ? AppColors.darkSurface : AppColors.surface),
                child: SwitchListTile(
                  value: _manualPeakProfitEnabled,
                  onChanged: (value) {
                    setState(() {
                      _manualPeakProfitEnabled = value;
                      _peakProfitError = null;
                    });
                    if (!value) {
                      _peakProfitFocusNode.unfocus();
                    }
                  },
                  title: Text(
                    'กำหนดกำไรสูงสุดเอง',
                    style: TextStyle(
                      fontSize: 15,
                      color: isDarkMode
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    _peakProfitStatusText(),
                    style: TextStyle(fontSize: 13, color: labelColor),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
              if (_manualPeakProfitEnabled) ...[
                _buildDivider(isDarkMode),
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
                Container(
                  width: double.infinity,
                  color:
                      theme.cardTheme.color ??
                      (isDarkMode ? AppColors.darkSurface : AppColors.surface),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Text(
                    _sellPlanError!,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode
                          ? AppColors.darkExpense
                          : AppColors.expense,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
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

  Widget _buildDivider(bool isDarkMode) {
    return Divider(
      height: 1,
      color: isDarkMode ? AppColors.darkDivider : AppColors.divider,
    );
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
    final theme = Theme.of(context);
    final labelColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;

    return Container(
      color:
          theme.cardTheme.color ??
          (isDarkMode ? AppColors.darkSurface : AppColors.surface),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 150,
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
                    hintStyle: TextStyle(color: labelColor),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  style: TextStyle(fontSize: 15, color: textColor),
                ),
              ),
            ],
          ),
          if (errorText != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
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
