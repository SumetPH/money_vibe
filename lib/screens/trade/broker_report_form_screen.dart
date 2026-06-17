import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/portfolio_annual_report.dart';
import '../../providers/account_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';

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
      text: r != null ? r.inflowUsd.toStringAsFixed(2) : '',
    );
    _noteController = TextEditingController(text: r?.note ?? '');
  }

  @override
  void dispose() {
    _yearController.dispose();
    _inflowController.dispose();
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

    setState(() => _isSaving = true);

    try {
      final provider = context.read<AccountProvider>();

      final report = PortfolioAnnualReport(
        id: widget.existingReport?.id ?? const Uuid().v4(),
        portfolioId: widget.portfolioId,
        year: year,
        inflowUsd: inflow,
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
              color: expenseColor,
              onPressed: _isSaving ? null : _delete,
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

              // ยอดโอนเข้าสะสม
              Container(
                color: surfaceColor,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.download, size: 18, color: incomeColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _inflowController,
                        style: TextStyle(
                          color: incomeColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          labelText: 'ยอดโอนเข้าสะสม (Total Inflow USD)',
                          labelStyle: TextStyle(color: secondaryColor),
                          hintText: '0.00',
                          hintStyle: TextStyle(color: secondaryColor),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                          ),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'กรุณาระบุยอดโอนเข้า';
                          }
                          final amount = double.tryParse(val);
                          if (amount == null) {
                            return 'ตัวเลขไม่ถูกต้อง';
                          }
                          if (amount < 0) return 'ต้องไม่ติดลบ';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ),
              _buildDivider(isDarkMode),

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

              const SizedBox(height: 24),

              // Save Button — flat, full-width, borderless row
              InkWell(
                onTap: _isSaving ? null : _save,
                child: Container(
                  color: surfaceColor,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  alignment: Alignment.center,
                  child: _isSaving
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: incomeColor,
                          ),
                        )
                      : Text(
                          'บันทึกข้อมูล',
                          style: TextStyle(
                            color: incomeColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
