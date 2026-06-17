import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/stock_holding.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';

typedef SellHoldingCallback =
    Future<void> Function({
      required double sharesSold,
      required double sellPriceUsd,
      required double cashReceivedUsd,
    });

TextInputFormatter _decimalInputFormatter(int maxDecimals) =>
    TextInputFormatter.withFunction((oldValue, newValue) {
      final text = newValue.text;
      if (text.isEmpty) return newValue;

      final match = RegExp('^\\d+(\\.\\d{0,$maxDecimals})?\$').hasMatch(text);
      return match ? newValue : oldValue;
    });

class HoldingSellFormScreen extends StatefulWidget {
  final StockHolding holding;
  final SellHoldingCallback onSell;

  const HoldingSellFormScreen({
    super.key,
    required this.holding,
    required this.onSell,
  });

  @override
  State<HoldingSellFormScreen> createState() => _HoldingSellFormScreenState();
}

class _HoldingSellFormScreenState extends State<HoldingSellFormScreen> {
  final _sharesController = TextEditingController();
  final _sellPriceController = TextEditingController();
  final _cashReceivedController = TextEditingController();
  bool _cashEdited = false;
  bool _isSaving = false;
  String? _sharesError;
  String? _sellPriceError;
  String? _cashReceivedError;

  @override
  void initState() {
    super.initState();
    _sharesController.text = formatStockHoldingEditableNumber(
      widget.holding.shares,
      scale: stockHoldingSharesDecimalPlaces,
    );
    _sellPriceController.text = formatStockHoldingEditableNumber(
      widget.holding.priceUsd,
      scale: stockHoldingPriceDecimalPlaces,
    );
    _setDefaultCashReceived();
    _sharesController.addListener(_syncDefaultCashReceived);
    _sellPriceController.addListener(_syncDefaultCashReceived);
  }

  @override
  void dispose() {
    _sharesController.dispose();
    _sellPriceController.dispose();
    _cashReceivedController.dispose();
    super.dispose();
  }

  void _syncDefaultCashReceived() {
    if (_cashEdited) return;
    _setDefaultCashReceived();
  }

  void _setDefaultCashReceived() {
    final shares = double.tryParse(_sharesController.text.trim()) ?? 0;
    final price = double.tryParse(_sellPriceController.text.trim()) ?? 0;
    final value = shares * price;
    _cashReceivedController.text = formatStockHoldingEditableNumber(
      value,
      scale: 4,
    );
  }

  Future<void> _submit() async {
    final shares = double.tryParse(_sharesController.text.trim());
    final sellPrice = double.tryParse(_sellPriceController.text.trim());
    final cashReceived = double.tryParse(_cashReceivedController.text.trim());

    setState(() {
      _sharesError = null;
      _sellPriceError = null;
      _cashReceivedError = null;
    });

    var hasError = false;
    if (shares == null || shares <= 0) {
      _sharesError = 'ต้องมากกว่า 0';
      hasError = true;
    } else if (shares > widget.holding.shares + 0.0000001) {
      _sharesError = 'มากกว่าจำนวนที่ถือ';
      hasError = true;
    }

    if (sellPrice == null || sellPrice < 0) {
      _sellPriceError = 'ต้องไม่ติดลบ';
      hasError = true;
    }

    if (cashReceived == null || cashReceived < 0) {
      _cashReceivedError = 'ต้องไม่ติดลบ';
      hasError = true;
    }

    if (hasError) {
      setState(() {});
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.onSell(
        sharesSold: shares!,
        sellPriceUsd: sellPrice!,
        cashReceivedUsd: cashReceived!,
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<SettingsProvider>().isDarkMode;
    final bgColor = isDarkMode
        ? AppColors.darkBackground
        : AppColors.background;
    final headerColor = isDarkMode ? AppColors.darkHeader : AppColors.header;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final secondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('ขาย ${widget.holding.ticker}'),
        backgroundColor: headerColor,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(icon: const Icon(Icons.check), onPressed: _submit),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _isSaving,
        child: ListView(
          padding: const EdgeInsets.only(top: 12, bottom: 24),
          children: [
            Container(
              color: isDarkMode ? AppColors.darkSurface : AppColors.surface,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.holding.ticker,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (widget.holding.name.isNotEmpty)
                          Text(
                            widget.holding.name,
                            style: TextStyle(
                              color: secondaryColor,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    'ถือ ${formatStockHoldingShares(widget.holding.shares)} หุ้น',
                    style: TextStyle(color: secondaryColor, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SellNumberFieldRow(
              label: 'จำนวนที่ขาย',
              controller: _sharesController,
              hintText: '0',
              isDarkMode: isDarkMode,
              errorText: _sharesError,
              inputFormatters: [
                _decimalInputFormatter(stockHoldingSharesDecimalPlaces),
              ],
            ),
            _buildDivider(isDarkMode),
            _SellNumberFieldRow(
              label: 'ราคาขาย (USD)',
              controller: _sellPriceController,
              hintText: '0.00',
              isDarkMode: isDarkMode,
              errorText: _sellPriceError,
              inputFormatters: [
                _decimalInputFormatter(stockHoldingPriceDecimalPlaces),
              ],
            ),
            _buildDivider(isDarkMode),
            _SellNumberFieldRow(
              label: 'เงินสดรับเข้า (USD)',
              controller: _cashReceivedController,
              hintText: '0.00',
              isDarkMode: isDarkMode,
              errorText: _cashReceivedError,
              inputFormatters: [_decimalInputFormatter(4)],
              onChanged: (_) => _cashEdited = true,
            ),
            const SizedBox(height: 12),
            _SellSummary(holding: widget.holding, isDarkMode: isDarkMode),
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

class _SellNumberFieldRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hintText;
  final bool isDarkMode;
  final String? errorText;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;

  const _SellNumberFieldRow({
    required this.label,
    required this.controller,
    required this.hintText,
    required this.isDarkMode,
    this.errorText,
    this.inputFormatters,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;

    return Container(
      color: isDarkMode ? AppColors.darkSurface : AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: SizedBox(
              width: 150,
              child: Text(
                label,
                style: TextStyle(fontSize: 15, color: labelColor),
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: inputFormatters,
              textAlign: TextAlign.right,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(color: labelColor),
                errorText: errorText,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
              style: TextStyle(fontSize: 16, color: textColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _SellSummary extends StatelessWidget {
  final StockHolding holding;
  final bool isDarkMode;

  const _SellSummary({required this.holding, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        'กำไร/ขาดทุนจะคำนวณจากราคาทุน ${formatStockHoldingCostBasis(holding.costBasisUsd)} USD',
        style: TextStyle(color: textColor, fontSize: 12),
        textAlign: TextAlign.right,
      ),
    );
  }
}
