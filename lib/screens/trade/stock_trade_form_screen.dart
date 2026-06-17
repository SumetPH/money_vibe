import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/account.dart';
import '../../models/stock_trade.dart';
import '../../providers/settings_provider.dart';
import '../../services/stock_price_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';

typedef SaveStockTradeCallback = Future<void> Function(StockTrade trade);
typedef FetchStockProfileCallback =
    Future<StockCompanyProfile?> Function(String ticker);

TextInputFormatter _decimalInputFormatter(int maxDecimals) =>
    TextInputFormatter.withFunction((oldValue, newValue) {
      final text = newValue.text;
      if (text.isEmpty) return newValue;

      final match = RegExp('^\\d+(\\.\\d{0,$maxDecimals})?\$').hasMatch(text);
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
  final _logoUrlController = TextEditingController();

  String? _portfolioId;
  DateTime _soldAt = DateTime.now();
  bool _isSaving = false;
  String? _portfolioError;
  String? _tickerError;
  String? _sharesError;
  String? _sellPriceError;
  String? _cashReceivedError;
  String? _costBasisError;

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
      _logoUrlController.text = trade.logoUrl;
      _soldAt = trade.soldAt;
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
    _logoUrlController.dispose();
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
    final ticker = _tickerController.text.trim().toUpperCase();

    setState(() {
      _portfolioError = null;
      _tickerError = null;
      _sharesError = null;
      _sellPriceError = null;
      _cashReceivedError = null;
      _costBasisError = null;
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

    if (hasError) {
      setState(() {});
      return;
    }

    setState(() => _isSaving = true);
    final profile = _logoUrlController.text.trim().isEmpty
        ? await widget.fetchProfile?.call(ticker)
        : null;
    if (!mounted) return;

    final existing = widget.existing;
    final trade = StockTrade(
      id: existing?.id ?? widget.generateId(),
      portfolioId: _portfolioId!,
      holdingId: existing?.holdingId ?? '',
      ticker: ticker,
      name: _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : (profile?.name ?? ''),
      logoUrl: _logoUrlController.text.trim().isNotEmpty
          ? _logoUrlController.text.trim()
          : (profile?.logoUrl ?? ''),
      sharesSold: shares!,
      sellPriceUsd: sellPrice!,
      cashReceivedUsd: cashReceived!,
      costBasisUsd: costBasis!,
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
              textCapitalization: TextCapitalization.characters,
            ),
            _buildDivider(isDarkMode),
            _TradeTextFieldRow(
              label: 'ชื่อหุ้น',
              controller: _nameController,
              hintText: 'Optional',
              isDarkMode: isDarkMode,
            ),
            _buildDivider(isDarkMode),
            _TradeTextFieldRow(
              label: 'จำนวนขาย',
              controller: _sharesController,
              hintText: '0',
              isDarkMode: isDarkMode,
              errorText: _sharesError,
              inputFormatters: [_decimalInputFormatter(7)],
            ),
            _buildDivider(isDarkMode),
            _TradeTextFieldRow(
              label: 'ราคาขาย (USD)',
              controller: _sellPriceController,
              hintText: '0.00',
              isDarkMode: isDarkMode,
              errorText: _sellPriceError,
              inputFormatters: [_decimalInputFormatter(4)],
            ),
            _buildDivider(isDarkMode),
            _TradeTextFieldRow(
              label: 'เงินสดรับ (USD)',
              controller: _cashReceivedController,
              hintText: '0.00',
              isDarkMode: isDarkMode,
              errorText: _cashReceivedError,
              inputFormatters: [_decimalInputFormatter(4)],
            ),
            _buildDivider(isDarkMode),
            _TradeTextFieldRow(
              label: 'ราคาทุน (USD)',
              controller: _costBasisController,
              hintText: '0.00',
              isDarkMode: isDarkMode,
              errorText: _costBasisError,
              inputFormatters: [_decimalInputFormatter(4)],
            ),
            _buildDivider(isDarkMode),
            _TradeTextFieldRow(
              label: 'Logo URL',
              controller: _logoUrlController,
              hintText: 'Optional',
              isDarkMode: isDarkMode,
              keyboardType: TextInputType.url,
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
              Text(
                'เลือกพอร์ต',
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
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

class _TradeTextFieldRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hintText;
  final bool isDarkMode;
  final String? errorText;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

  const _TradeTextFieldRow({
    required this.label,
    required this.controller,
    required this.hintText,
    required this.isDarkMode,
    this.errorText,
    this.inputFormatters,
    this.keyboardType,
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
              keyboardType:
                  keyboardType ??
                  const TextInputType.numberWithOptions(decimal: true),
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
