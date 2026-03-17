import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/recurring_transaction.dart';
import '../../models/transaction.dart';
import '../../models/account.dart';
import '../../models/category.dart';
import '../../providers/recurring_transaction_provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';

class RecurringFormScreen extends StatefulWidget {
  final RecurringTransaction? recurring;

  const RecurringFormScreen({super.key, this.recurring});

  @override
  State<RecurringFormScreen> createState() => _RecurringFormScreenState();
}

class _RecurringFormScreenState extends State<RecurringFormScreen> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  late TransactionType _type;
  late IconData _icon;
  late Color _color;
  late int _dayOfMonth; // 0 = สิ้นเดือน
  late DateTime _startDate;
  DateTime? _endDate;
  String? _accountId;
  String? _toAccountId;
  String? _debtAccountId; // สำหรับชำระหนี้สิน
  String? _categoryId;
  late bool _isHidden;

  bool get _isEditing => widget.recurring != null;

  @override
  void initState() {
    super.initState();
    final r = widget.recurring;
    _nameController.text = r?.name ?? '';
    _amountController.text = r != null && r.amount > 0
        ? r.amount.toStringAsFixed(2)
        : '';
    _noteController.text = r?.note ?? '';
    _type = r?.transactionType ?? TransactionType.expense;
    _icon = r?.icon ?? Icons.repeat;
    _color = r?.color ?? AppColors.accountColors.first;
    _dayOfMonth = r?.dayOfMonth ?? DateTime.now().day;
    _startDate = r?.startDate ?? DateTime.now();
    _endDate = r?.endDate;
    _accountId = r?.accountId;
    _toAccountId = r?.toAccountId;
    _debtAccountId = _type.requiresDebtAccount ? r?.toAccountId : null;
    _categoryId = r?.categoryId;
    _isHidden = r?.isHidden ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณากรอกชื่อรายการ')));
      return;
    }
    final rawAmount = _amountController.text.replaceAll(',', '').trim();
    final amount = double.tryParse(rawAmount) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณากรอกจำนวนเงิน')));
      return;
    }
    if (_accountId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณาเลือกบัญชี')));
      return;
    }
    // Validate debt account for debtRepay type
    if (_type.requiresDebtAccount && _debtAccountId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณาเลือกบัญชีหนี้สิน')));
      return;
    }

    final provider = context.read<RecurringTransactionProvider>();
    final note = _noteController.text.trim().isEmpty
        ? null
        : _noteController.text.trim();

    final toAccountId = _type.requiresDebtAccount
        ? _debtAccountId
        : _toAccountId;

    if (_isEditing) {
      provider.updateRecurring(
        widget.recurring!.copyWith(
          name: name,
          icon: _icon,
          color: _color,
          startDate: _startDate,
          endDate: _endDate,
          clearEndDate: _endDate == null,
          dayOfMonth: _dayOfMonth,
          transactionType: _type,
          amount: amount,
          accountId: _accountId!,
          toAccountId: toAccountId,
          clearToAccountId: toAccountId == null,
          categoryId: _type.supportsCategory ? _categoryId : null,
          clearCategoryId: _categoryId == null,
          note: note,
          clearNote: note == null,
          isHidden: _isHidden,
        ),
      );
    } else {
      provider.addRecurring(
        RecurringTransaction(
          id: provider.generateId(),
          name: name,
          icon: _icon,
          color: _color,
          startDate: _startDate,
          endDate: _endDate,
          dayOfMonth: _dayOfMonth,
          transactionType: _type,
          amount: amount,
          accountId: _accountId!,
          toAccountId: toAccountId,
          categoryId: _type.supportsCategory ? _categoryId : null,
          note: note,
          isHidden: _isHidden,
        ),
      );
    }
    Navigator.pop(context);
  }

  void _delete() {
    showDialog(
      context: context,
      builder: (_) => Consumer<SettingsProvider>(
        builder: (context, sp, _) {
          final isDark = sp.isDarkMode;
          return AlertDialog(
            backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
            title: Text(
              'ลบรายการประจำ',
              style: TextStyle(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
            ),
            content: Text(
              'คุณต้องการลบรายการประจำนี้ใช่หรือไม่?',
              style: TextStyle(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'ยกเลิก',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: isDark
                      ? AppColors.darkExpense
                      : AppColors.expense,
                ),
                onPressed: () {
                  context.read<RecurringTransactionProvider>().deleteRecurring(
                    widget.recurring!.id,
                  );
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
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
    return Consumer3<AccountProvider, CategoryProvider, SettingsProvider>(
      builder: (context, accountProvider, catProvider, sp, _) {
        final isDark = sp.isDarkMode;
        final bgColor = isDark
            ? AppColors.darkBackground
            : AppColors.background;
        final surfaceColor = isDark ? AppColors.darkSurface : AppColors.surface;
        final textPrimary = isDark
            ? AppColors.darkTextPrimary
            : AppColors.textPrimary;
        final textSecondary = isDark
            ? AppColors.darkTextSecondary
            : AppColors.textSecondary;
        final dividerColor = isDark ? AppColors.darkDivider : AppColors.divider;

        final accounts = switch (_type) {
          TransactionType.debtTransfer => accountProvider.visibleAccounts
              .where(
                (a) =>
                    (a.type == AccountType.debt ||
                        a.type == AccountType.creditCard) &&
                    a.type != AccountType.portfolio,
              )
              .toList(),
          TransactionType.income ||
          TransactionType.expense ||
          TransactionType.debtRepay => accountProvider.visibleAccounts
              .where(
                (a) =>
                    a.type != AccountType.debt && a.type != AccountType.portfolio,
              )
              .toList(),
          _ => accountProvider.visibleAccounts,
        };
        final selectedAccount = _accountId != null
            ? accountProvider.findById(_accountId!)
            : null;
        final selectedToAccount = _toAccountId != null
            ? accountProvider.findById(_toAccountId!)
            : null;
        final selectedDebtAccount = _debtAccountId != null
            ? accountProvider.findById(_debtAccountId!)
            : null;
        final categories = _type == TransactionType.income
            ? catProvider.incomeCategories
            : catProvider.expenseCategories;
        final selectedCategory = _categoryId != null
            ? catProvider.findById(_categoryId!)
            : null;

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(_isEditing ? 'แก้ไขรายการประจำ' : 'เพิ่มรายการประจำ'),
            actions: [
              if (_isEditing)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _delete,
                ),
              IconButton(icon: const Icon(Icons.check), onPressed: _save),
            ],
          ),
          body: ListView(
            children: [
              const SizedBox(height: 8),

              // ── Name ──────────────────────────────────────────────────────
              Container(
                color: surfaceColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'ชื่อรายการ',
                    hintStyle: TextStyle(color: textSecondary),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  style: TextStyle(fontSize: 16, color: textPrimary),
                ),
              ),
              Divider(height: 1, color: dividerColor),

              // ── Amount ────────────────────────────────────────────────────
              Container(
                color: surfaceColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: InputDecoration(
                    hintText: 'จำนวนเงิน',
                    hintStyle: TextStyle(color: textSecondary),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    suffixText: 'บาท',
                    suffixStyle: TextStyle(color: textSecondary, fontSize: 15),
                  ),
                  style: TextStyle(fontSize: 16, color: textPrimary),
                ),
              ),
              const SizedBox(height: 8),

              // ── Type selector ─────────────────────────────────────────────
              _RowTile(
                label: 'ประเภท',
                value: _type.label,
                valueColor: _typeColor(_type, isDark),
                surfaceColor: surfaceColor,
                textSecondary: textSecondary,
                onTap: () => _pickType(isDark),
              ),
              Divider(height: 1, color: dividerColor),

              // ── Account ───────────────────────────────────────────────────
              _RowTile(
                label: 'บัญชี',
                value: selectedAccount?.name ?? 'เลือกบัญชี',
                surfaceColor: surfaceColor,
                textSecondary: textSecondary,
                onTap: () =>
                    _pickAccount(accounts, isDark, isDestination: false),
              ),
              Divider(height: 1, color: dividerColor),

              // ── To Account (transfer only) ────────────────────────────────
              if (_type.isTransferLike) ...[
                _RowTile(
                  label: 'บัญชีปลายทาง',
                  value: (_type == TransactionType.debtTransfer
                          ? selectedDebtAccount
                          : selectedToAccount)
                      ?.name ??
                      'เลือกบัญชี',
                  surfaceColor: surfaceColor,
                  textSecondary: textSecondary,
                  onTap: () => _type == TransactionType.debtTransfer
                      ? _pickDebtAccount(accountProvider, isDark)
                      : _pickAccount(accounts, isDark, isDestination: true),
                ),
                Divider(height: 1, color: dividerColor),
              ],

              // ── Debt Account (debtRepay only) ─────────────────────────────
              if (_type == TransactionType.debtRepay) ...[
                _RowTile(
                  label: 'บัญชีหนี้สิน',
                  value: selectedDebtAccount?.name ?? 'เลือกบัญชีหนี้สิน',
                  surfaceColor: surfaceColor,
                  textSecondary: textSecondary,
                  onTap: () => _pickDebtAccount(accountProvider, isDark),
                ),
                Divider(height: 1, color: dividerColor),
              ],

              // ── Category (non-transfer) ────────────────────────────────────
              if (_type.supportsCategory) ...[
                _RowTile(
                  label: 'หมวดหมู่',
                  value: selectedCategory?.name ?? 'ไม่ได้เลือก',
                  surfaceColor: surfaceColor,
                  textSecondary: textSecondary,
                  onTap: () => _pickCategory(categories, isDark),
                ),
                Divider(height: 1, color: dividerColor),
              ],

              // ── Day of month ──────────────────────────────────────────────
              _RowTile(
                label: 'วันที่ในเดือน',
                value: _dayOfMonth == 0 ? 'สิ้นเดือน' : 'วันที่ $_dayOfMonth',
                surfaceColor: surfaceColor,
                textSecondary: textSecondary,
                onTap: () => _pickDayOfMonth(isDark),
              ),
              Divider(height: 1, color: dividerColor),

              // ── Month start ────────────────────────────────────────────────
              InkWell(
                onTap: () => _pickDate(isStart: true),
                child: Container(
                  color: surfaceColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'เดือนเริ่มต้น',
                        style: TextStyle(fontSize: 16, color: textSecondary),
                      ),
                      const Spacer(),
                      Text(
                        _formatMonthYear(_startDate),
                        style: TextStyle(fontSize: 15, color: textPrimary),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, color: textSecondary, size: 18),
                    ],
                  ),
                ),
              ),
              Divider(height: 1, color: dividerColor),

              // ── Month end (optional) ───────────────────────────────────────
              InkWell(
                onTap: () => _pickDate(isStart: false),
                child: Container(
                  color: surfaceColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'เดือนสิ้นสุด',
                        style: TextStyle(fontSize: 16, color: textSecondary),
                      ),
                      const Spacer(),
                      if (_endDate != null) ...[
                        Text(
                          _formatMonthYear(_endDate!),
                          style: TextStyle(fontSize: 15, color: textPrimary),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => setState(() => _endDate = null),
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: textSecondary,
                          ),
                        ),
                      ] else
                        Text(
                          'ไม่ได้เลือก',
                          style: TextStyle(
                            fontSize: 15,
                            color: textSecondary.withValues(alpha: 0.6),
                          ),
                        ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, color: textSecondary, size: 18),
                    ],
                  ),
                ),
              ),
              Divider(height: 1, color: dividerColor),
              // ── Icon ──────────────────────────────────────────────────────
              InkWell(
                onTap: () => _pickIcon(isDark),
                child: Container(
                  color: surfaceColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'ไอคอน',
                        style: TextStyle(fontSize: 16, color: textSecondary),
                      ),
                      const Spacer(),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(_icon, color: _color, size: 26),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, color: textSecondary, size: 18),
                    ],
                  ),
                ),
              ),
              Divider(height: 1, color: dividerColor),

              // ── Color ─────────────────────────────────────────────────────
              InkWell(
                onTap: () => _pickColor(isDark),
                child: Container(
                  color: surfaceColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'สี',
                        style: TextStyle(fontSize: 16, color: textSecondary),
                      ),
                      const Spacer(),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _color,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, color: textSecondary, size: 18),
                    ],
                  ),
                ),
              ),
              Divider(height: 1, color: dividerColor),

              // ── Note ──────────────────────────────────────────────────────
              const SizedBox(height: 8),
              Container(
                color: surfaceColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: TextField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'โน้ต (ไม่บังคับ)',
                    hintStyle: TextStyle(color: textSecondary),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  style: TextStyle(fontSize: 16, color: textPrimary),
                ),
              ),

              // ── Hidden toggle ──────────────────────────────────────────────
              const SizedBox(height: 8),
              Container(
                color: surfaceColor,
                child: SwitchListTile(
                  value: _isHidden,
                  onChanged: (v) => setState(() => _isHidden = v),
                  title: Text(
                    'ซ่อนรายการนี้',
                    style: TextStyle(fontSize: 16, color: textPrimary),
                  ),
                  subtitle: Text(
                    'ซ่อนจากรายการประจำ (แต่ยังทำงานอยู่)',
                    style: TextStyle(fontSize: 13, color: textSecondary),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  // ── Pickers ────────────────────────────────────────────────────────────────

  void _pickType(bool isDark) {
    final bgColor = isDark ? AppColors.darkSurface : Colors.white;
    final handleColor = isDark ? AppColors.darkDivider : Colors.grey.shade300;
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final dividerColor = isDark ? AppColors.darkDivider : AppColors.divider;
    final selectedColor = isDark ? AppColors.darkIncome : AppColors.header;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Handle(color: handleColor),
            ...TransactionType.values.map(
              (t) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    tileColor: bgColor,
                    title: Text(t.label, style: TextStyle(color: textColor)),
                    trailing: _type == t
                        ? Icon(Icons.check, color: selectedColor)
                        : null,
                    onTap: () {
                      setState(() {
                        _type = t;
                        _categoryId = null;
                        // Reset debt account when changing type
                        if (!t.requiresDebtAccount) {
                          _debtAccountId = null;
                        }
                        if (t != TransactionType.transfer) {
                          _toAccountId = null;
                        }
                      });
                      Navigator.pop(context);
                    },
                  ),
                  Divider(height: 1, color: dividerColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _pickAccount(
    List<Account> accounts,
    bool isDark, {
    required bool isDestination,
  }) {
    final bgColor = isDark ? AppColors.darkSurface : Colors.white;
    final handleColor = isDark ? AppColors.darkDivider : Colors.grey.shade300;
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final dividerColor = isDark ? AppColors.darkDivider : AppColors.divider;
    final selectedColor = isDark ? AppColors.darkIncome : AppColors.header;

    // Group accounts by display group
    final Map<String, List<Account>> groupedAccounts = {};
    for (final account in accounts) {
      final group = accountTypeDisplayGroup(account.type);
      groupedAccounts.putIfAbsent(group, () => []).add(account);
    }

    // Sort each group by sortOrder
    for (final group in groupedAccounts.keys) {
      groupedAccounts[group]!.sort(
        (a, b) => a.sortOrder.compareTo(b.sortOrder),
      );
    }

    // Display order - use actual groups from groupedAccounts
    const groupOrder = ['เงินสด / เงินฝาก', 'บัตรเครดิต', 'หนี้สิน', 'ลงทุน'];
    final orderedGroups = groupOrder
        .where(groupedAccounts.containsKey)
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, sc) => Column(
          children: [
            _Handle(color: handleColor),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                isDestination ? 'บัญชีปลายทาง' : 'เลือกบัญชี',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: textColor,
                ),
              ),
            ),
            Divider(height: 1, color: dividerColor),
            Expanded(
              child: ListView.builder(
                controller: sc,
                itemCount: orderedGroups.length,
                itemBuilder: (context, groupIndex) {
                  final groupName = orderedGroups[groupIndex];
                  final groupAccounts = groupedAccounts[groupName]!;
                  final headerBgColor = isDark
                      ? AppColors.darkBackground
                      : AppColors.background;
                  final headerTextColor = isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section Header
                      SizedBox(
                        width: double.infinity,
                        child: Container(
                          color: headerBgColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Text(
                            groupName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: headerTextColor,
                            ),
                          ),
                        ),
                      ),
                      // Account items
                      ...groupAccounts.map((acc) {
                        final currentId = isDestination
                            ? _toAccountId
                            : _accountId;
                        final isSelected = currentId == acc.id;
                        return Column(
                          children: [
                            ListTile(
                              tileColor: bgColor,
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: acc.color.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  acc.icon,
                                  color: acc.color,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                acc.name,
                                style: TextStyle(color: textColor),
                              ),
                              trailing: isSelected
                                  ? Icon(Icons.check, color: selectedColor)
                                  : null,
                              onTap: () {
                                setState(() {
                                  if (isDestination) {
                                    _toAccountId = acc.id;
                                  } else {
                                    _accountId = acc.id;
                                  }
                                });
                                Navigator.pop(context);
                              },
                            ),
                            Divider(height: 1, color: dividerColor),
                          ],
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _pickDebtAccount(AccountProvider accountProvider, bool isDark) {
    final debtAccounts = accountProvider.debtAccounts;
    final bgColor = isDark ? AppColors.darkSurface : Colors.white;
    final handleColor = isDark ? AppColors.darkDivider : Colors.grey.shade300;
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final dividerColor = isDark ? AppColors.darkDivider : AppColors.divider;
    final selectedColor = isDark ? AppColors.darkIncome : AppColors.header;

    // Group debt accounts by display group
    final Map<String, List<Account>> groupedAccounts = {};
    for (final account in debtAccounts) {
      final group = accountTypeDisplayGroup(account.type);
      groupedAccounts.putIfAbsent(group, () => []).add(account);
    }

    // Sort each group by sortOrder
    for (final group in groupedAccounts.keys) {
      groupedAccounts[group]!.sort(
        (a, b) => a.sortOrder.compareTo(b.sortOrder),
      );
    }

    // Display order for debt accounts (บัตรเครดิต, หนี้สิน)
    const groupOrder = ['บัตรเครดิต', 'หนี้สิน'];
    final orderedGroups = groupOrder
        .where(groupedAccounts.containsKey)
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, sc) => Column(
          children: [
            _Handle(color: handleColor),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'เลือกบัญชีหนี้สิน',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: textColor,
                ),
              ),
            ),
            Divider(height: 1, color: dividerColor),
            Expanded(
              child: ListView.builder(
                controller: sc,
                itemCount: orderedGroups.length,
                itemBuilder: (context, groupIndex) {
                  final groupName = orderedGroups[groupIndex];
                  final groupAccounts = groupedAccounts[groupName]!;
                  final headerBgColor = isDark
                      ? AppColors.darkBackground
                      : AppColors.background;
                  final headerTextColor = isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section Header
                      SizedBox(
                        width: double.infinity,
                        child: Container(
                          color: headerBgColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Text(
                            groupName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: headerTextColor,
                            ),
                          ),
                        ),
                      ),
                      // Account items
                      ...groupAccounts.map((acc) {
                        final isSelected = _debtAccountId == acc.id;
                        return Column(
                          children: [
                            ListTile(
                              tileColor: bgColor,
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: acc.color.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  acc.icon,
                                  color: acc.color,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                acc.name,
                                style: TextStyle(color: textColor),
                              ),
                              trailing: isSelected
                                  ? Icon(Icons.check, color: selectedColor)
                                  : null,
                              onTap: () {
                                setState(() {
                                  _debtAccountId = acc.id;
                                });
                                Navigator.pop(context);
                              },
                            ),
                            Divider(height: 1, color: dividerColor),
                          ],
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _pickCategory(List<Category> categories, bool isDark) {
    final bgColor = isDark ? AppColors.darkSurface : Colors.white;
    final handleColor = isDark ? AppColors.darkDivider : Colors.grey.shade300;
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final dividerColor = isDark ? AppColors.darkDivider : AppColors.divider;
    final selectedColor = isDark ? AppColors.darkIncome : AppColors.header;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, sc) => Column(
          children: [
            _Handle(color: handleColor),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'เลือกหมวดหมู่',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: textColor,
                ),
              ),
            ),
            Divider(height: 1, color: dividerColor),
            // Clear option
            ListTile(
              tileColor: bgColor,
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.do_not_disturb, color: Colors.grey, size: 18),
              ),
              title: Text('ไม่ได้เลือก', style: TextStyle(color: textColor)),
              trailing: _categoryId == null
                  ? Icon(Icons.check, color: selectedColor)
                  : null,
              onTap: () {
                setState(() => _categoryId = null);
                Navigator.pop(context);
              },
            ),
            Divider(height: 1, color: dividerColor),
            Expanded(
              child: ListView.separated(
                controller: sc,
                itemCount: categories.length,
                separatorBuilder: (context, i) =>
                    Divider(height: 1, color: dividerColor),
                itemBuilder: (_, i) {
                  final cat = categories[i];
                  final isSelected = _categoryId == cat.id;
                  return ListTile(
                    tileColor: bgColor,
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: cat.color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(cat.icon, color: cat.color, size: 18),
                    ),
                    title: Text(cat.name, style: TextStyle(color: textColor)),
                    trailing: isSelected
                        ? Icon(Icons.check, color: selectedColor)
                        : null,
                    onTap: () {
                      setState(() => _categoryId = cat.id);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _pickDayOfMonth(bool isDark) {
    final bgColor = isDark ? AppColors.darkSurface : Colors.white;
    final handleColor = isDark ? AppColors.darkDivider : Colors.grey.shade300;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final selectedColor = isDark ? AppColors.darkIncome : AppColors.header;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Handle(color: handleColor),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'วันที่ในเดือน',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: textPrimary,
                ),
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: 32, // 1-31 + 0 (สิ้นเดือน)
                itemBuilder: (_, i) {
                  final day = i; // 0 = สิ้นเดือน, 1-31 = actual day
                  final isSelected = _dayOfMonth == day;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _dayOfMonth = day);
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? selectedColor : bgColor,
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? null
                            : Border.all(
                                color: isDark
                                    ? AppColors.darkDivider
                                    : AppColors.divider,
                              ),
                      ),
                      child: Center(
                        child: Text(
                          day == 0 ? 'สิ้น' : '$day',
                          style: TextStyle(
                            fontSize: day == 0 ? 10 : 14,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.normal,
                            color: isSelected ? Colors.white : textPrimary,
                          ),
                        ),
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

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : (_endDate ?? _startDate);
    final picked = await _showMonthYearPicker(
      context,
      initial,
      isStart ? DateTime(2000) : _startDate,
      isEnd: !isStart,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<DateTime?> _showMonthYearPicker(
    BuildContext context,
    DateTime initialDate,
    DateTime firstDate, {
    required bool isEnd,
  }) async {
    final isDark = context.read<SettingsProvider>().isDarkMode;
    final bgColor = isDark ? AppColors.darkSurface : Colors.white;
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final selectedColor = isDark ? AppColors.darkIncome : AppColors.header;

    int selectedYear = initialDate.year;

    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgColor,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkDivider : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header with year navigator
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => setModalState(() => selectedYear--),
                      color: textColor,
                    ),
                    Expanded(
                      child: Text(
                        '${selectedYear + 543}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => setModalState(() => selectedYear++),
                      color: textColor,
                    ),
                  ],
                ),
              ),
              // Month grid
              Padding(
                padding: const EdgeInsets.all(16),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: 12,
                  itemBuilder: (_, i) {
                    final month = i + 1;
                    final isSelected =
                        selectedYear == initialDate.year &&
                        month == initialDate.month;
                    return GestureDetector(
                      onTap: () {
                        // For start date, use day 1; for end date, use last day
                        final day = isEnd
                            ? DateTime(selectedYear, month + 1, 0).day
                            : 1;
                        Navigator.pop(
                          context,
                          DateTime(selectedYear, month, day),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? selectedColor : bgColor,
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected
                              ? null
                              : Border.all(
                                  color: isDark
                                      ? AppColors.darkDivider
                                      : AppColors.divider,
                                ),
                        ),
                        child: Center(
                          child: Text(
                            _thaiMonthsShort[month - 1],
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                              color: isSelected ? Colors.white : textColor,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  static const _thaiMonthsShort = [
    'ม.ค.',
    'ก.พ.',
    'มี.ค.',
    'เม.ย.',
    'พ.ค.',
    'มิ.ย.',
    'ก.ค.',
    'ส.ค.',
    'ก.ย.',
    'ต.ค.',
    'พ.ย.',
    'ธ.ค.',
  ];

  static const _thaiMonths = [
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

  String _formatMonthYear(DateTime d) =>
      '${_thaiMonths[d.month - 1]} ${d.year + 543}';

  void _pickIcon(bool isDark) {
    final bgColor = isDark ? AppColors.darkBackground : AppColors.background;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'เลือกไอคอน',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: textPrimary,
                ),
              ),
            ),
            Expanded(
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
                  final selected = icon == _icon;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _icon = icon);
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: selected
                            ? _color.withValues(alpha: 0.15)
                            : bgColor,
                        borderRadius: BorderRadius.circular(10),
                        border: selected
                            ? Border.all(color: _color, width: 2)
                            : null,
                      ),
                      child: Icon(
                        icon,
                        color: selected ? _color : textSecondary,
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

  void _pickColor(bool isDark) {
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'เลือกสี',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: textPrimary,
                ),
              ),
            ),
            Expanded(
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
                  final selected = color.toARGB32() == _color.toARGB32();
                  return GestureDetector(
                    onTap: () {
                      setState(() => _color = color);
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

  // ── Helpers ────────────────────────────────────────────────────────────────

  Color _typeColor(TransactionType type, bool isDark) {
    switch (type) {
      case TransactionType.income:
        return isDark ? AppColors.darkIncome : AppColors.income;
      case TransactionType.expense:
        return isDark ? AppColors.darkExpense : AppColors.expense;
      case TransactionType.transfer:
      case TransactionType.debtRepay:
        return isDark ? AppColors.darkTransfer : AppColors.transfer;
      case TransactionType.debtTransfer:
        return isDark ? AppColors.darkDebtTransfer : AppColors.debtTransfer;
    }
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _RowTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final Color surfaceColor;
  final Color textSecondary;
  final VoidCallback onTap;

  const _RowTile({
    required this.label,
    required this.value,
    this.valueColor,
    required this.surfaceColor,
    required this.textSecondary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<SettingsProvider>().isDarkMode;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: surfaceColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text(label, style: TextStyle(fontSize: 16, color: textSecondary)),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                color: valueColor ?? textPrimary,
                fontWeight: valueColor != null
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: textSecondary, size: 18),
          ],
        ),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  final Color color;
  const _Handle({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
