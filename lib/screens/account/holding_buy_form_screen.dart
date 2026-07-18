import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/stock_holding.dart';
import '../../models/account.dart';
import '../../models/stock_purchase.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_bar_action_button.dart';
import '../../theme/app_radii.dart';

typedef BuyHoldingCallback =
    Future<void> Function({
      required String ticker,
      required String portfolioId,
      required double sharesBought,
      required double buyPriceUsd,
      required double cashPaidUsd,
      required double resultingShares,
      required double resultingCostBasisUsd,
      required bool resetPeakProfit,
      double? grossCostUsd,
      double? brokerFeeUsd,
      double? exchangeFeeUsd,
      double? taxFeeUsd,
      required bool sellPlanEnabled,
      required double takeProfitPct,
      required double trailingStopPct,
      required double stopLossPct,
    });

class HoldingBuyFormScreen extends StatefulWidget {
  final StockHolding? holding;
  final String currencyCode;
  final List<Account> portfolios;
  final String initialPortfolioId;
  final StockPurchase? existingPurchase;
  final BuyHoldingCallback onBuy;

  const HoldingBuyFormScreen({
    super.key,
    this.holding,
    required this.currencyCode,
    required this.portfolios,
    required this.initialPortfolioId,
    this.existingPurchase,
    required this.onBuy,
  });

  @override
  State<HoldingBuyFormScreen> createState() => _HoldingBuyFormScreenState();
}

class _HoldingBuyFormScreenState extends State<HoldingBuyFormScreen> {
  final _ticker = TextEditingController();
  final _takeProfit = TextEditingController();
  final _trailingStop = TextEditingController();
  final _stopLoss = TextEditingController();
  final _shares = TextEditingController();
  final _price = TextEditingController();
  final _gross = TextEditingController();
  final _brokerFee = TextEditingController();
  final _taxFee = TextEditingController();
  final _exchangeFee = TextEditingController();
  final _cash = TextEditingController();
  final _resultShares = TextEditingController();
  final _resultTotalCost = TextEditingController();
  final _resultCostBasis = TextEditingController();
  bool _syncing = false;
  bool _grossEdited = false;
  bool _cashEdited = false;
  bool _resultSharesEdited = false;
  bool _saving = false;
  bool _sellPlanEnabled = true;
  late String _selectedPortfolioId;

  StockHolding? get _holding => widget.holding;
  bool get _isNewHolding => _holding == null;
  bool get _isHistoryEdit => widget.existingPurchase != null;
  Account? get _selectedPortfolio {
    for (final portfolio in widget.portfolios) {
      if (portfolio.id == _selectedPortfolioId) return portfolio;
    }
    return null;
  }

  String get _currencyCode =>
      _selectedPortfolio?.currencyCodeLabel ?? widget.currencyCode;

  TextInputFormatter _decimalInputFormatter(int maxDecimals) =>
      TextInputFormatter.withFunction((oldValue, newValue) {
        final text = newValue.text;
        if (text.isEmpty) return newValue;
        return RegExp('^\\d+(\\.\\d{0,$maxDecimals})?\$').hasMatch(text)
            ? newValue
            : oldValue;
      });

  @override
  void initState() {
    super.initState();
    _selectedPortfolioId = widget.initialPortfolioId;
    final holding = _holding;
    if (holding != null) {
      _ticker.text = holding.ticker;
      _price.text = formatStockHoldingEditableNumber(
        holding.priceUsd,
        scale: stockHoldingPriceDecimalPlaces,
      );
      _sellPlanEnabled = holding.sellPlanEnabled;
      _takeProfit.text = formatStockHoldingEditableNumber(
        holding.takeProfitPct,
        scale: 2,
      );
      _trailingStop.text = formatStockHoldingEditableNumber(
        holding.trailingStopPct,
        scale: 2,
      );
      _stopLoss.text = formatStockHoldingEditableNumber(
        holding.stopLossPct,
        scale: 2,
      );
    }
    final purchase = widget.existingPurchase;
    if (purchase != null) {
      _ticker.text = purchase.ticker;
      _selectedPortfolioId = purchase.portfolioId;
      _shares.text = formatStockHoldingEditableNumber(
        purchase.sharesBought,
        scale: stockHoldingSharesDecimalPlaces,
      );
      _price.text = formatStockHoldingEditableNumber(
        purchase.buyPriceUsd,
        scale: stockHoldingPriceDecimalPlaces,
      );
      _gross.text = formatStockHoldingEditableNumber(
        purchase.costUsd,
        scale: 2,
      );
      _brokerFee.text = formatStockHoldingEditableNumber(
        purchase.brokerFeeUsd ?? 0,
        scale: 4,
      );
      _taxFee.text = formatStockHoldingEditableNumber(
        purchase.taxFeeUsd ?? 0,
        scale: 4,
      );
      _exchangeFee.text = formatStockHoldingEditableNumber(
        purchase.exchangeFeeUsd ?? 0,
        scale: 4,
      );
      _cash.text = formatStockHoldingEditableNumber(
        purchase.cashPaidUsd,
        scale: 2,
      );
      _grossEdited = true;
      _cashEdited = true;
    }
    if (holding == null) {
      _takeProfit.text = '10';
      _trailingStop.text = '5';
      _stopLoss.text = '5';
    }
    for (final controller in [_shares, _price]) {
      controller.addListener(_syncFromPurchase);
    }
    _gross.addListener(_syncCashPaid);
    _brokerFee.addListener(_syncCashPaid);
    _taxFee.addListener(_syncCashPaid);
    _exchangeFee.addListener(_syncCashPaid);
    _resultTotalCost.addListener(_syncCostBasisFromTotal);
    _resultCostBasis.addListener(_syncTotalFromCostBasis);
    _syncFromPurchase();
  }

  @override
  void dispose() {
    for (final controller in [
      _shares,
      _ticker,
      _takeProfit,
      _trailingStop,
      _stopLoss,
      _price,
      _gross,
      _brokerFee,
      _taxFee,
      _exchangeFee,
      _cash,
      _resultShares,
      _resultTotalCost,
      _resultCostBasis,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  double _value(TextEditingController controller) =>
      double.tryParse(controller.text) ?? 0;

  void _set(TextEditingController controller, double value, int scale) {
    controller.text = formatStockHoldingEditableNumber(value, scale: scale);
  }

  void _syncFromPurchase() {
    if (_syncing) return;
    final shares = _value(_shares);
    final price = _value(_price);
    final resultingShares = (_holding?.shares ?? 0) + shares;
    final gross = shares * price;
    _syncing = true;
    if (!_grossEdited) _set(_gross, gross, 2);
    if (!_resultSharesEdited) {
      _set(_resultShares, resultingShares, stockHoldingSharesDecimalPlaces);
    }
    _syncing = false;
    _syncCashPaid();
  }

  void _syncCashPaid() {
    if (_syncing) return;
    _syncing = true;
    if (!_cashEdited) _set(_cash, _cashPaidIncludingFees(), 2);
    _syncing = false;
    _syncResultingHolding();
  }

  void _syncResultingHolding() {
    final resultingShares = _value(_resultShares);
    final totalCost = (_holding?.totalCostUsd ?? 0) + _value(_gross);
    _syncing = true;
    _set(_resultTotalCost, totalCost, 2);
    _set(
      _resultCostBasis,
      resultingShares > 0 ? totalCost / resultingShares : 0,
      stockHoldingCostBasisDecimalPlaces,
    );
    _syncing = false;
    setState(() {});
  }

  double _cashPaidIncludingFees() =>
      _value(_gross) +
      _value(_brokerFee) +
      _value(_taxFee) +
      _value(_exchangeFee);

  void _syncCostBasisFromTotal() {
    if (_syncing) return;
    final shares = _value(_resultShares);
    _syncing = true;
    _set(
      _resultCostBasis,
      shares > 0 ? _value(_resultTotalCost) / shares : 0,
      stockHoldingCostBasisDecimalPlaces,
    );
    _syncing = false;
  }

  void _syncTotalFromCostBasis() {
    if (_syncing) return;
    _syncing = true;
    _set(_resultTotalCost, _value(_resultShares) * _value(_resultCostBasis), 2);
    _syncing = false;
  }

  Future<void> _save() async {
    final shares = _value(_shares);
    final price = _value(_price);
    final cash = _value(_cash);
    final ticker = _ticker.text.trim().toUpperCase();
    if (ticker.isEmpty || shares <= 0 || price < 0 || cash < 0) return;
    final takeProfit = _value(_takeProfit);
    final trailingStop = _value(_trailingStop);
    final stopLoss = _value(_stopLoss);
    if (_sellPlanEnabled &&
        (takeProfit < 0 || trailingStop <= 0 || stopLoss <= 0)) {
      return;
    }
    final resetPeakProfit = await _confirmResetPeakProfitIfNeeded();
    if (resetPeakProfit == null) return;
    setState(() => _saving = true);
    try {
      await widget.onBuy(
        ticker: ticker,
        portfolioId: _selectedPortfolioId,
        sharesBought: shares,
        buyPriceUsd: price,
        grossCostUsd: _value(_gross),
        brokerFeeUsd: _value(_brokerFee),
        taxFeeUsd: _value(_taxFee),
        exchangeFeeUsd: _value(_exchangeFee),
        sellPlanEnabled: _sellPlanEnabled,
        takeProfitPct: takeProfit,
        trailingStopPct: trailingStop,
        stopLossPct: stopLoss,
        cashPaidUsd: cash,
        resultingShares: _value(_resultShares),
        resultingCostBasisUsd: _value(_resultCostBasis),
        resetPeakProfit: resetPeakProfit,
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool?> _confirmResetPeakProfitIfNeeded() async {
    final holding = _holding;
    if (holding == null ||
        !holding.sellPlanEnabled ||
        holding.peakProfitPct == null) {
      return false;
    }

    final basisChanged = holding
        .copyWith(
          shares: _value(_resultShares),
          costBasisUsd: _value(_resultCostBasis),
        )
        .hasInvestmentBasisChangedFrom(holding);
    if (!basisChanged) return false;

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

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isDarkMode = settings.isDarkMode;
    final backgroundColor = isDarkMode
        ? AppColors.darkBackground
        : AppColors.background;
    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final headerColor = AppColors.headerFor(isDarkMode, settings.themeColor);
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final secondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          _isHistoryEdit
              ? 'แก้ไขประวัติซื้อ ${_ticker.text}'
              : (_isNewHolding
                    ? 'ซื้อหุ้นใหม่'
                    : 'ซื้อเพิ่ม ${_holding!.ticker}'),
        ),
        backgroundColor: headerColor,
        actions: [
          AppBarActionButton(
            icon: const Icon(Icons.check),
            onPressed: _save,
            tooltip: 'บันทึก',
            isLoading: _saving,
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 12, bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: surfaceColor,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isNewHolding ? 'หุ้นใหม่' : _holding!.ticker,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (!_isNewHolding && _holding!.name.isNotEmpty)
                            Text(
                              _holding!.name,
                              style: TextStyle(
                                color: secondaryColor,
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (!_isNewHolding)
                      Text(
                        'ถือ ${formatStockHoldingShares(_holding!.shares)} หุ้น',
                        style: TextStyle(color: secondaryColor, fontSize: 16),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_isNewHolding) ...[
                _BuyPortfolioFieldRow(
                  account: _selectedPortfolio,
                  isDarkMode: isDarkMode,
                  onTap: () => _selectPortfolio(isDarkMode: isDarkMode),
                ),
                _divider(isDarkMode),
                _BuyTickerFieldRow(controller: _ticker, isDarkMode: isDarkMode),
                _divider(isDarkMode),
              ],
              _BuyNumberFieldRow(
                label: 'จำนวนที่ซื้อ',
                controller: _shares,
                hintText: '0',
                isDarkMode: isDarkMode,
                inputFormatters: [_decimalInputFormatter(7)],
              ),
              _divider(isDarkMode),
              _BuyNumberFieldRow(
                label: 'ราคาซื้อ ($_currencyCode)',
                controller: _price,
                hintText: '0.00',
                isDarkMode: isDarkMode,
                inputFormatters: [_decimalInputFormatter(4)],
              ),
              _divider(isDarkMode),
              _BuyNumberFieldRow(
                label: 'มูลค่าหุ้น (Gross $_currencyCode)',
                controller: _gross,
                hintText: '0.00',
                isDarkMode: isDarkMode,
                inputFormatters: [_decimalInputFormatter(2)],
                onChanged: (_) {
                  _grossEdited = true;
                  _syncCashPaid();
                },
              ),

              if (!_isHistoryEdit) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    'ค่าธรรมเนียม',
                    style: TextStyle(
                      color: secondaryColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                _BuyNumberFieldRow(
                  label: 'ค่าคอมมิชชัน ($_currencyCode)',
                  controller: _brokerFee,
                  hintText: '0.00',
                  isDarkMode: isDarkMode,
                  inputFormatters: [_decimalInputFormatter(4)],
                ),
                _divider(isDarkMode),
                _BuyNumberFieldRow(
                  label: 'ภาษี (VAT $_currencyCode)',
                  controller: _taxFee,
                  hintText: '0.00',
                  isDarkMode: isDarkMode,
                  inputFormatters: [_decimalInputFormatter(4)],
                ),
                _divider(isDarkMode),
                _BuyNumberFieldRow(
                  label: 'ค่าธรรมเนียมอื่นๆ \n(SEC/TAF)',
                  controller: _exchangeFee,
                  hintText: '0.00',
                  isDarkMode: isDarkMode,
                  inputFormatters: [_decimalInputFormatter(4)],
                ),
                const SizedBox(height: 12),
                _divider(isDarkMode),
                _BuyNumberFieldRow(
                  label: 'ยอดที่จ่าย (Net $_currencyCode)',
                  controller: _cash,
                  hintText: '0.00',
                  isDarkMode: isDarkMode,
                  inputFormatters: [_decimalInputFormatter(2)],
                  onChanged: (_) {
                    _cashEdited = true;
                    _syncResultingHolding();
                  },
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    'หลังการซื้อ',
                    style: TextStyle(
                      color: secondaryColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                _BuyNumberFieldRow(
                  label: 'จำนวนหุ้น',
                  controller: _resultShares,
                  hintText: '0',
                  isDarkMode: isDarkMode,
                  inputFormatters: [_decimalInputFormatter(7)],
                  onChanged: (_) {
                    _resultSharesEdited = true;
                    _syncCostBasisFromTotal();
                  },
                ),
                _divider(isDarkMode),
                _BuyNumberFieldRow(
                  label: 'ต้นทุนรวม ($_currencyCode)',
                  controller: _resultTotalCost,
                  hintText: '0.00',
                  isDarkMode: isDarkMode,
                  inputFormatters: [_decimalInputFormatter(2)],
                ),
                _divider(isDarkMode),
                _BuyNumberFieldRow(
                  label: 'ต้นทุนต่อหุ้น ($_currencyCode)',
                  controller: _resultCostBasis,
                  hintText: '0.0000',
                  isDarkMode: isDarkMode,
                  inputFormatters: [_decimalInputFormatter(4)],
                ),
                const SizedBox(height: 12),
                if (_isNewHolding) ...[
                  Container(
                    color: surfaceColor,
                    child: SwitchListTile(
                      title: Text(
                        'กำหนดแผนขาย',
                        style: TextStyle(color: textColor),
                      ),
                      value: _sellPlanEnabled,
                      onChanged: (value) =>
                          setState(() => _sellPlanEnabled = value),
                    ),
                  ),
                  if (_sellPlanEnabled) ...[
                    _divider(isDarkMode),
                    _BuyNumberFieldRow(
                      label: 'Take Profit (%)',
                      controller: _takeProfit,
                      hintText: '0',
                      isDarkMode: isDarkMode,
                      inputFormatters: [_decimalInputFormatter(2)],
                    ),
                    _divider(isDarkMode),
                    _BuyNumberFieldRow(
                      label: 'Trailing Stop (%)',
                      controller: _trailingStop,
                      hintText: '0',
                      isDarkMode: isDarkMode,
                      inputFormatters: [_decimalInputFormatter(2)],
                    ),
                    _divider(isDarkMode),
                    _BuyNumberFieldRow(
                      label: 'Stop Loss (%)',
                      controller: _stopLoss,
                      hintText: '0',
                      isDarkMode: isDarkMode,
                      inputFormatters: [_decimalInputFormatter(2)],
                    ),
                  ],
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider(bool isDarkMode) => Divider(
    height: 1,
    color: isDarkMode ? AppColors.darkDivider : AppColors.divider,
  );

  Future<void> _selectPortfolio({required bool isDarkMode}) async {
    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final secondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: surfaceColor,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.sheet),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: dividerColor,
                      borderRadius: BorderRadius.circular(AppRadii.tiny),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'เลือกพอร์ต',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ...widget.portfolios.map(
                  (portfolio) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      portfolio.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: textColor),
                    ),
                    trailing: portfolio.id == _selectedPortfolioId
                        ? Icon(Icons.check, color: secondaryColor)
                        : null,
                    onTap: () => Navigator.pop(sheetContext, portfolio.id),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null && mounted) {
      setState(() => _selectedPortfolioId = selected);
    }
  }
}

class _BuyPortfolioFieldRow extends StatelessWidget {
  final Account? account;
  final bool isDarkMode;
  final VoidCallback onTap;

  const _BuyPortfolioFieldRow({
    required this.account,
    required this.isDarkMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    return Material(
      color: isDarkMode ? AppColors.darkSurface : AppColors.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              SizedBox(
                width: 150,
                child: Text(
                  'พอร์ต',
                  style: TextStyle(fontSize: 15, color: labelColor),
                ),
              ),
              Expanded(
                child: Text(
                  account?.name ?? 'เลือกพอร์ต',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 16, color: textColor),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, color: labelColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _BuyNumberFieldRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hintText;
  final bool isDarkMode;
  final List<TextInputFormatter> inputFormatters;
  final ValueChanged<String>? onChanged;

  const _BuyNumberFieldRow({
    required this.label,
    required this.controller,
    required this.hintText,
    required this.isDarkMode,
    required this.inputFormatters,
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
              textAlign: TextAlign.right,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: inputFormatters,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(color: labelColor),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
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

class _BuyTickerFieldRow extends StatelessWidget {
  final TextEditingController controller;
  final bool isDarkMode;

  const _BuyTickerFieldRow({
    required this.controller,
    required this.isDarkMode,
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
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: SizedBox(
              width: 150,
              child: Text(
                'Ticker',
                style: TextStyle(fontSize: 15, color: labelColor),
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              textAlign: TextAlign.right,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'เช่น AAPL',
                hintStyle: TextStyle(color: labelColor),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
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
