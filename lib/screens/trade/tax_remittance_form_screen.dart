import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/account.dart';
import '../../models/tax_remittance.dart';
import '../../providers/settings_provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';

typedef SaveTaxRemittanceCallback =
    Future<void> Function(TaxRemittance remittance);

TextInputFormatter _decimalInputFormatter(int maxDecimals) =>
    TextInputFormatter.withFunction((oldValue, newValue) {
      final text = newValue.text;
      if (text.isEmpty) return newValue;

      final match = RegExp('^\\d+(\\.\\d{0,$maxDecimals})?\$').hasMatch(text);
      return match ? newValue : oldValue;
    });

class TaxRemittanceFormScreen extends StatefulWidget {
  final List<Account> portfolios;
  final TaxRemittance? existing;
  final String Function() generateId;
  final SaveTaxRemittanceCallback onSave;

  const TaxRemittanceFormScreen({
    super.key,
    required this.portfolios,
    required this.existing,
    required this.generateId,
    required this.onSave,
  });

  @override
  State<TaxRemittanceFormScreen> createState() =>
      _TaxRemittanceFormScreenState();
}

class _TaxRemittanceFormScreenState extends State<TaxRemittanceFormScreen> {
  final _amountUsdController = TextEditingController();
  final _fxRateController = TextEditingController();
  final _principalController = TextEditingController();
  final _taxableController = TextEditingController();
  final _taxYearController = TextEditingController();
  final _noteController = TextEditingController();

  String? _portfolioId;
  DateTime _remittedAt = DateTime.now();
  bool _isSaving = false;
  String? _portfolioError;
  String? _amountUsdError;
  String? _fxRateError;
  String? _allocationError;
  String? _taxYearError;

  bool _isAllocationManuallyEdited = false;

  bool get _isEditing => widget.existing != null;
  int get _selectedPrincipalPoolYear =>
      int.tryParse(_taxYearController.text.trim()) ?? _remittedAt.year;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _portfolioId =
        existing?.portfolioId ??
        (widget.portfolios.isNotEmpty ? widget.portfolios.first.id : null);

    if (existing != null) {
      _remittedAt = existing.remittedAt;
      _amountUsdController.text = _formatEditable(existing.amountUsd, 4);
      _fxRateController.text = _formatEditable(existing.fxRate, 6);
      _noteController.text = existing.note;
      final principal = existing.allocations
          .where(
            (allocation) =>
                allocation.bucketType == TaxRemittanceBucketType.principal,
          )
          .fold(0.0, (sum, allocation) => sum + allocation.amountUsd);
      final taxable = existing.allocations
          .where(
            (allocation) =>
                allocation.bucketType != TaxRemittanceBucketType.principal,
          )
          .fold(0.0, (sum, allocation) => sum + allocation.amountUsd);
      int? taxYear;
      for (final allocation in existing.allocations) {
        if (allocation.taxYear != null) {
          taxYear = allocation.taxYear;
          break;
        }
      }
      if (principal > 0) {
        _principalController.text = _formatEditable(principal, 4);
      }
      if (taxable > 0) {
        _taxableController.text = _formatEditable(taxable, 4);
      }
      if (taxYear != null) {
        _taxYearController.text = taxYear.toString();
      }
      _isAllocationManuallyEdited = true;
    } else {
      _taxYearController.text = DateTime.now().year.toString();
    }

    _amountUsdController.addListener(_syncAllocationDefault);
  }

  @override
  void dispose() {
    _amountUsdController.dispose();
    _fxRateController.dispose();
    _principalController.dispose();
    _taxableController.dispose();
    _taxYearController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _syncAllocationDefault() {
    if (_isAllocationManuallyEdited) return;

    final amountText = _amountUsdController.text.trim();
    if (amountText.isEmpty) {
      _principalController.clear();
      _taxableController.clear();
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) return;

    if (_portfolioId == null) return;

    final txProvider = Provider.of<TransactionProvider>(context, listen: false);
    final accProvider = Provider.of<AccountProvider>(context, listen: false);

    final remainingPrincipalPool = accProvider.getRemainingPrincipalPool(
      _portfolioId!,
      txProvider.transactions,
      excludeRemittanceId: widget.existing?.id,
      targetYear: _selectedPrincipalPoolYear,
    );

    if (amount <= remainingPrincipalPool) {
      _principalController.text = _formatEditable(amount, 4);
      _taxableController.text = '0';
    } else {
      _principalController.text = _formatEditable(remainingPrincipalPool, 4);
      _taxableController.text = _formatEditable(
        amount - remainingPrincipalPool,
        4,
      );
    }
  }

  Future<void> _pickRemittedAt() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _remittedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _remittedAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _remittedAt.hour,
        _remittedAt.minute,
      );
      if (_taxYearController.text.trim().isEmpty) {
        _taxYearController.text = picked.year.toString();
      }
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
      _principalController.clear();
      _taxableController.clear();
      _isAllocationManuallyEdited = false;
      _syncAllocationDefault();
    });
  }

  Future<void> _submit() async {
    final amountUsd = double.tryParse(_amountUsdController.text.trim());
    final fxRate = double.tryParse(_fxRateController.text.trim());
    final principal = double.tryParse(_principalController.text.trim()) ?? 0;
    final taxable = double.tryParse(_taxableController.text.trim()) ?? 0;
    final taxYear = int.tryParse(_taxYearController.text.trim());

    setState(() {
      _portfolioError = null;
      _amountUsdError = null;
      _fxRateError = null;
      _allocationError = null;
      _taxYearError = null;
    });

    var hasError = false;
    if (_portfolioId == null || _portfolioId!.isEmpty) {
      _portfolioError = 'ต้องเลือกพอร์ต';
      hasError = true;
    }
    if (amountUsd == null || amountUsd <= 0) {
      _amountUsdError = 'ต้องมากกว่า 0';
      hasError = true;
    }
    if (fxRate == null || fxRate <= 0) {
      _fxRateError = 'ต้องมากกว่า 0';
      hasError = true;
    }
    if (taxYear == null || taxYear < 1900 || taxYear > 2100) {
      _taxYearError = 'กรุณาระบุปีให้ถูกต้อง';
      hasError = true;
    }
    if (principal < 0 || taxable < 0) {
      _allocationError = 'ยอด allocation ต้องไม่ติดลบ';
      hasError = true;
    } else if (amountUsd != null && principal + taxable > amountUsd + 0.0001) {
      _allocationError = 'เงินต้น + เงินได้ ต้องไม่เกินยอดโอนกลับ';
      hasError = true;
    }
    if (_portfolioId != null) {
      final txProvider = context.read<TransactionProvider>();
      final accProvider = context.read<AccountProvider>();
      final remainingPrincipalPool = accProvider.getRemainingPrincipalPool(
        _portfolioId!,
        txProvider.transactions,
        excludeRemittanceId: widget.existing?.id,
        targetYear: _selectedPrincipalPoolYear,
      );
      if (principal > remainingPrincipalPool + 0.0001) {
        _allocationError = 'เงินต้นต้องไม่เกินโควตาเงินต้นคงเหลือ';
        hasError = true;
      }
    }

    if (hasError) {
      setState(() {});
      return;
    }

    final id = widget.existing?.id ?? widget.generateId();
    final allocations = <TaxRemittanceAllocation>[];
    if (principal > 0) {
      allocations.add(
        TaxRemittanceAllocation(
          id: widget.generateId(),
          remittanceId: id,
          bucketType: TaxRemittanceBucketType.principal,
          taxYear: taxYear,
          amountUsd: principal,
        ),
      );
    }
    if (taxable > 0) {
      allocations.add(
        TaxRemittanceAllocation(
          id: widget.generateId(),
          remittanceId: id,
          bucketType: TaxRemittanceBucketType.realizedGain,
          taxYear: taxYear,
          amountUsd: taxable,
        ),
      );
    }

    final remittance = TaxRemittance(
      id: id,
      portfolioId: _portfolioId!,
      remittedAt: _remittedAt,
      amountUsd: amountUsd!,
      fxRate: fxRate!,
      note: _noteController.text.trim(),
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
      allocations: allocations,
    );

    setState(() => _isSaving = true);
    try {
      await widget.onSave(remittance);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<SettingsProvider>().isDarkMode;
    final transactionProvider = context.watch<TransactionProvider>();
    final accountProvider = context.watch<AccountProvider>();

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

    final amountUsd = double.tryParse(_amountUsdController.text.trim()) ?? 0;
    final fxRate = double.tryParse(_fxRateController.text.trim()) ?? 0;
    final taxable = double.tryParse(_taxableController.text.trim()) ?? 0;

    double remainingPrincipalPool = 0.0;
    if (_portfolioId != null) {
      remainingPrincipalPool = accountProvider.getRemainingPrincipalPool(
        _portfolioId!,
        transactionProvider.transactions,
        excludeRemittanceId: widget.existing?.id,
        targetYear: _selectedPrincipalPoolYear,
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(_isEditing ? 'แก้ไขโอนกลับไทย' : 'โอนเงินกลับไทย'),
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
              child: ListTile(
                title: Text('พอร์ต', style: TextStyle(color: secondaryColor)),
                subtitle: Text(
                  selectedPortfolio?.name ?? 'เลือกพอร์ต',
                  style: TextStyle(color: textColor, fontSize: 16),
                ),
                trailing: Icon(
                  Icons.keyboard_arrow_down,
                  color: secondaryColor,
                ),
                onTap: () => _pickPortfolio(isDarkMode),
              ),
            ),
            if (_portfolioError != null)
              _ErrorText(text: _portfolioError!, isDarkMode: isDarkMode),
            const SizedBox(height: 12),
            _RemittanceNumberFieldRow(
              label: 'ยอดโอนกลับ (USD)',
              controller: _amountUsdController,
              hintText: '0.00',
              isDarkMode: isDarkMode,
              errorText: _amountUsdError,
              inputFormatters: [_decimalInputFormatter(4)],
              onChanged: (_) {
                _isAllocationManuallyEdited = false;
                _syncAllocationDefault();
                setState(() {});
              },
            ),
            _buildDivider(isDarkMode),
            _RemittanceNumberFieldRow(
              label: 'อัตราแลกเปลี่ยน',
              controller: _fxRateController,
              hintText: '35.00',
              isDarkMode: isDarkMode,
              errorText: _fxRateError,
              inputFormatters: [_decimalInputFormatter(6)],
              onChanged: (_) => setState(() {}),
            ),
            _buildDivider(isDarkMode),
            ListTile(
              tileColor: isDarkMode ? AppColors.darkSurface : AppColors.surface,
              title: Text(
                'วันที่โอนกลับไทย',
                style: TextStyle(color: textColor),
              ),
              subtitle: Text(
                _formatDate(_remittedAt),
                style: TextStyle(color: secondaryColor),
              ),
              trailing: Icon(Icons.calendar_today, color: secondaryColor),
              onTap: _pickRemittedAt,
            ),
            Row(
              children: [
                Expanded(
                  child: _SectionLabel(
                    text:
                        'Allocation (โควตาเงินต้นคงเหลือ: \$${_formatAmount(remainingPrincipalPool)} USD)',
                    isDarkMode: isDarkMode,
                  ),
                ),
              ],
            ),
            _RemittanceNumberFieldRow(
              label: 'เงินต้น (USD)',
              controller: _principalController,
              hintText: '0.00',
              isDarkMode: isDarkMode,
              inputFormatters: [_decimalInputFormatter(4)],
              onChanged: (_) {
                if (_principalController.text.trim().isEmpty &&
                    _taxableController.text.trim().isEmpty) {
                  _isAllocationManuallyEdited = false;
                  _syncAllocationDefault();
                } else {
                  _isAllocationManuallyEdited = true;
                }
                setState(() {});
              },
            ),
            _buildDivider(isDarkMode),
            _RemittanceNumberFieldRow(
              label: 'เงินได้/กำไร (USD)',
              controller: _taxableController,
              hintText: '0.00',
              isDarkMode: isDarkMode,
              inputFormatters: [_decimalInputFormatter(4)],
              onChanged: (_) {
                if (_principalController.text.trim().isEmpty &&
                    _taxableController.text.trim().isEmpty) {
                  _isAllocationManuallyEdited = false;
                  _syncAllocationDefault();
                } else {
                  _isAllocationManuallyEdited = true;
                }
                setState(() {});
              },
            ),
            _buildDivider(isDarkMode),
            _RemittanceNumberFieldRow(
              label: 'ปีที่เงินได้ก้อนนี้เกิด',
              controller: _taxYearController,
              hintText: 'ปี',
              isDarkMode: isDarkMode,
              keyboardType: TextInputType.number,
              errorText: _taxYearError,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) {
                _isAllocationManuallyEdited = false;
                _syncAllocationDefault();
                setState(() {});
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Text(
                'ใช้ระบุว่ากำไรหรือเงินได้ส่วนนี้เกิดในปีไหน แม้จะโอนกลับไทยคนละปี',
                style: TextStyle(color: secondaryColor, fontSize: 12),
              ),
            ),
            if (_allocationError != null)
              _ErrorText(text: _allocationError!, isDarkMode: isDarkMode),
            const SizedBox(height: 12),
            _RemittanceTextFieldRow(
              label: 'Note',
              controller: _noteController,
              hintText: 'Optional',
              isDarkMode: isDarkMode,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                'ประมาณการ taxable: ${_formatAmount(taxable)} USD / ${_formatAmount(taxable * fxRate)} THB\nยอดโอนรวม: ${_formatAmount(amountUsd)} USD / ${_formatAmount(amountUsd * fxRate)} THB',
                textAlign: TextAlign.right,
                style: TextStyle(color: secondaryColor, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDarkMode) => Divider(
    height: 1,
    color: isDarkMode ? AppColors.darkDivider : AppColors.divider,
  );

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

  String _formatAmount(double value) => value.toStringAsFixed(2);
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final bool isDarkMode;

  const _SectionLabel({required this.text, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final color = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  final String text;
  final bool isDarkMode;

  const _ErrorText({required this.text, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Text(
        text,
        textAlign: TextAlign.right,
        style: TextStyle(
          color: isDarkMode ? AppColors.darkExpense : AppColors.expense,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _RemittanceNumberFieldRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hintText;
  final bool isDarkMode;
  final String? errorText;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final TextInputType keyboardType;

  const _RemittanceNumberFieldRow({
    required this.label,
    required this.controller,
    required this.hintText,
    required this.isDarkMode,
    this.errorText,
    this.inputFormatters,
    this.onChanged,
    this.keyboardType = const TextInputType.numberWithOptions(decimal: true),
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
              keyboardType: keyboardType,
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

class _RemittanceTextFieldRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hintText;
  final bool isDarkMode;

  const _RemittanceTextFieldRow({
    required this.label,
    required this.controller,
    required this.hintText,
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
