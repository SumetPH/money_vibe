import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/stock_holding.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';

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
  bool _isSaving = false;

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
    }
  }

  @override
  void dispose() {
    _tickerController.dispose();
    _sharesController.dispose();
    _priceController.dispose();
    _costController.dispose();
    super.dispose();
  }

  String _formatNum(double value) {
    if (value == value.truncateToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

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
    );

    setState(() => _isSaving = true);
    try {
      await widget.onSave(holding);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
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

    await widget.onDelete!();
    if (mounted) {
      Navigator.pop(context, true);
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
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_isEditing ? 'แก้ไขหุ้น' : 'เพิ่มหุ้น'),
        actions: [
          if (_isEditing && widget.onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _isSaving ? null : _delete,
              tooltip: 'ลบหุ้น',
            ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _isSaving ? null : _save,
            tooltip: 'บันทึก',
          ),
        ],
      ),
      body: ListView(
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
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
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
        ],
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

  const _HoldingNumberFieldRow({
    required this.label,
    required this.controller,
    required this.hintText,
    required this.isDarkMode,
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
      child: Row(
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
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
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
    );
  }
}
