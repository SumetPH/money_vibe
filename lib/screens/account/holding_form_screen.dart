import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/stock_holding.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';

final _twoDecimalInputFormatter = TextInputFormatter.withFunction((
  oldValue,
  newValue,
) {
  final text = newValue.text;
  if (text.isEmpty) return newValue;

  final match = RegExp(r'^\d+(\.\d{0,2})?$').hasMatch(text);
  return match ? newValue : oldValue;
});

class HoldingFormScreen extends StatefulWidget {
  final String portfolioId;
  final StockHolding? existing;
  final Future<void> Function(StockHolding holding) onSave;
  final Future<void> Function()? onDelete;
  final String Function() generateId;

  const HoldingFormScreen({
    super.key,
    required this.portfolioId,
    required this.existing,
    required this.onSave,
    required this.generateId,
    this.onDelete,
  });

  @override
  State<HoldingFormScreen> createState() => _HoldingFormScreenState();
}

class _HoldingFormScreenState extends State<HoldingFormScreen> {
  final _tickerController = TextEditingController();
  final _sharesController = TextEditingController();
  final _priceController = TextEditingController();
  final _costController = TextEditingController();
  final _takeProfitController = TextEditingController();
  final _trailingStopController = TextEditingController();
  final _peakProfitController = TextEditingController();
  bool _isSaving = false;
  bool _sellPlanEnabled = false;
  String? _takeProfitError;
  String? _trailingStopError;
  String? _peakProfitError;
  String? _sellPlanError;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final holding = widget.existing;
    if (holding != null) {
      _tickerController.text = holding.ticker;
      _sharesController.text = _formatNum(holding.shares);
      _priceController.text = _formatNum(holding.priceUsd);
      if (holding.costBasisUsd > 0) {
        _costController.text = _formatNum(holding.costBasisUsd);
      }
      _sellPlanEnabled = holding.sellPlanEnabled;
      if (holding.takeProfitPct > 0) {
        _takeProfitController.text = _formatNum(holding.takeProfitPct);
      }
      if (holding.trailingStopPct > 0) {
        _trailingStopController.text = _formatNum(holding.trailingStopPct);
      }
      if (holding.peakProfitPct != null) {
        _peakProfitController.text = _formatPct(holding.peakProfitPct!);
      }
    }
  }

  @override
  void dispose() {
    _tickerController.dispose();
    _sharesController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _takeProfitController.dispose();
    _trailingStopController.dispose();
    _peakProfitController.dispose();
    super.dispose();
  }

  String _formatNum(double value) {
    if (value == value.truncateToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
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

    final shares = double.tryParse(_sharesController.text.trim()) ?? 0;
    final price = double.tryParse(_priceController.text.trim()) ?? 0;
    final cost = double.tryParse(_costController.text.trim()) ?? 0;
    final takeProfit = double.tryParse(_takeProfitController.text.trim()) ?? 0;
    final trailingStop =
        double.tryParse(_trailingStopController.text.trim()) ?? 0;
    final peakProfitText = _peakProfitController.text.trim();
    final manualPeakProfit = peakProfitText.isEmpty
        ? null
        : double.tryParse(peakProfitText);

    setState(() {
      _takeProfitError = null;
      _trailingStopError = null;
      _peakProfitError = null;
      _sellPlanError = null;
    });

    if (_sellPlanEnabled) {
      var hasError = false;
      if (cost <= 0) {
        _sellPlanError = 'ต้องมีราคาทุนมากกว่า 0 เพื่อใช้แผนขาย';
        hasError = true;
      }
      if (takeProfit <= 0) {
        _takeProfitError = 'กรุณากรอก Take Profit %';
        hasError = true;
      }
      if (trailingStop <= 0) {
        _trailingStopError = 'กรุณากรอก Trailing Stop %';
        hasError = true;
      }
      if (peakProfitText.isNotEmpty && manualPeakProfit == null) {
        _peakProfitError = 'กรุณากรอกกำไรสูงสุด % ให้ถูกต้อง';
        hasError = true;
      } else if (manualPeakProfit != null && manualPeakProfit < takeProfit) {
        _peakProfitError = 'กำไรสูงสุด % ต้องมากกว่าหรือเท่ากับ Take Profit %';
        hasError = true;
      }
      if (hasError) {
        setState(() {});
        return;
      }
    }

    final peakProfitPct = _resolvePeakProfitPct(
      shares: shares,
      priceUsd: price,
      costBasisUsd: cost,
      sellPlanEnabled: _sellPlanEnabled,
      takeProfitPct: takeProfit,
      manualPeakProfitPct: manualPeakProfit,
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
      peakProfitPct: _sellPlanEnabled
          ? peakProfitPct
          : widget.existing?.peakProfitPct,
    );

    setState(() => _isSaving = true);
    try {
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
    if (currentPnlPct < takeProfitPct) {
      return null;
    }

    if (existing == null) {
      return _roundPct(currentPnlPct);
    }

    // Buying more or selling part of a position changes the investment basis,
    // so any historical peak profit percentage must start over from
    // the new position state.
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
      peakProfitPct: existing.peakProfitPct,
    ).hasInvestmentBasisChangedFrom(existing);
    if (basisChanged || !existing.sellPlanEnabled) {
      return _roundPct(currentPnlPct);
    }

    final previousPeak = existing.peakProfitPct;
    if (previousPeak == null || currentPnlPct > previousPeak) {
      return _roundPct(currentPnlPct);
    }
    return _roundPct(previousPeak);
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
          _isSaving
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: _isSaving ? null : _save,
                  tooltip: 'บันทึก',
                ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _isSaving,
        child: ListView(
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
            const SizedBox(height: 8),
            _HoldingNumberFieldRow(
              label: 'จำนวนหุ้น',
              controller: _sharesController,
              hintText: '0',
              isDarkMode: isDarkMode,
            ),
            _buildDivider(isDarkMode),
            _HoldingNumberFieldRow(
              label: 'ราคาทุน (USD)',
              controller: _costController,
              hintText: '0.00',
              isDarkMode: isDarkMode,
            ),
            _buildDivider(isDarkMode),
            _HoldingNumberFieldRow(
              label: 'ราคาปัจจุบัน (USD)',
              controller: _priceController,
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
                  'ตั้ง Take Profit % และ Trailing Stop %',
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
                hintText: '0.00',
                isDarkMode: isDarkMode,
                errorText: _takeProfitError,
              ),
              _buildDivider(isDarkMode),
              _HoldingNumberFieldRow(
                label: 'Trailing Stop %',
                controller: _trailingStopController,
                hintText: '0.00',
                isDarkMode: isDarkMode,
                errorText: _trailingStopError,
              ),
              _buildDivider(isDarkMode),
              _HoldingNumberFieldRow(
                label: 'กำไรสูงสุด %',
                controller: _peakProfitController,
                hintText: 'ปล่อยว่างให้ระบบคำนวณ',
                isDarkMode: isDarkMode,
                errorText: _peakProfitError,
                inputFormatters: [_twoDecimalInputFormatter],
              ),
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
  final String hintText;
  final bool isDarkMode;
  final String? errorText;
  final List<TextInputFormatter>? inputFormatters;

  const _HoldingNumberFieldRow({
    required this.label,
    required this.controller,
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
