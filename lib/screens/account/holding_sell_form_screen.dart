import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/stock_holding.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';

typedef SellHoldingCallback =
    Future<void> Function({
      required double sharesSold,
      required double sellPriceUsd,
      required double cashReceivedUsd,
      required double remainingShares,
      required bool resetPeakProfit,
      double? remainingCostBasisUsd,
      double? grossProceedsUsd,
      double? brokerFeeUsd,
      double? exchangeFeeUsd,
      double? taxFeeUsd,
    });

TextInputFormatter _decimalInputFormatter(int maxDecimals) =>
    TextInputFormatter.withFunction((oldValue, newValue) {
      final text = newValue.text;
      if (text.isEmpty) return newValue;

      final match = RegExp('^\\d+(\\.\\d{0,$maxDecimals})?\$').hasMatch(text);
      return match ? newValue : oldValue;
    });

double _roundToCents(double value) => (value * 100).roundToDouble() / 100;

class HoldingSellFormScreen extends StatefulWidget {
  final StockHolding holding;
  final String currencyCode;
  final SellHoldingCallback onSell;

  const HoldingSellFormScreen({
    super.key,
    required this.holding,
    required this.currencyCode,
    required this.onSell,
  });

  @override
  State<HoldingSellFormScreen> createState() => _HoldingSellFormScreenState();
}

class _HoldingSellFormScreenState extends State<HoldingSellFormScreen> {
  final _sharesController = TextEditingController();
  final _sellPriceController = TextEditingController();
  final _grossProceedsController = TextEditingController();
  final _brokerFeeController = TextEditingController();
  final _taxFeeController = TextEditingController();
  final _exchangeFeeController = TextEditingController();
  final _cashReceivedController = TextEditingController();
  final _remainingSharesController = TextEditingController();
  final _remainingTotalCostController = TextEditingController();
  final _remainingCostBasisController = TextEditingController();

  bool _grossEdited = false;
  bool _cashEdited = false;
  bool _remainingSharesEdited = false;
  bool _isSyncingRemainingHolding = false;
  bool _isSaving = false;

  String? _sharesError;
  String? _sellPriceError;
  String? _cashReceivedError;
  String? _remainingSharesError;
  String? _remainingTotalCostError;
  String? _remainingCostBasisError;

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
    _syncGrossProceeds();
    _syncRemainingHoldingFromSharesSold();

    _sharesController.addListener(_onSharesOrPriceChanged);
    _sellPriceController.addListener(_onSharesOrPriceChanged);
    _grossProceedsController.addListener(_onGrossChanged);
    _brokerFeeController.addListener(_syncCashReceived);
    _taxFeeController.addListener(_syncCashReceived);
    _exchangeFeeController.addListener(_syncCashReceived);
    _remainingTotalCostController.addListener(_syncRemainingCostBasisFromTotal);
    _remainingCostBasisController.addListener(
      _syncRemainingTotalCostFromCostBasis,
    );

    _syncCashReceived(notify: false);
  }

  @override
  void dispose() {
    _sharesController.dispose();
    _sellPriceController.dispose();
    _grossProceedsController.dispose();
    _brokerFeeController.dispose();
    _taxFeeController.dispose();
    _exchangeFeeController.dispose();
    _cashReceivedController.dispose();
    _remainingSharesController.dispose();
    _remainingTotalCostController.dispose();
    _remainingCostBasisController.dispose();
    super.dispose();
  }

  void _onSharesOrPriceChanged() {
    if (!_grossEdited) {
      _syncGrossProceeds();
    }
    _syncRemainingHoldingFromSharesSold();
  }

  void _syncRemainingHoldingFromSharesSold() {
    if (_isSyncingRemainingHolding) return;
    final sharesSold = double.tryParse(_sharesController.text.trim()) ?? 0;
    final calculatedRemainingShares = (widget.holding.shares - sharesSold)
        .clamp(0.0, widget.holding.shares)
        .toDouble();
    final remainingShares = _remainingSharesEdited
        ? double.tryParse(_remainingSharesController.text.trim()) ?? 0
        : calculatedRemainingShares;
    _setRemainingHoldingValues(
      shares: remainingShares,
      costBasis: widget.holding.costBasisUsd,
      updateShares: !_remainingSharesEdited,
    );
  }

  void _syncRemainingCostBasisFromTotal() {
    if (_isSyncingRemainingHolding) return;
    final shares = double.tryParse(_remainingSharesController.text.trim()) ?? 0;
    final totalCost =
        double.tryParse(_remainingTotalCostController.text.trim()) ?? 0;
    _setRemainingHoldingValues(
      shares: shares,
      costBasis: shares > 0 ? totalCost / shares : 0,
      updateShares: false,
      updateTotalCost: false,
    );
  }

  void _syncRemainingTotalCostFromCostBasis() {
    if (_isSyncingRemainingHolding) return;
    final shares = double.tryParse(_remainingSharesController.text.trim()) ?? 0;
    final costBasis =
        double.tryParse(_remainingCostBasisController.text.trim()) ?? 0;
    _setRemainingHoldingValues(
      shares: shares,
      costBasis: costBasis,
      updateShares: false,
      updateCostBasis: false,
    );
  }

  void _setRemainingHoldingValues({
    required double shares,
    required double costBasis,
    bool updateShares = true,
    bool updateTotalCost = true,
    bool updateCostBasis = true,
  }) {
    _isSyncingRemainingHolding = true;
    if (updateShares) {
      _remainingSharesController.text = formatStockHoldingEditableNumber(
        shares,
        scale: stockHoldingSharesDecimalPlaces,
      );
    }
    if (updateTotalCost) {
      _remainingTotalCostController.text = formatStockHoldingEditableNumber(
        shares * costBasis,
        scale: 2,
      );
    }
    if (updateCostBasis) {
      _remainingCostBasisController.text = formatStockHoldingEditableNumber(
        costBasis,
        scale: stockHoldingCostBasisDecimalPlaces,
      );
    }
    _isSyncingRemainingHolding = false;
    if (mounted) setState(() {});
  }

  void _onGrossChanged() {
    if (!_cashEdited) {
      _syncCashReceived();
    }
    setState(() {});
  }

  void _syncGrossProceeds() {
    final shares = double.tryParse(_sharesController.text.trim()) ?? 0;
    final price = double.tryParse(_sellPriceController.text.trim()) ?? 0;
    final value = shares * price;
    if (value > 0) {
      final newText = formatStockHoldingEditableNumber(value, scale: 2);
      if (_grossProceedsController.text != newText) {
        _grossProceedsController.text = newText;
      }
    } else {
      if (_grossProceedsController.text != '') {
        _grossProceedsController.text = '';
      }
    }
  }

  void _syncCashReceived({bool notify = true}) {
    if (_cashEdited) return;
    final value = _calculateCashReceivedFromDetails();

    if (value > 0) {
      final newText = formatStockHoldingEditableNumber(value, scale: 2);
      if (_cashReceivedController.text != newText) {
        _cashReceivedController.text = newText;
      }
    } else {
      if (_cashReceivedController.text != '') {
        _cashReceivedController.text = '';
      }
    }
    if (notify) setState(() {});
  }

  double _calculateCashReceivedFromDetails() {
    final gross = double.tryParse(_grossProceedsController.text.trim()) ?? 0;
    final broker = double.tryParse(_brokerFeeController.text.trim()) ?? 0;
    final tax = double.tryParse(_taxFeeController.text.trim()) ?? 0;
    final exchange = double.tryParse(_exchangeFeeController.text.trim()) ?? 0;
    return gross - broker - tax - exchange;
  }

  Future<void> _submit() async {
    final shares = double.tryParse(_sharesController.text.trim());
    final sellPrice = double.tryParse(_sellPriceController.text.trim());
    final grossProceeds = double.tryParse(_grossProceedsController.text.trim());
    final brokerFee = double.tryParse(_brokerFeeController.text.trim());
    final taxFee = double.tryParse(_taxFeeController.text.trim());
    final exchangeFee = double.tryParse(_exchangeFeeController.text.trim());
    final displayedCashReceived = double.tryParse(
      _cashReceivedController.text.trim(),
    );
    final cashReceived = _cashEdited
        ? displayedCashReceived
        : _roundToCents(_calculateCashReceivedFromDetails());
    final remainingShares = double.tryParse(_remainingSharesController.text);
    final remainingTotalCost = double.tryParse(
      _remainingTotalCostController.text,
    );
    final remainingCostBasis = double.tryParse(
      _remainingCostBasisController.text,
    );

    setState(() {
      _sharesError = null;
      _sellPriceError = null;
      _cashReceivedError = null;
      _remainingSharesError = null;
      _remainingTotalCostError = null;
      _remainingCostBasisError = null;
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

    if (remainingShares == null || remainingShares < 0) {
      _remainingSharesError = 'ต้องไม่ติดลบ';
      hasError = true;
    } else if (remainingShares > widget.holding.shares + 0.0000001) {
      _remainingSharesError = 'มากกว่าจำนวนที่ถือ';
      hasError = true;
    }
    if (remainingTotalCost == null || remainingTotalCost < 0) {
      _remainingTotalCostError = 'ต้องไม่ติดลบ';
      hasError = true;
    }
    if (remainingCostBasis == null || remainingCostBasis < 0) {
      _remainingCostBasisError = 'ต้องไม่ติดลบ';
      hasError = true;
    }

    if (hasError) {
      return;
    }

    final resetPeakProfit = await _confirmResetPeakProfitIfNeeded(
      remainingShares: remainingShares!,
      remainingCostBasisUsd: remainingCostBasis!,
    );
    if (resetPeakProfit == null) return;

    setState(() => _isSaving = true);
    try {
      await widget.onSell(
        sharesSold: shares!,
        sellPriceUsd: sellPrice!,
        cashReceivedUsd: cashReceived!,
        remainingShares: remainingShares,
        resetPeakProfit: resetPeakProfit,
        remainingCostBasisUsd: remainingCostBasis,
        grossProceedsUsd: grossProceeds,
        brokerFeeUsd: brokerFee,
        taxFeeUsd: taxFee,
        exchangeFeeUsd: exchangeFee,
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<bool?> _confirmResetPeakProfitIfNeeded({
    required double remainingShares,
    required double remainingCostBasisUsd,
  }) async {
    final holding = widget.holding;
    if (remainingShares <= 0.0000001 ||
        !holding.sellPlanEnabled ||
        holding.peakProfitPct == null) {
      return false;
    }

    final basisChanged = holding
        .copyWith(shares: remainingShares, costBasisUsd: remainingCostBasisUsd)
        .hasInvestmentBasisChangedFrom(holding);
    if (!basisChanged) return false;

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

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final isDarkMode = settingsProvider.isDarkMode;
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
    final expenseColor = isDarkMode ? AppColors.darkExpense : AppColors.expense;

    final sharesSold = double.tryParse(_sharesController.text.trim()) ?? 0;
    final cashReceived =
        double.tryParse(_cashReceivedController.text.trim()) ?? 0;

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
          'ขาย ${widget.holding.ticker}',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton(
              onPressed: _isSaving ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: expenseColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                shape: const StadiumBorder(),
                elevation: 0,
                minimumSize: const Size(64, 36),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Text(
                      'ขาย',
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 4, bottom: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(AppRadii.xLarge),
                    border: Border.all(
                      color: dividerColor.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? AppColors.darkSurfaceVariant
                              : AppColors.sectionHeader,
                          borderRadius: BorderRadius.circular(AppRadii.large),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          widget.holding.ticker.length > 2
                              ? widget.holding.ticker.substring(0, 2)
                              : widget.holding.ticker,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.holding.ticker,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 18,
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? AppColors.darkSurfaceVariant
                              : AppColors.sectionHeader,
                          borderRadius: BorderRadius.circular(AppRadii.full),
                        ),
                        child: Text(
                          'ถือ ${formatStockHoldingShares(widget.holding.shares)} หุ้น',
                          style: TextStyle(
                            color: secondaryColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildSectionHeader('ข้อมูลการขาย', secondaryColor),
                _buildInsetCard(
                  surfaceColor: surfaceColor,
                  dividerColor: dividerColor,
                  children: [
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
                    _buildCardDivider(isDarkMode),
                    _SellNumberFieldRow(
                      label: 'ราคาขาย (${widget.currencyCode})',
                      controller: _sellPriceController,
                      hintText: '0.00',
                      isDarkMode: isDarkMode,
                      errorText: _sellPriceError,
                      inputFormatters: [
                        _decimalInputFormatter(stockHoldingPriceDecimalPlaces),
                      ],
                    ),
                    _buildCardDivider(isDarkMode),
                    _SellNumberFieldRow(
                      label: 'มูลค่าหุ้น (Gross ${widget.currencyCode})',
                      controller: _grossProceedsController,
                      hintText: '0.00',
                      isDarkMode: isDarkMode,
                      inputFormatters: [_decimalInputFormatter(2)],
                      onChanged: (_) {
                        _grossEdited = true;
                        _syncCashReceived();
                      },
                    ),
                    _buildCardDivider(isDarkMode),
                    _SellNumberFieldRow(
                      label: 'ยอดที่จะได้รับคืน (Net ${widget.currencyCode})',
                      controller: _cashReceivedController,
                      hintText: '0.00',
                      isDarkMode: isDarkMode,
                      errorText: _cashReceivedError,
                      inputFormatters: [_decimalInputFormatter(2)],
                      onChanged: (_) {
                        _cashEdited = true;
                        setState(() {});
                      },
                    ),
                  ],
                ),
                _buildSectionHeader('ค่าธรรมเนียม', secondaryColor),
                _buildInsetCard(
                  surfaceColor: surfaceColor,
                  dividerColor: dividerColor,
                  children: [
                    _SellNumberFieldRow(
                      label: 'ค่าคอมมิชชัน (${widget.currencyCode})',
                      controller: _brokerFeeController,
                      hintText: '0.00',
                      isDarkMode: isDarkMode,
                      inputFormatters: [_decimalInputFormatter(4)],
                    ),
                    _buildCardDivider(isDarkMode),
                    _SellNumberFieldRow(
                      label: 'ภาษี (VAT ${widget.currencyCode})',
                      controller: _taxFeeController,
                      hintText: '0.00',
                      isDarkMode: isDarkMode,
                      inputFormatters: [_decimalInputFormatter(4)],
                    ),
                    _buildCardDivider(isDarkMode),
                    _SellNumberFieldRow(
                      label: 'ค่าธรรมเนียมอื่นๆ (SEC/TAF)',
                      controller: _exchangeFeeController,
                      hintText: '0.00',
                      isDarkMode: isDarkMode,
                      inputFormatters: [_decimalInputFormatter(4)],
                    ),
                  ],
                ),
                _buildSectionHeader('หลังการขาย', secondaryColor),
                _buildInsetCard(
                  surfaceColor: surfaceColor,
                  dividerColor: dividerColor,
                  children: [
                    _SellNumberFieldRow(
                      label: 'จำนวนหุ้นคงเหลือ',
                      controller: _remainingSharesController,
                      hintText: '0',
                      isDarkMode: isDarkMode,
                      errorText: _remainingSharesError,
                      inputFormatters: [
                        _decimalInputFormatter(stockHoldingSharesDecimalPlaces),
                      ],
                      onChanged: (_) {
                        _remainingSharesEdited = true;
                        _syncRemainingHoldingFromSharesSold();
                      },
                    ),
                    _buildCardDivider(isDarkMode),
                    _SellNumberFieldRow(
                      label: 'ต้นทุนรวมคงเหลือ (${widget.currencyCode})',
                      controller: _remainingTotalCostController,
                      hintText: '0.00',
                      isDarkMode: isDarkMode,
                      errorText: _remainingTotalCostError,
                      inputFormatters: [_decimalInputFormatter(2)],
                    ),
                    _buildCardDivider(isDarkMode),
                    _SellNumberFieldRow(
                      label: 'ต้นทุนต่อหุ้นคงเหลือ (${widget.currencyCode})',
                      controller: _remainingCostBasisController,
                      hintText: '0.0000',
                      isDarkMode: isDarkMode,
                      errorText: _remainingCostBasisError,
                      inputFormatters: [
                        _decimalInputFormatter(
                          stockHoldingCostBasisDecimalPlaces,
                        ),
                      ],
                    ),
                  ],
                ),
                _buildSectionHeader('สรุปผลการขาย', secondaryColor),
                _buildInsetCard(
                  surfaceColor: surfaceColor,
                  dividerColor: dividerColor,
                  children: [
                    _SellSummaryCard(
                      holding: widget.holding,
                      currencyCode: widget.currencyCode,
                      isDarkMode: isDarkMode,
                      sharesSold: sharesSold,
                      cashReceivedUsd: cashReceived,
                    ),
                  ],
                ),
              ],
            ),
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
          color: dividerColor.withValues(alpha: 0.35),
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
      color: (isDarkMode ? AppColors.darkDivider : AppColors.divider)
          .withValues(alpha: 0.3),
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: inputFormatters,
                  textAlign: TextAlign.right,
                  onChanged: onChanged,
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

class _SellSummaryCard extends StatelessWidget {
  final StockHolding holding;
  final String currencyCode;
  final bool isDarkMode;
  final double sharesSold;
  final double cashReceivedUsd;

  const _SellSummaryCard({
    required this.holding,
    required this.currencyCode,
    required this.isDarkMode,
    required this.sharesSold,
    required this.cashReceivedUsd,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final secondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;

    final estimatedCost = holding.costBasisUsd * sharesSold;
    final estimatedPnl = cashReceivedUsd - estimatedCost;
    final isProfit = estimatedPnl >= 0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ราคาทุนเฉลี่ย',
                style: TextStyle(color: secondaryColor, fontSize: 14),
              ),
              Text(
                '${formatStockHoldingCostBasis(holding.costBasisUsd)} $currencyCode/หุ้น',
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'กำไร/ขาดทุนโดยประมาณ',
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                sharesSold > 0
                    ? '${isProfit ? '+' : ''}${formatStockHoldingCostBasis(estimatedPnl)} $currencyCode'
                    : '-',
                style: TextStyle(
                  color: sharesSold > 0
                      ? (isProfit
                            ? (isDarkMode
                                  ? AppColors.darkIncome
                                  : AppColors.income)
                            : (isDarkMode
                                  ? AppColors.darkExpense
                                  : AppColors.expense))
                      : secondaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
