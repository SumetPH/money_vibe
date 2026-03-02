import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/account.dart';
import '../../providers/account_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../main.dart';

class AccountFormScreen extends StatefulWidget {
  final Account? account;

  const AccountFormScreen({super.key, this.account});

  @override
  State<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends State<AccountFormScreen> {
  final _nameController = TextEditingController();
  final _initialBalanceController = TextEditingController();
  final _exchangeRateController = TextEditingController();
  final _noteController = TextEditingController();

  late AccountType _selectedType;
  late String _selectedCurrency;
  late DateTime _startDate;
  late IconData _selectedIcon;
  late Color _selectedColor;
  late bool _excludeFromNetWorth;
  late bool _isHidden;
  int? _statementDay;

  bool get _isEditing => widget.account != null;
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    final acc = widget.account;
    _nameController.text = acc?.name ?? '';
    _selectedType = acc?.type ?? AccountType.cash;
    _selectedCurrency = acc?.currency ?? 'THB';
    _startDate = acc?.startDate ?? DateTime.now();
    _selectedIcon = acc?.icon ?? Icons.account_balance_wallet;
    _selectedColor = acc?.color ?? AppColors.accountColors.first;
    _excludeFromNetWorth = acc?.excludeFromNetWorth ?? false;
    _isHidden = acc?.isHidden ?? false;
    _statementDay = acc?.statementDay;

    if (_selectedType == AccountType.portfolio) {
      _initialBalanceController.text = acc != null
          ? formatAmount(acc.cashBalance)
          : '';
      _exchangeRateController.text = acc != null
          ? acc.exchangeRate.toString()
          : '35.0';
    } else {
      _initialBalanceController.text = acc != null
          ? formatAmount(acc.initialBalance)
          : '';
      _exchangeRateController.text = '35.0';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _initialBalanceController.dispose();
    _exchangeRateController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณากรอกชื่อบัญชี')));
      return;
    }

    final balanceText = _initialBalanceController.text
        .replaceAll(',', '')
        .trim();
    final balanceValue = double.tryParse(balanceText) ?? 0;
    final exchangeRate =
        double.tryParse(_exchangeRateController.text.trim()) ?? 35.0;

    final isPortfolio = _selectedType == AccountType.portfolio;
    final initialBalance = isPortfolio ? 0.0 : balanceValue;
    final cashBalance = isPortfolio ? balanceValue : 0.0;

    final provider = context.read<AccountProvider>();

    if (_isEditing) {
      provider.updateAccount(
        widget.account!.copyWith(
          name: name,
          type: _selectedType,
          initialBalance: initialBalance,
          currency: _selectedCurrency,
          startDate: _startDate,
          icon: _selectedIcon,
          color: _selectedColor,
          excludeFromNetWorth: _excludeFromNetWorth,
          isHidden: _isHidden,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
          cashBalance: cashBalance,
          exchangeRate: exchangeRate,
          statementDay: _selectedType == AccountType.creditCard
              ? _statementDay
              : null,
        ),
      );
    } else {
      provider.addAccount(
        Account(
          id: provider.generateId(),
          name: name,
          type: _selectedType,
          initialBalance: initialBalance,
          currency: _selectedCurrency,
          startDate: _startDate,
          icon: _selectedIcon,
          color: _selectedColor,
          excludeFromNetWorth: _excludeFromNetWorth,
          isHidden: _isHidden,
          cashBalance: cashBalance,
          exchangeRate: exchangeRate,
          statementDay: _selectedType == AccountType.creditCard
              ? _statementDay
              : null,
        ),
      );
    }

    Navigator.pop(context);
  }

  void _delete() {
    showDialog(
      context: context,
      builder: (_) => Consumer<SettingsProvider>(
        builder: (context, settingsProvider, _) {
          final isDarkMode = settingsProvider.isDarkMode;
          final dialogBgColor = isDarkMode
              ? AppColors.darkSurface
              : Colors.white;
          final textColor = isDarkMode
              ? AppColors.darkTextPrimary
              : AppColors.textPrimary;

          return AlertDialog(
            backgroundColor: dialogBgColor,
            title: Text('ลบบัญชี', style: TextStyle(color: textColor)),
            content: Text(
              'คุณต้องการที่จะลบบัญชีนี้ใช่หรือไม่?',
              style: TextStyle(color: textColor),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('ยกเลิก', style: TextStyle(color: textColor)),
              ),
              TextButton(
                onPressed: () {
                  context.read<AccountProvider>().deleteAccount(
                    widget.account!.id,
                  );
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Close form
                },
                style: TextButton.styleFrom(
                  foregroundColor: isDarkMode
                      ? AppColors.darkExpense
                      : AppColors.expense,
                ),
                child: const Text('ลบ'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, _) {
        _isDarkMode = settingsProvider.isDarkMode;
        final bgColor = _isDarkMode
            ? AppColors.darkBackground
            : AppColors.background;
        final surfaceColor = _isDarkMode
            ? AppColors.darkSurface
            : AppColors.surface;
        final textPrimaryColor = _isDarkMode
            ? AppColors.darkTextPrimary
            : AppColors.textPrimary;
        final textSecondaryColor = _isDarkMode
            ? AppColors.darkTextSecondary
            : AppColors.textSecondary;
        final dividerColor = _isDarkMode
            ? AppColors.darkDivider
            : AppColors.divider;

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(_isEditing ? 'แก้ไขบัญชี' : 'เพิ่มบัญชีใหม่'),
            actions: [
              if (_isEditing)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _delete,
                  tooltip: 'ลบบัญชี',
                ),
              IconButton(icon: const Icon(Icons.check), onPressed: _save),
            ],
          ),
          body: ListView(
            children: [
              const SizedBox(height: 8),
              // Name
              _buildTextField(
                controller: _nameController,
                hintText: 'ชื่อ',
                surfaceColor: surfaceColor,
                textSecondaryColor: textSecondaryColor,
              ),
              _buildDivider(color: dividerColor),
              // Account Type
              _buildPickerRow(
                label: 'ชนิดบัญชี',
                value: _selectedType.label,
                onTap: _pickAccountType,
                surfaceColor: surfaceColor,
                textPrimaryColor: textPrimaryColor,
                textSecondaryColor: textSecondaryColor,
              ),
              _buildDivider(color: dividerColor),
              // Initial Balance / Cash Balance
              _buildBalanceField(
                surfaceColor: surfaceColor,
                textSecondaryColor: textSecondaryColor,
              ),
              _buildDivider(color: dividerColor),
              // Exchange Rate (portfolio only)
              if (_selectedType == AccountType.portfolio) ...[
                _buildExchangeRateField(
                  surfaceColor: surfaceColor,
                  textSecondaryColor: textSecondaryColor,
                ),
                _buildDivider(color: dividerColor),
              ],
              // Currency
              _buildPickerRow(
                label: 'สกุลเงิน',
                value: 'สกุลเงินหลัก ($_selectedCurrency)',
                onTap: () {},
                surfaceColor: surfaceColor,
                textPrimaryColor: textPrimaryColor,
                textSecondaryColor: textSecondaryColor,
              ),
              _buildDivider(color: dividerColor),
              // Start Date
              _buildPickerRow(
                label: 'เริ่มวันที่',
                value: _formatThaiDate(_startDate),
                onTap: _pickDate,
                surfaceColor: surfaceColor,
                textPrimaryColor: textPrimaryColor,
                textSecondaryColor: textSecondaryColor,
              ),
              _buildDivider(color: dividerColor),
              // Icon
              _buildIconRow(
                surfaceColor: surfaceColor,
                textSecondaryColor: textSecondaryColor,
              ),
              _buildDivider(color: dividerColor),
              // Color
              _buildColorRow(
                surfaceColor: surfaceColor,
                textSecondaryColor: textSecondaryColor,
              ),
              const SizedBox(height: 8),
              // Credit Card Statement Day
              if (_selectedType == AccountType.creditCard) ...[
                _buildDivider(color: dividerColor),
                _buildStatementDayPicker(
                  surfaceColor: surfaceColor,
                  textPrimaryColor: textPrimaryColor,
                  textSecondaryColor: textSecondaryColor,
                ),
              ],
              // Switches
              const SizedBox(height: 8),
              _buildSwitchRow(
                label: 'ไม่รวมในทรัพย์สินสุทธิ',
                value: _excludeFromNetWorth,
                onChanged: (v) => setState(() => _excludeFromNetWorth = v),
                surfaceColor: surfaceColor,
                textSecondaryColor: textSecondaryColor,
              ),
              _buildDivider(color: dividerColor),
              _buildSwitchRow(
                label: 'ซ่อนบัญชีนี้',
                value: _isHidden,
                onChanged: (v) => setState(() => _isHidden = v),
                surfaceColor: surfaceColor,
                textSecondaryColor: textSecondaryColor,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required Color surfaceColor,
    required Color textSecondaryColor,
  }) {
    return Container(
      color: surfaceColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: textSecondaryColor),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          filled: false,
        ),
        style: TextStyle(fontSize: 15, color: textSecondaryColor),
      ),
    );
  }

  Widget _buildBalanceField({
    required Color surfaceColor,
    required Color textSecondaryColor,
  }) {
    return Container(
      color: surfaceColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              _selectedType == AccountType.portfolio
                  ? 'เงินสดใน Broker'
                  : 'ยอดเริ่มต้น',
              style: TextStyle(fontSize: 15, color: textSecondaryColor),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _initialBalanceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[-0-9.,]')),
              ],
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: _selectedType == AccountType.portfolio
                    ? '0'
                    : 'ยอดเริ่มต้น',
                hintStyle: TextStyle(color: textSecondaryColor),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                filled: false,
              ),
              style: TextStyle(fontSize: 15, color: textSecondaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExchangeRateField({
    required Color surfaceColor,
    required Color textSecondaryColor,
  }) {
    return Container(
      color: surfaceColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              'USD/THB',
              style: TextStyle(fontSize: 15, color: textSecondaryColor),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _exchangeRateController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: '35.0',
                hintStyle: TextStyle(color: textSecondaryColor),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                filled: false,
              ),
              style: TextStyle(fontSize: 15, color: textSecondaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerRow({
    required String label,
    required String value,
    required VoidCallback onTap,
    required Color surfaceColor,
    required Color textPrimaryColor,
    required Color textSecondaryColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: surfaceColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 15, color: textSecondaryColor),
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(fontSize: 15, color: textPrimaryColor),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: textSecondaryColor, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildIconRow({
    required Color surfaceColor,
    required Color textSecondaryColor,
  }) {
    return InkWell(
      onTap: _pickIcon,
      child: Container(
        color: surfaceColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Text(
              'ไอคอน',
              style: TextStyle(fontSize: 15, color: textSecondaryColor),
            ),
            const Spacer(),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _selectedColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_selectedIcon, color: _selectedColor, size: 26),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: textSecondaryColor, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildColorRow({
    required Color surfaceColor,
    required Color textSecondaryColor,
  }) {
    return InkWell(
      onTap: _pickColor,
      child: Container(
        color: surfaceColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Text(
              'สี',
              style: TextStyle(fontSize: 15, color: textSecondaryColor),
            ),
            const Spacer(),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _selectedColor,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: textSecondaryColor, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color surfaceColor,
    required Color textSecondaryColor,
  }) {
    return Container(
      color: surfaceColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 15, color: textSecondaryColor),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildDivider({required Color color}) =>
      Divider(height: 1, indent: 16, color: color);

  Widget _buildStatementDayPicker({
    required Color surfaceColor,
    required Color textPrimaryColor,
    required Color textSecondaryColor,
  }) {
    return InkWell(
      onTap: _pickStatementDay,
      child: Container(
        color: surfaceColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text(
              'วันสรุปยอด',
              style: TextStyle(fontSize: 15, color: textSecondaryColor),
            ),
            const Spacer(),
            Text(
              _statementDay != null ? 'วันที่ $_statementDay' : 'ไม่ระบุ',
              style: TextStyle(fontSize: 15, color: textPrimaryColor),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: textSecondaryColor, size: 18),
          ],
        ),
      ),
    );
  }

  void _pickStatementDay() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? AppColors.darkSurface : Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Consumer<SettingsProvider>(
        builder: (context, settingsProvider, _) {
          final isDarkMode = settingsProvider.isDarkMode;
          final surfaceColor = isDarkMode
              ? AppColors.darkSurface
              : AppColors.surface;
          final textPrimaryColor = isDarkMode
              ? AppColors.darkTextPrimary
              : AppColors.textPrimary;
          final textSecondaryColor = isDarkMode
              ? AppColors.darkTextSecondary
              : AppColors.textSecondary;
          final headerColor = isDarkMode
              ? AppColors.darkIncome
              : AppColors.header;
          final handleColor = isDarkMode
              ? AppColors.darkDivider
              : Colors.grey.shade300;

          return SafeArea(
            child: Container(
              color: surfaceColor,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: handleColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'เลือกวันสรุปยอด',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: textPrimaryColor,
                      ),
                    ),
                  ),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                      itemCount: 31,
                      itemBuilder: (_, i) {
                        final day = i + 1;
                        final selected = _statementDay == day;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _statementDay = day);
                            Navigator.pop(context);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: selected
                                  ? headerColor.withValues(alpha: 0.2)
                                  : surfaceColor,
                              borderRadius: BorderRadius.circular(8),
                              border: selected
                                  ? Border.all(color: headerColor, width: 2)
                                  : Border.all(
                                      color: textSecondaryColor.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                            ),
                            child: Center(
                              child: Text(
                                '$day',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: selected
                                      ? headerColor
                                      : textPrimaryColor,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (_statementDay != null)
                    ListTile(
                      tileColor: surfaceColor,
                      title: Text(
                        'ลบวันสรุปยอด',
                        style: TextStyle(
                          color: AppColors.getAmountColor(-1, isDarkMode),
                        ),
                      ),
                      leading: Icon(
                        Icons.delete_outline,
                        color: AppColors.getAmountColor(-1, isDarkMode),
                      ),
                      onTap: () {
                        setState(() => _statementDay = null);
                        Navigator.pop(context);
                      },
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _pickAccountType() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? AppColors.darkSurface : Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Consumer<SettingsProvider>(
        builder: (context, settingsProvider, _) {
          final surfaceColor = isDarkMode
              ? AppColors.darkSurface
              : AppColors.surface;
          final textPrimaryColor = isDarkMode
              ? AppColors.darkTextPrimary
              : AppColors.textPrimary;
          final headerColor = isDarkMode
              ? AppColors.darkIncome
              : AppColors.header;
          final handleColor = isDarkMode
              ? AppColors.darkDivider
              : Colors.grey.shade300;

          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: handleColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                ...AccountType.values.map(
                  (type) => ListTile(
                    tileColor: surfaceColor,
                    title: Text(
                      type.label,
                      style: TextStyle(color: textPrimaryColor),
                    ),
                    trailing: _selectedType == type
                        ? Icon(Icons.check, color: headerColor)
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedType = type;
                        // Clear balance field when switching type
                        _initialBalanceController.clear();
                      });
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  void _pickIcon() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? AppColors.darkSurface : Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Consumer<SettingsProvider>(
        builder: (context, settingsProvider, _) {
          final isDarkMode = settingsProvider.isDarkMode;
          final bgColor = isDarkMode
              ? AppColors.darkBackground
              : AppColors.background;
          final textPrimaryColor = isDarkMode
              ? AppColors.darkTextPrimary
              : AppColors.textPrimary;
          final textSecondaryColor = isDarkMode
              ? AppColors.darkTextSecondary
              : AppColors.textSecondary;
          final handleColor = isDarkMode
              ? AppColors.darkDivider
              : Colors.grey.shade300;

          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: handleColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'เลือกไอคอน',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: textPrimaryColor,
                    ),
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                        ),
                    itemCount: AppColors.accountIcons.length,
                    itemBuilder: (_, i) {
                      final icon = AppColors.accountIcons[i];
                      final selected = icon == _selectedIcon;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedIcon = icon);
                          Navigator.pop(context);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: selected
                                ? _selectedColor.withValues(alpha: 0.2)
                                : bgColor,
                            borderRadius: BorderRadius.circular(10),
                            border: selected
                                ? Border.all(color: _selectedColor, width: 2)
                                : null,
                          ),
                          child: Icon(
                            icon,
                            color: selected
                                ? _selectedColor
                                : textSecondaryColor,
                            size: 24,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _pickColor() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? AppColors.darkSurface : Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Consumer<SettingsProvider>(
        builder: (context, settingsProvider, _) {
          final isDarkMode = settingsProvider.isDarkMode;
          final textPrimaryColor = isDarkMode
              ? AppColors.darkTextPrimary
              : AppColors.textPrimary;
          final handleColor = isDarkMode
              ? AppColors.darkDivider
              : Colors.grey.shade300;

          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: handleColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'เลือกสี',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: textPrimaryColor,
                    ),
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                        ),
                    itemCount: AppColors.accountColors.length,
                    itemBuilder: (_, i) {
                      final color = AppColors.accountColors[i];
                      final selected =
                          color.toARGB32() == _selectedColor.toARGB32();
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedColor = color);
                          Navigator.pop(context);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(10),
                            border: selected
                                ? Border.all(color: Colors.black45, width: 2)
                                : null,
                          ),
                          child: selected
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 20,
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatThaiDate(DateTime date) {
    const thaiMonths = [
      'มกราคม',
      'กุมภาพันธ์',
      'มีนาคม',
      'เมษายน',
      'พฤษภาคม',
      'มิถุนายน',
      'กรกฎาคม',
      'สิงหาคม',
      'กันยายน',
      'ตุลาคม',
      'พฤศจิกายน',
      'ธันวาคม',
    ];
    return '${date.day} ${thaiMonths[date.month - 1]} ${date.year}';
  }
}
