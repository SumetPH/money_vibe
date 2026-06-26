import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/account.dart';
import '../../models/stock_trade.dart';
import '../../providers/settings_provider.dart';
import '../../services/stock_logo_storage_service.dart';
import '../../services/stock_price_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../widgets/app_bar_action_button.dart';

typedef SaveStockTradeCallback = Future<void> Function(StockTrade trade);
typedef FetchStockProfileCallback =
    Future<StockCompanyProfile?> Function(String ticker);

TextInputFormatter _decimalInputFormatter(int maxDecimals) =>
    TextInputFormatter.withFunction((oldValue, newValue) {
      final text = newValue.text;
      if (text.isEmpty || text == '-') return newValue;

      final match = RegExp('^-?\\d+(\\.\\d{0,$maxDecimals})?\$').hasMatch(text);
      return match ? newValue : oldValue;
    });

class StockTradeFormScreen extends StatefulWidget {
  final List<Account> portfolios;
  final StockTrade? existing;
  final String Function() generateId;
  final SaveStockTradeCallback onSave;
  final FetchStockProfileCallback? fetchProfile;

  const StockTradeFormScreen({
    super.key,
    required this.portfolios,
    required this.existing,
    required this.generateId,
    required this.onSave,
    this.fetchProfile,
  });

  @override
  State<StockTradeFormScreen> createState() => _StockTradeFormScreenState();
}

class _StockTradeFormScreenState extends State<StockTradeFormScreen> {
  final _tickerController = TextEditingController();
  final _nameController = TextEditingController();
  final _sharesController = TextEditingController();
  final _sellPriceController = TextEditingController();
  final _cashReceivedController = TextEditingController();
  final _costBasisController = TextEditingController();
  final _realizedPnlController = TextEditingController();

  final _grossProceedsController = TextEditingController();
  final _brokerFeeController = TextEditingController();
  final _exchangeFeeController = TextEditingController();
  final _taxFeeController = TextEditingController();
  final StockLogoStorageService _logoStorageService = StockLogoStorageService();

  String? _portfolioId;
  DateTime _soldAt = DateTime.now();
  bool _isSaving = false;
  bool _useBrokerPnl = false;
  bool _showAdvancedDetails = false;

  String? _portfolioError;
  String? _tickerError;
  String? _sharesError;
  String? _sellPriceError;
  String? _cashReceivedError;
  String? _costBasisError;
  String? _realizedPnlError;

  String? _grossProceedsError;
  String? _brokerFeeError;
  String? _exchangeFeeError;
  String? _taxFeeError;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final trade = widget.existing;
    _portfolioId =
        trade?.portfolioId ??
        (widget.portfolios.isNotEmpty ? widget.portfolios.first.id : null);
    if (trade != null) {
      _tickerController.text = trade.ticker;
      _nameController.text = trade.name;
      _sharesController.text = _formatEditable(trade.sharesSold, 7);
      _sellPriceController.text = _formatEditable(trade.sellPriceUsd, 4);
      _cashReceivedController.text = _formatEditable(trade.cashReceivedUsd, 4);
      _costBasisController.text = _formatEditable(trade.costBasisUsd, 4);
      _soldAt = trade.soldAt;
      _useBrokerPnl =
          trade.pnlSource == PnlSource.broker ||
          trade.pnlSource == PnlSource.manual;
      _realizedPnlController.text = _formatEditable(trade.realizedPnlUsd, 4);
      if (trade.grossProceedsUsd != null) {
        _grossProceedsController.text = _formatEditable(
          trade.grossProceedsUsd!,
          4,
        );
      }
      if (trade.brokerFeeUsd != null) {
        _brokerFeeController.text = _formatEditable(trade.brokerFeeUsd!, 4);
      }
      if (trade.exchangeFeeUsd != null) {
        _exchangeFeeController.text = _formatEditable(trade.exchangeFeeUsd!, 4);
      }
      if (trade.taxFeeUsd != null) {
        _taxFeeController.text = _formatEditable(trade.taxFeeUsd!, 4);
      }
      _showAdvancedDetails =
          trade.name.trim().isNotEmpty ||
          trade.grossProceedsUsd != null ||
          trade.brokerFeeUsd != null ||
          trade.exchangeFeeUsd != null ||
          trade.taxFeeUsd != null ||
          _useBrokerPnl;
    }
  }

  @override
  void dispose() {
    _tickerController.dispose();
    _nameController.dispose();
    _sharesController.dispose();
    _sellPriceController.dispose();
    _cashReceivedController.dispose();
    _costBasisController.dispose();
    _realizedPnlController.dispose();
    _grossProceedsController.dispose();
    _brokerFeeController.dispose();
    _exchangeFeeController.dispose();
    _taxFeeController.dispose();
    super.dispose();
  }

  Future<void> _pickSoldAt() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _soldAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _soldAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _soldAt.hour,
        _soldAt.minute,
      );
    });
  }

  Future<void> _pickPortfolio(bool isDarkMode) async {
    final selected = await _showPortfolioPickerSheet(
      context: context,
      portfolios: widget.portfolios,
      selectedPortfolioId: _portfolioId,
      isDarkMode: isDarkMode,
    );
    if (!mounted || selected == null) return;
    setState(() {
      _portfolioId = selected;
      _portfolioError = null;
    });
  }

  Future<void> _submit() async {
    final shares = double.tryParse(_sharesController.text.trim());
    final sellPrice = double.tryParse(_sellPriceController.text.trim());
    final cashReceived = double.tryParse(_cashReceivedController.text.trim());
    final costBasis = double.tryParse(_costBasisController.text.trim());
    final realizedPnl = double.tryParse(_realizedPnlController.text.trim());
    final ticker = _tickerController.text.trim().toUpperCase();

    final grossProceeds = _grossProceedsController.text.trim().isNotEmpty
        ? double.tryParse(_grossProceedsController.text.trim())
        : null;
    final brokerFee = _brokerFeeController.text.trim().isNotEmpty
        ? double.tryParse(_brokerFeeController.text.trim())
        : null;
    final exchangeFee = _exchangeFeeController.text.trim().isNotEmpty
        ? double.tryParse(_exchangeFeeController.text.trim())
        : null;
    final taxFee = _taxFeeController.text.trim().isNotEmpty
        ? double.tryParse(_taxFeeController.text.trim())
        : null;

    setState(() {
      _portfolioError = null;
      _tickerError = null;
      _sharesError = null;
      _sellPriceError = null;
      _cashReceivedError = null;
      _costBasisError = null;
      _realizedPnlError = null;
      _grossProceedsError = null;
      _brokerFeeError = null;
      _exchangeFeeError = null;
      _taxFeeError = null;
    });

    var hasError = false;
    if (_portfolioId == null || _portfolioId!.isEmpty) {
      _portfolioError = 'ต้องเลือกพอร์ต';
      hasError = true;
    }
    if (ticker.isEmpty) {
      _tickerError = 'ต้องระบุ ticker';
      hasError = true;
    }
    if (shares == null || shares <= 0) {
      _sharesError = 'ต้องมากกว่า 0';
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
    if (costBasis == null || costBasis < 0) {
      _costBasisError = 'ต้องไม่ติดลบ';
      hasError = true;
    }
    if (_useBrokerPnl && realizedPnl == null) {
      _realizedPnlError = 'ต้องระบุตัวเลข (ติดลบได้)';
      hasError = true;
    }
    if (grossProceeds != null && grossProceeds < 0) {
      _grossProceedsError = 'ต้องไม่ติดลบ';
      hasError = true;
    }
    if (brokerFee != null && brokerFee < 0) {
      _brokerFeeError = 'ต้องไม่ติดลบ';
      hasError = true;
    }
    if (exchangeFee != null && exchangeFee < 0) {
      _exchangeFeeError = 'ต้องไม่ติดลบ';
      hasError = true;
    }
    if (taxFee != null && taxFee < 0) {
      _taxFeeError = 'ต้องไม่ติดลบ';
      hasError = true;
    }

    if (hasError) {
      setState(() {});
      return;
    }

    setState(() => _isSaving = true);
    final existing = widget.existing;
    final hasSameTicker =
        existing != null && existing.ticker.trim().toUpperCase() == ticker;
    final currentLogoUrl = hasSameTicker ? existing.logoUrl.trim() : '';
    final profile = await widget.fetchProfile?.call(ticker);
    final resolvedLogoUrl = await _resolveLogoUrl(
      ticker: ticker,
      sourceUrl: profile?.logoUrl ?? '',
      currentLogoUrl: currentLogoUrl,
    );
    if (!mounted) return;

    final trade = StockTrade(
      id: existing?.id ?? widget.generateId(),
      portfolioId: _portfolioId!,
      holdingId: existing?.holdingId ?? '',
      ticker: ticker,
      name: _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : (profile?.name ?? ''),
      logoUrl: resolvedLogoUrl,
      sharesSold: shares!,
      sellPriceUsd: sellPrice!,
      cashReceivedUsd: cashReceived!,
      costBasisUsd: costBasis!,
      realizedPnlUsd: _useBrokerPnl ? realizedPnl : null,
      pnlSource: _useBrokerPnl ? PnlSource.broker : PnlSource.estimated,
      costMethod: existing?.costMethod ?? CostMethod.average,
      grossProceedsUsd: grossProceeds,
      brokerFeeUsd: brokerFee,
      exchangeFeeUsd: exchangeFee,
      taxFeeUsd: taxFee,
      settledAt: existing?.settledAt,
      brokerOrderRef: existing?.brokerOrderRef,
      soldAt: _soldAt,
      createdAt: existing?.createdAt ?? DateTime.now(),
    );

    try {
      await widget.onSave(trade);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<String> _resolveLogoUrl({
    required String ticker,
    required String sourceUrl,
    required String currentLogoUrl,
  }) async {
    if (sourceUrl.isEmpty) return currentLogoUrl;
    if (_logoStorageService.isStoredLogoUrl(currentLogoUrl)) {
      return currentLogoUrl;
    }

    final mirroredLogoUrl = await _logoStorageService.mirrorLogo(
      ticker: ticker,
      sourceUrl: sourceUrl,
    );
    if (mirroredLogoUrl != null && mirroredLogoUrl.isNotEmpty) {
      return mirroredLogoUrl;
    }

    return currentLogoUrl.isNotEmpty ? currentLogoUrl : sourceUrl;
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final isDarkMode = settingsProvider.isDarkMode;
    final bgColor = isDarkMode
        ? AppColors.darkBackground
        : AppColors.background;
    final headerColor = AppColors.headerFor(
      isDarkMode,
      settingsProvider.themeColor,
    );
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final secondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    Account? selectedPortfolio;
    for (final portfolio in widget.portfolios) {
      if (portfolio.id == _portfolioId) {
        selectedPortfolio = portfolio;
        break;
      }
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(_isEditing ? 'แก้ไข Trade' : 'เพิ่ม Trade'),
        backgroundColor: headerColor,
        actions: [
          AppBarActionButton(
            icon: const Icon(Icons.check),
            onPressed: _submit,
            tooltip: 'บันทึก',
            isLoading: _isSaving,
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _isSaving,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            Container(
              color: isDarkMode ? AppColors.darkSurface : AppColors.surface,
              child: InkWell(
                onTap: () => _pickPortfolio(isDarkMode),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 140,
                            child: Text(
                              'พอร์ต',
                              style: TextStyle(
                                color: secondaryColor,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              selectedPortfolio?.name ?? 'เลือกพอร์ต',
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: textColor, fontSize: 16),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.keyboard_arrow_down,
                            color: secondaryColor,
                          ),
                        ],
                      ),
                      if (_portfolioError != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _portfolioError!,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: isDarkMode
                                ? AppColors.darkExpense
                                : AppColors.expense,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            _buildDivider(isDarkMode),
            _TradeTextFieldRow(
              label: 'Ticker',
              controller: _tickerController,
              hintText: 'AAPL',
              isDarkMode: isDarkMode,
              errorText: _tickerError,
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.characters,
            ),
            _buildDivider(isDarkMode),
            _TradeTextFieldRow(
              label: 'จำนวนขาย',
              controller: _sharesController,
              hintText: '0',
              isDarkMode: isDarkMode,
              errorText: _sharesError,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [_decimalInputFormatter(7)],
            ),
            _buildDivider(isDarkMode),
            _TradeTextFieldRow(
              label: 'ราคาทุน (USD)',
              controller: _costBasisController,
              hintText: '0.00',
              isDarkMode: isDarkMode,
              errorText: _costBasisError,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [_decimalInputFormatter(4)],
            ),
            _buildDivider(isDarkMode),
            _TradeTextFieldRow(
              label: 'ราคาขาย (USD)',
              controller: _sellPriceController,
              hintText: '0.00',
              isDarkMode: isDarkMode,
              errorText: _sellPriceError,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [_decimalInputFormatter(4)],
            ),
            _buildDivider(isDarkMode),
            _TradeTextFieldRow(
              label: 'เงินสดรับ (USD)',
              controller: _cashReceivedController,
              hintText: '0.00',
              isDarkMode: isDarkMode,
              errorText: _cashReceivedError,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [_decimalInputFormatter(4)],
            ),

            _buildDivider(isDarkMode),
            _AdvancedDetailsSection(
              isDarkMode: isDarkMode,
              textColor: textColor,
              secondaryColor: secondaryColor,
              isExpanded: _showAdvancedDetails,
              onToggle: () {
                setState(() {
                  _showAdvancedDetails = !_showAdvancedDetails;
                });
              },
              children: [
                _TradeTextFieldRow(
                  label: 'ชื่อหุ้น',
                  controller: _nameController,
                  hintText: 'Optional',
                  isDarkMode: isDarkMode,
                ),
                _buildDivider(isDarkMode),
                _TradeTextFieldRow(
                  label: 'มูลค่าขายรวม (Gross)',
                  controller: _grossProceedsController,
                  hintText: 'Optional',
                  isDarkMode: isDarkMode,
                  errorText: _grossProceedsError,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [_decimalInputFormatter(4)],
                ),
                _buildDivider(isDarkMode),
                _TradeTextFieldRow(
                  label: 'ค่าธรรมเนียม Broker',
                  controller: _brokerFeeController,
                  hintText: 'Optional',
                  isDarkMode: isDarkMode,
                  errorText: _brokerFeeError,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [_decimalInputFormatter(4)],
                ),
                _buildDivider(isDarkMode),
                _TradeTextFieldRow(
                  label: 'SEC / Exchange Fee',
                  controller: _exchangeFeeController,
                  hintText: 'Optional',
                  isDarkMode: isDarkMode,
                  errorText: _exchangeFeeError,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [_decimalInputFormatter(4)],
                ),
                _buildDivider(isDarkMode),
                _TradeTextFieldRow(
                  label: 'Tax / VAT',
                  controller: _taxFeeController,
                  hintText: 'Optional',
                  isDarkMode: isDarkMode,
                  errorText: _taxFeeError,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [_decimalInputFormatter(4)],
                ),
                _buildDivider(isDarkMode),
                Container(
                  color: isDarkMode ? AppColors.darkSurface : AppColors.surface,
                  child: SwitchListTile(
                    title: Text(
                      'ยึด P/L จาก Broker',
                      style: TextStyle(color: textColor, fontSize: 15),
                    ),
                    subtitle: Text(
                      'หากเปิด จะไม่คำนวณ P/L จาก Average Cost',
                      style: TextStyle(color: secondaryColor, fontSize: 13),
                    ),
                    value: _useBrokerPnl,
                    onChanged: (val) {
                      setState(() => _useBrokerPnl = val);
                    },
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
                if (_useBrokerPnl) ...[
                  _buildDivider(isDarkMode),
                  _TradeTextFieldRow(
                    label: 'Realized P/L (USD)',
                    controller: _realizedPnlController,
                    hintText: '0.00',
                    isDarkMode: isDarkMode,
                    errorText: _realizedPnlError,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    inputFormatters: [_decimalInputFormatter(4)],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              tileColor: isDarkMode ? AppColors.darkSurface : AppColors.surface,
              title: Text('วันที่ขาย', style: TextStyle(color: textColor)),
              subtitle: Text(
                _formatDate(_soldAt),
                style: TextStyle(color: secondaryColor),
              ),
              trailing: Icon(Icons.calendar_today, color: secondaryColor),
              onTap: _pickSoldAt,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                'บันทึกเฉพาะประวัติ Trade ไม่ปรับเงินสดในพอร์ต',
                style: TextStyle(color: secondaryColor, fontSize: 12),
                textAlign: TextAlign.right,
              ),
            ),
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

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String _formatEditable(double value, int scale) {
    if (value == value.truncateToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(scale).replaceFirst(RegExp(r'\.?0+$'), '');
  }
}

Future<String?> _showPortfolioPickerSheet({
  required BuildContext context,
  required List<Account> portfolios,
  required String? selectedPortfolioId,
  required bool isDarkMode,
}) {
  final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
  final textColor = isDarkMode
      ? AppColors.darkTextPrimary
      : AppColors.textPrimary;
  final secondaryColor = isDarkMode
      ? AppColors.darkTextSecondary
      : AppColors.textSecondary;
  final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;

  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: surfaceColor,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
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
              ...portfolios.map(
                (portfolio) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    portfolio.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: textColor),
                  ),
                  trailing: portfolio.id == selectedPortfolioId
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
}

class _AdvancedDetailsSection extends StatelessWidget {
  final bool isDarkMode;
  final Color textColor;
  final Color secondaryColor;
  final bool isExpanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  const _AdvancedDetailsSection({
    required this.isDarkMode,
    required this.textColor,
    required this.secondaryColor,
    required this.isExpanded,
    required this.onToggle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: isDarkMode ? AppColors.darkSurface : AppColors.surface,
          child: ListTile(
            title: Text(
              'รายละเอียดเพิ่มเติม',
              style: TextStyle(color: textColor, fontSize: 15),
            ),
            subtitle: Text(
              'ค่าธรรมเนียม ภาษี และข้อมูลจาก statement',
              style: TextStyle(color: secondaryColor, fontSize: 13),
            ),
            trailing: Icon(
              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: secondaryColor,
            ),
            onTap: onToggle,
          ),
        ),
        if (isExpanded) ...[
          Divider(
            height: 1,
            color: isDarkMode ? AppColors.darkDivider : AppColors.divider,
          ),
          ...children,
        ],
      ],
    );
  }
}

class _TradeTextFieldRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hintText;
  final bool isDarkMode;
  final String? errorText;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final TextInputType keyboardType;

  const _TradeTextFieldRow({
    required this.label,
    required this.controller,
    required this.hintText,
    required this.isDarkMode,
    this.keyboardType = TextInputType.text,
    this.errorText,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
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
              width: 140,
              child: Text(
                label,
                style: TextStyle(color: labelColor, fontSize: 15),
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              textAlign: TextAlign.right,
              keyboardType: keyboardType,
              textCapitalization: textCapitalization,
              inputFormatters: inputFormatters,
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
              style: TextStyle(color: textColor, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
