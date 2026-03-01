import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/account.dart';
import '../../providers/account_provider.dart';
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
  final _noteController = TextEditingController();

  late AccountType _selectedType;
  late String _selectedCurrency;
  late DateTime _startDate;
  late IconData _selectedIcon;
  late Color _selectedColor;
  late bool _excludeFromNetWorth;
  late bool _isHidden;

  bool get _isEditing => widget.account != null;

  @override
  void initState() {
    super.initState();
    final acc = widget.account;
    _nameController.text = acc?.name ?? '';
    _initialBalanceController.text = acc != null
        ? formatAmount(acc.initialBalance)
        : '';
    _selectedType = acc?.type ?? AccountType.cash;
    _selectedCurrency = acc?.currency ?? 'THB';
    _startDate = acc?.startDate ?? DateTime.now();
    _selectedIcon = acc?.icon ?? Icons.account_balance_wallet;
    _selectedColor = acc?.color ?? AppColors.accountColors.first;
    _excludeFromNetWorth = acc?.excludeFromNetWorth ?? false;
    _isHidden = acc?.isHidden ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _initialBalanceController.dispose();
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
    final initialBalance = double.tryParse(balanceText) ?? 0;

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
        ),
      );
    }

    Navigator.pop(context);
  }

  void _delete() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ลบบัญชี'),
        content: const Text('คุณต้องการที่จะลบบัญชีนี้ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () {
              context.read<AccountProvider>().deleteAccount(widget.account!.id);
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close form
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.expense),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
          _buildTextField(controller: _nameController, hintText: 'ชื่อ'),
          _buildDivider(),
          // Account Type
          _buildPickerRow(
            label: 'ชนิดบัญชี',
            value: _selectedType.label,
            onTap: _pickAccountType,
          ),
          _buildDivider(),
          // Initial Balance
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const SizedBox(
                  width: 130,
                  child: Text(
                    'ยอดเริ่มต้น',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                    ),
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
                    decoration: const InputDecoration(
                      hintText: 'ยอดเริ่มต้น',
                      hintStyle: TextStyle(color: AppColors.textSecondary),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
          _buildDivider(),
          // Currency
          _buildPickerRow(
            label: 'สกุลเงิน',
            value: 'สกุลเงินหลัก ($_selectedCurrency)',
            onTap: () {},
          ),
          _buildDivider(),
          // Start Date
          _buildPickerRow(
            label: 'เริ่มวันที่',
            value: _formatThaiDate(_startDate),
            onTap: _pickDate,
          ),
          _buildDivider(),
          // Icon
          _buildIconRow(),
          _buildDivider(),
          // Color
          _buildColorRow(),
          const SizedBox(height: 8),
          // Switches
          _buildSwitchRow(
            label: 'ไม่รวมในทรัพย์สินสุทธิ',
            value: _excludeFromNetWorth,
            onChanged: (v) => setState(() => _excludeFromNetWorth = v),
          ),
          _buildDivider(),
          _buildSwitchRow(
            label: 'ซ่อนบัญชีนี้',
            value: _isHidden,
            onChanged: (v) => setState(() => _isHidden = v),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
  }) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: AppColors.textSecondary),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        style: const TextStyle(fontSize: 15),
      ),
    );
  }

  Widget _buildPickerRow({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: AppColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconRow() {
    return InkWell(
      onTap: _pickIcon,
      child: Container(
        color: AppColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Text(
              'ไอคอน',
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
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
            const Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorRow() {
    return InkWell(
      onTap: _pickColor,
      child: Container(
        color: AppColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Text(
              'สี',
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
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
            const Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildDivider() => const Divider(height: 1, indent: 16);

  void _pickAccountType() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: AccountType.values
              .map(
                (type) => ListTile(
                  title: Text(type.label),
                  trailing: _selectedType == type
                      ? const Icon(Icons.check, color: AppColors.header)
                      : null,
                  onTap: () {
                    setState(() => _selectedType = type);
                    Navigator.pop(context);
                  },
                ),
              )
              .toList(),
        ),
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
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'เลือกไอคอน',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
            SizedBox(
              height: 250,
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: selected
                            ? Border.all(color: _selectedColor, width: 2)
                            : null,
                      ),
                      child: Icon(
                        icon,
                        color: selected
                            ? _selectedColor
                            : AppColors.textSecondary,
                        size: 24,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _pickColor() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'เลือกสี',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
            SizedBox(
              height: 200,
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
    return '${date.day} ${thaiMonths[date.month - 1]} ${date.year + 543}';
  }
}
