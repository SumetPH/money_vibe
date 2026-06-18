import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/portfolio_annual_report.dart';
import '../../providers/account_provider.dart';
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

class BrokerReportFormScreen extends StatefulWidget {
  final String portfolioId;
  final PortfolioAnnualReport? existingReport;

  const BrokerReportFormScreen({
    super.key,
    required this.portfolioId,
    this.existingReport,
  });

  @override
  State<BrokerReportFormScreen> createState() => _BrokerReportFormScreenState();
}

class _BrokerReportFormScreenState extends State<BrokerReportFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _yearController;
  late final TextEditingController _inflowController;
  late final TextEditingController _inflowThbController;
  late final TextEditingController _dividendGrossController;
  late final TextEditingController _dividendTaxWithheldController;
  late final TextEditingController _dividendNetController;
  late final TextEditingController _remittedUsdController;
  late final TextEditingController _remittedThbController;
  late final TextEditingController _noteController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.existingReport;
    _yearController = TextEditingController(
      text: r?.year.toString() ?? DateTime.now().year.toString(),
    );
    _inflowController = TextEditingController(
      text: r != null ? _formatEditable(r.inflowUsd) : '',
    );
    _inflowThbController = TextEditingController(
      text: r != null && r.inflowThb > 0 ? _formatEditable(r.inflowThb) : '',
    );
    _dividendGrossController = TextEditingController(
      text: r != null && r.dividendGrossUsd > 0
          ? _formatEditable(r.dividendGrossUsd)
          : '',
    );
    _dividendTaxWithheldController = TextEditingController(
      text: r != null && r.dividendTaxWithheldUsd > 0
          ? _formatEditable(r.dividendTaxWithheldUsd)
          : '',
    );
    _dividendNetController = TextEditingController(
      text: r != null && r.dividendNetUsd > 0
          ? _formatEditable(r.dividendNetUsd)
          : '',
    );
    _remittedUsdController = TextEditingController(
      text: r != null && r.remittedUsd > 0
          ? _formatEditable(r.remittedUsd)
          : '',
    );
    _remittedThbController = TextEditingController(
      text: r != null && r.remittedThb > 0
          ? _formatEditable(r.remittedThb)
          : '',
    );
    _noteController = TextEditingController(text: r?.note ?? '');
  }

  @override
  void dispose() {
    _yearController.dispose();
    _inflowController.dispose();
    _inflowThbController.dispose();
    _dividendGrossController.dispose();
    _dividendTaxWithheldController.dispose();
    _dividendNetController.dispose();
    _remittedUsdController.dispose();
    _remittedThbController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final year = int.tryParse(_yearController.text.trim());
    if (year == null || year < 1900 || year > 2100) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณาระบุปีให้ถูกต้อง')));
      return;
    }

    final inflow = double.tryParse(_inflowController.text.trim()) ?? 0.0;
    final inflowThb = _parseAmount(_inflowThbController);
    final dividendGross = _parseAmount(_dividendGrossController);
    final dividendTaxWithheld = _parseAmount(_dividendTaxWithheldController);
    final dividendNet = _parseAmount(_dividendNetController);
    final remittedUsd = _parseAmount(_remittedUsdController);
    final remittedThb = _parseAmount(_remittedThbController);

    setState(() => _isSaving = true);

    try {
      final provider = context.read<AccountProvider>();

      final report = PortfolioAnnualReport(
        id: widget.existingReport?.id ?? const Uuid().v4(),
        portfolioId: widget.portfolioId,
        year: year,
        inflowUsd: inflow,
        inflowThb: inflowThb,
        dividendGrossUsd: dividendGross,
        dividendTaxWithheldUsd: dividendTaxWithheld,
        dividendNetUsd: dividendNet,
        remittedUsd: remittedUsd,
        remittedThb: remittedThb,
        note: _noteController.text.trim(),
        createdAt: widget.existingReport?.createdAt,
      );

      if (widget.existingReport == null) {
        final existingReports = provider.getPortfolioAnnualReportsForPortfolio(
          widget.portfolioId,
        );
        if (existingReports.any((r) => r.year == year)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('มีข้อมูลของปี $year อยู่แล้ว')),
          );
          setState(() => _isSaving = false);
          return;
        }
        await provider.addPortfolioAnnualReport(report);
      } else {
        await provider.updatePortfolioAnnualReport(report);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เกิดข้อผิดพลาดในการบันทึกข้อมูล')),
      );
      setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final isDarkMode = context.read<SettingsProvider>().isDarkMode;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบรายงาน'),
        content: const Text('คุณต้องการลบข้อมูลรายงานปีนี้ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: isDarkMode
                  ? AppColors.darkExpense
                  : AppColors.expense,
            ),
            child: const Text('ลบข้อมูล'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isSaving = true);
    try {
      await context.read<AccountProvider>().deletePortfolioAnnualReport(
        widget.existingReport!.id,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เกิดข้อผิดพลาดในการลบข้อมูล')),
      );
      setState(() => _isSaving = false);
    }
  }

  Widget _buildDivider(bool isDarkMode) => Divider(
    height: 1,
    color: isDarkMode ? AppColors.darkDivider : AppColors.divider,
  );

  double _parseAmount(TextEditingController controller) =>
      double.tryParse(controller.text.trim()) ?? 0.0;

  String _formatEditable(double value) {
    if (value == value.truncateToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(4).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  Widget _buildMoneyField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color iconColor,
    required Color amountColor,
    required Color surfaceColor,
    required Color secondaryColor,
    bool isRequired = false,
  }) {
    return Container(
      color: surfaceColor,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: controller,
              style: TextStyle(
                color: amountColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: TextStyle(color: secondaryColor),
                hintText: '0.00',
                hintStyle: TextStyle(color: secondaryColor),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [_decimalInputFormatter(4)],
              validator: (val) {
                if (isRequired && (val == null || val.isEmpty)) {
                  return 'กรุณาระบุยอด';
                }
                if (val == null || val.isEmpty) return null;
                final amount = double.tryParse(val);
                if (amount == null) return 'ตัวเลขไม่ถูกต้อง';
                if (amount < 0) return 'ต้องไม่ติดลบ';
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<SettingsProvider>().isDarkMode;
    final backgroundColor = isDarkMode
        ? AppColors.darkBackground
        : AppColors.background;
    final headerColor = isDarkMode ? AppColors.darkHeader : AppColors.header;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final secondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final incomeColor = isDarkMode ? AppColors.darkIncome : AppColors.income;
    final expenseColor = isDarkMode ? AppColors.darkExpense : AppColors.expense;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: headerColor,
        foregroundColor: textColor,
        elevation: 0,
        title: Text(
          widget.existingReport == null
              ? 'เพิ่มรายงาน Broker'
              : 'แก้ไขรายงาน Broker',
        ),
        actions: [
          if (widget.existingReport != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _isSaving ? null : _delete,
            ),
          AppBarActionButton(
            icon: const Icon(Icons.check),
            tooltip: 'บันทึก',
            isLoading: _isSaving,
            onPressed: _save,
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _isSaving,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              // Info section
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  'ระบบจะนำยอด Inflow ของปีที่ระบุไปตั้งเป็นโควตาเงินต้นแทนรายการ Transaction ในแอป เพื่อความแม่นยำตามข้อมูลของ Broker',
                  style: TextStyle(color: secondaryColor, fontSize: 12),
                ),
              ),

              // ปี ค.ศ.
              Container(
                color: surfaceColor,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 18, color: secondaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _yearController,
                        style: TextStyle(color: textColor, fontSize: 16),
                        decoration: InputDecoration(
                          labelText: 'ปี ค.ศ. (Year)',
                          labelStyle: TextStyle(color: secondaryColor),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'กรุณาระบุปี';
                          return null;
                        },
                        enabled: widget.existingReport == null,
                      ),
                    ),
                  ],
                ),
              ),
              _buildDivider(isDarkMode),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  'เงินทุนเติมเข้า Broker จากรายงานประจำปี',
                  style: TextStyle(
                    color: secondaryColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _buildMoneyField(
                controller: _inflowController,
                label: 'เงินทุนเติมเข้า Broker (USD)',
                icon: Icons.download,
                iconColor: incomeColor,
                amountColor: incomeColor,
                surfaceColor: surfaceColor,
                secondaryColor: secondaryColor,
                isRequired: true,
              ),
              _buildDivider(isDarkMode),
              _buildMoneyField(
                controller: _inflowThbController,
                label: 'ยอดเงินบาทที่เติมเข้า Broker (THB)',
                icon: Icons.currency_exchange_outlined,
                iconColor: incomeColor,
                amountColor: incomeColor,
                surfaceColor: surfaceColor,
                secondaryColor: secondaryColor,
              ),
              _buildDivider(isDarkMode),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  'เงินโอนกลับไทยจากรายงานประจำปี',
                  style: TextStyle(
                    color: secondaryColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _buildMoneyField(
                controller: _remittedUsdController,
                label: 'ยอดโอนกลับไทยรวม (USD)',
                icon: Icons.account_balance_outlined,
                iconColor: expenseColor,
                amountColor: expenseColor,
                surfaceColor: surfaceColor,
                secondaryColor: secondaryColor,
              ),
              _buildDivider(isDarkMode),
              _buildMoneyField(
                controller: _remittedThbController,
                label: 'ยอดเงินบาทที่ได้รับรวม (THB)',
                icon: Icons.payments_outlined,
                iconColor: incomeColor,
                amountColor: incomeColor,
                surfaceColor: surfaceColor,
                secondaryColor: secondaryColor,
              ),
              _buildDivider(isDarkMode),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  'เงินปันผลจากรายงานประจำปี',
                  style: TextStyle(
                    color: secondaryColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _buildMoneyField(
                controller: _dividendGrossController,
                label: 'ปันผลรวม (Gross Dividend USD)',
                icon: Icons.savings_outlined,
                iconColor: incomeColor,
                amountColor: incomeColor,
                surfaceColor: surfaceColor,
                secondaryColor: secondaryColor,
              ),
              _buildDivider(isDarkMode),
              _buildMoneyField(
                controller: _dividendTaxWithheldController,
                label: 'ภาษีปันผลหัก ณ ที่จ่าย (USD)',
                icon: Icons.receipt_long_outlined,
                iconColor: expenseColor,
                amountColor: expenseColor,
                surfaceColor: surfaceColor,
                secondaryColor: secondaryColor,
              ),
              _buildDivider(isDarkMode),
              _buildMoneyField(
                controller: _dividendNetController,
                label: 'ปันผลสุทธิ (Net Dividend USD)',
                icon: Icons.account_balance_wallet_outlined,
                iconColor: incomeColor,
                amountColor: incomeColor,
                surfaceColor: surfaceColor,
                secondaryColor: secondaryColor,
              ),
              _buildDivider(isDarkMode),

              const SizedBox(height: 24),

              // Note
              Container(
                color: surfaceColor,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.note_outlined, size: 18, color: secondaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _noteController,
                        style: TextStyle(color: textColor, fontSize: 16),
                        decoration: InputDecoration(
                          labelText: 'บันทึกช่วยจำ (Note)',
                          labelStyle: TextStyle(color: secondaryColor),
                          hintText: 'Optional',
                          hintStyle: TextStyle(color: secondaryColor),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
