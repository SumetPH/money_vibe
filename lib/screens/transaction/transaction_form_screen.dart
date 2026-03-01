import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/transaction.dart';
import '../../models/account.dart';
import '../../models/category.dart';
import '../../providers/account_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../theme/app_colors.dart';
import '../../main.dart';

class TransactionFormScreen extends StatefulWidget {
  final AppTransaction? transaction;

  const TransactionFormScreen({super.key, this.transaction});

  @override
  State<TransactionFormScreen> createState() =>
      _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  final _amountController = TextEditingController();
  final _payeeController = TextEditingController();
  final _locationController = TextEditingController();
  final _noteController = TextEditingController();
  final _tagController = TextEditingController();

  late TransactionType _type;
  String? _selectedAccountId;
  String? _selectedCategoryId;
  String? _selectedToAccountId;
  String? _selectedDebtAccountId;
  late DateTime _selectedDateTime;
  DateTime? _recordDate;

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    final tx = widget.transaction;
    _type = tx?.type ?? TransactionType.expense;
    _selectedAccountId = tx?.accountId;
    _selectedCategoryId = tx?.categoryId;
    _selectedToAccountId =
        _type == TransactionType.transfer ? tx?.toAccountId : null;
    _selectedDebtAccountId =
        _type == TransactionType.debtRepay ? tx?.toAccountId : null;
    _selectedDateTime = tx?.dateTime ?? DateTime.now();
    _recordDate = tx?.recordDate;
    _amountController.text =
        tx != null ? formatAmount(tx.amount) : '';
    _payeeController.text = tx?.payee ?? '';
    _locationController.text = tx?.location ?? '';
    _noteController.text = tx?.note ?? '';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedAccountId == null) {
        final accounts =
            context.read<AccountProvider>().visibleAccounts;
        if (accounts.isNotEmpty) {
          setState(() => _selectedAccountId = accounts.first.id);
        }
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _payeeController.dispose();
    _locationController.dispose();
    _noteController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _save() {
    final amountText =
        _amountController.text.replaceAll(',', '').trim();
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกจำนวนเงิน')),
      );
      return;
    }
    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกบัญชี')),
      );
      return;
    }
    if (_type == TransactionType.debtRepay &&
        _selectedDebtAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกบัญชีหนี้สิน')),
      );
      return;
    }

    final txProvider = context.read<TransactionProvider>();

    String? toAccountId;
    if (_type == TransactionType.transfer) {
      toAccountId = _selectedToAccountId;
    } else if (_type == TransactionType.debtRepay) {
      toAccountId = _selectedDebtAccountId;
    }

    final tx = AppTransaction(
      id: _isEditing
          ? widget.transaction!.id
          : txProvider.generateId(),
      type: _type,
      amount: amount,
      accountId: _selectedAccountId!,
      categoryId: _selectedCategoryId,
      toAccountId: toAccountId,
      payee: _payeeController.text.trim().isEmpty
          ? null
          : _payeeController.text.trim(),
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      dateTime: _selectedDateTime,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      recordDate: _recordDate,
    );

    if (_isEditing) {
      txProvider.updateTransaction(tx);
    } else {
      txProvider.addTransaction(tx);
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<AccountProvider, TransactionProvider,
        CategoryProvider>(
      builder: (context, accountProvider, txProvider, catProvider, _) {
        final accounts = accountProvider.visibleAccounts;
        final selectedAccount = _selectedAccountId != null
            ? accountProvider.findById(_selectedAccountId!)
            : null;
        final selectedToAccount = _selectedToAccountId != null
            ? accountProvider.findById(_selectedToAccountId!)
            : null;
        final selectedDebtAccount = _selectedDebtAccountId != null
            ? accountProvider.findById(_selectedDebtAccountId!)
            : null;
        final categories = _type == TransactionType.income
            ? catProvider.incomeCategories
            : catProvider.expenseCategories;
        final selectedCategory = _selectedCategoryId != null
            ? catProvider.findById(_selectedCategoryId!)
            : null;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
            title: _TypeSelector(
              selectedType: _type,
              onChanged: (t) => setState(() {
                _type = t;
                _selectedCategoryId = null;
              }),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.more_horiz),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.save_outlined),
                onPressed: () {},
                tooltip: 'บันทึกแบบร่าง',
              ),
              IconButton(
                icon: const Icon(Icons.check),
                onPressed: _save,
              ),
            ],
          ),
          body: ListView(
            children: _buildFormItems(
              accountProvider: accountProvider,
              accounts: accounts,
              selectedAccount: selectedAccount,
              selectedToAccount: selectedToAccount,
              selectedDebtAccount: selectedDebtAccount,
              categories: categories,
              selectedCategory: selectedCategory,
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildFormItems({
    required AccountProvider accountProvider,
    required List<Account> accounts,
    required Account? selectedAccount,
    required Account? selectedToAccount,
    required Account? selectedDebtAccount,
    required List<Category> categories,
    required Category? selectedCategory,
  }) {
    final bool isDebtRepay = _type == TransactionType.debtRepay;
    final amountText =
        _amountController.text.replaceAll(',', '').trim();
    final amount = double.tryParse(amountText) ?? 0.0;

    return [
      // Amount section
      Container(
        color: AppColors.surface,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Text(
              isDebtRepay ? 'เงินต้น' : 'จำนวน',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'[0-9.,]')),
                ],
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w300,
                  color: isDebtRepay
                      ? AppColors.expense
                      : AppColors.textSecondary,
                ),
                decoration: InputDecoration(
                  hintText: 'จำนวน',
                  hintStyle: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w300,
                    color: AppColors.divider,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 8),
                  suffixText: 'บาท',
                  suffixStyle: TextStyle(
                    fontSize: 14,
                    color: isDebtRepay
                        ? AppColors.expense
                        : AppColors.textSecondary,
                  ),
                ),
                autofocus: !_isEditing,
                onChanged: isDebtRepay ? (_) => setState(() {}) : null,
              ),
            ),
          ],
        ),
      ),

      // รวม row (debtRepay only)
      if (isDebtRepay) ...[
        const Divider(height: 1, indent: 16),
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Text(
                'รวม',
                style: TextStyle(
                    fontSize: 15, color: AppColors.textSecondary),
              ),
              const Spacer(),
              Text(
                '${formatAmount(amount)} บาท',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.expense,
                ),
              ),
            ],
          ),
        ),
      ],

      const SizedBox(height: 8),

      // Account section
      if (isDebtRepay)
        _DebtRepayAccountSection(
          selectedDebtAccount: selectedDebtAccount,
          selectedAccount: selectedAccount,
          selectedCategory: selectedCategory,
          onDebtAccountTap: () =>
              _pickDebtAccount(context, accountProvider),
          onAccountTap: () => _pickAccount(context, accounts, false),
          onClearAccount: () =>
              setState(() => _selectedAccountId = null),
          onCategoryTap: () => _pickCategory(context, categories),
        )
      else
        _AccountCategorySelector(
          type: _type,
          accounts: accounts,
          selectedAccount: selectedAccount,
          selectedToAccount: selectedToAccount,
          categories: categories,
          selectedCategory: selectedCategory,
          onAccountTap: () => _pickAccount(context, accounts, false),
          onToAccountTap: () => _pickAccount(context, accounts, true),
          onCategoryTap: () => _pickCategory(context, categories),
        ),

      const SizedBox(height: 8),

      // Payee (not for debtRepay)
      if (!isDebtRepay) ...[
        _FieldRow(
          label: 'ผู้รับเงิน',
          controller: _payeeController,
          icon: Icons.person_outline,
          hint: '',
        ),
        _buildDivider(),
      ],

      // Location
      _FieldRow(
        label: 'ตำแหน่ง',
        controller: _locationController,
        icon: Icons.location_on_outlined,
        hint: '',
      ),
      _buildDivider(),

      // DateTime
      _DateTimeRow(
        dateTime: _selectedDateTime,
        onTap: () => _pickDateTime(context),
      ),
      _buildDivider(),

      // Record date (debtRepay only)
      if (isDebtRepay) ...[
        _RecordDateRow(
          recordDate: _recordDate,
          onTap: () => _pickRecordDate(context),
        ),
        _buildDivider(),
      ],

      // Note
      _FieldRow(
        label: 'โน้ต',
        controller: _noteController,
        icon: Icons.notes,
        hint: '',
        maxLines: 3,
      ),
      _buildDivider(),

      // Tags
      _TagRow(controller: _tagController),
      const SizedBox(height: 16),

      // Add image
      GestureDetector(
        onTap: () {},
        child: Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: const Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_photo_alternate_outlined,
                    color: AppColors.textSecondary, size: 20),
                SizedBox(width: 8),
                Text(
                  'เพิ่มรูปภาพ',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 80),
    ];
  }

  Widget _buildDivider() => const Divider(height: 1, indent: 16);

  void _pickAccount(
      BuildContext context, List<Account> accounts, bool isTarget) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isTarget ? 'เลือกบัญชีปลายทาง' : 'เลือกบัญชี',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Divider(),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: accounts.length,
                itemBuilder: (_, i) {
                  final acc = accounts[i];
                  final selected = (isTarget
                          ? _selectedToAccountId
                          : _selectedAccountId) ==
                      acc.id;
                  return ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: acc.color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child:
                          Icon(acc.icon, color: acc.color, size: 20),
                    ),
                    title: Text(acc.name),
                    trailing: selected
                        ? const Icon(Icons.check,
                            color: AppColors.header)
                        : null,
                    onTap: () {
                      setState(() {
                        if (isTarget) {
                          _selectedToAccountId = acc.id;
                        } else {
                          _selectedAccountId = acc.id;
                        }
                      });
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
            const SafeArea(top: false, child: SizedBox()),
          ],
        ),
      ),
    );
  }

  void _pickDebtAccount(
      BuildContext context, AccountProvider accountProvider) {
    final debtAccounts = accountProvider.debtAccounts;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'เลือกบัญชีหนี้สิน',
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Divider(),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: debtAccounts.length,
                itemBuilder: (_, i) {
                  final acc = debtAccounts[i];
                  final selected = _selectedDebtAccountId == acc.id;
                  return ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: acc.color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child:
                          Icon(acc.icon, color: acc.color, size: 20),
                    ),
                    title: Text(acc.name),
                    trailing: selected
                        ? const Icon(Icons.check,
                            color: AppColors.header)
                        : null,
                    onTap: () {
                      setState(() => _selectedDebtAccountId = acc.id);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
            const SafeArea(top: false, child: SizedBox()),
          ],
        ),
      ),
    );
  }

  void _pickCategory(BuildContext context, List<Category> categories) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'เลือกหมวดหมู่',
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Divider(),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: categories.length,
                itemBuilder: (_, i) {
                  final cat = categories[i];
                  return ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: cat.color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child:
                          Icon(cat.icon, color: cat.color, size: 20),
                    ),
                    title: Text(cat.name),
                    trailing: _selectedCategoryId == cat.id
                        ? const Icon(Icons.check,
                            color: AppColors.header)
                        : null,
                    onTap: () {
                      setState(() => _selectedCategoryId = cat.id);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
            const SafeArea(top: false, child: SizedBox()),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateTime(BuildContext context) async {
    final initialDt = _selectedDateTime;
    final date = await showDatePicker(
      context: context,
      initialDate: initialDt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: this.context,
      initialTime: TimeOfDay.fromDateTime(initialDt),
    );
    if (time == null) return;

    setState(() {
      _selectedDateTime = DateTime(
        date.year, date.month, date.day, time.hour, time.minute,
      );
    });
  }

  Future<void> _pickRecordDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _recordDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    setState(() => _recordDate = date);
  }
}

class _TypeSelector extends StatelessWidget {
  final TransactionType selectedType;
  final ValueChanged<TransactionType> onChanged;

  const _TypeSelector({
    required this.selectedType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<TransactionType>(
      onSelected: onChanged,
      itemBuilder: (_) => TransactionType.values
          .map((t) => PopupMenuItem(
                value: t,
                child: Text(t.label),
              ))
          .toList(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            selectedType.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_drop_down,
              color: Colors.white, size: 20),
        ],
      ),
    );
  }
}

class _DebtRepayAccountSection extends StatelessWidget {
  final Account? selectedDebtAccount;
  final Account? selectedAccount;
  final Category? selectedCategory;
  final VoidCallback onDebtAccountTap;
  final VoidCallback onAccountTap;
  final VoidCallback onClearAccount;
  final VoidCallback onCategoryTap;

  const _DebtRepayAccountSection({
    required this.selectedDebtAccount,
    required this.selectedAccount,
    required this.selectedCategory,
    required this.onDebtAccountTap,
    required this.onAccountTap,
    required this.onClearAccount,
    required this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // หนี้สิน row
          InkWell(
            onTap: onDebtAccountTap,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const SizedBox(
                    width: 72,
                    child: Text(
                      'หนี้สิน',
                      style: TextStyle(
                          fontSize: 15,
                          color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (selectedDebtAccount != null) ...[
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: selectedDebtAccount!.color
                            .withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(selectedDebtAccount!.icon,
                          color: selectedDebtAccount!.color, size: 13),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        selectedDebtAccount!.name,
                        style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ] else
                    const Expanded(
                      child: Text(
                        'เลือกบัญชีหนี้สิน',
                        style: TextStyle(
                            fontSize: 15,
                            color: AppColors.textSecondary),
                      ),
                    ),
                  const Icon(Icons.arrow_drop_down,
                      color: AppColors.textSecondary, size: 20),
                ],
              ),
            ),
          ),
          const Divider(height: 1, indent: 16),
          // บัญชี (source chip) + หมวดหมู่ row
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _AccountChip(
                  account: selectedAccount,
                  onTap: onAccountTap,
                  onClear: onClearAccount,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: onCategoryTap,
                    child: Text(
                      selectedCategory?.name ??
                          'เลือกหมวดหมู่ (ปล่อยว่างได้)',
                      style: TextStyle(
                        fontSize: 13,
                        color: selectedCategory != null
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountChip extends StatelessWidget {
  final Account? account;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _AccountChip({
    required this.account,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    if (account == null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.divider),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text(
            'บัญชี',
            style: TextStyle(
                fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: account!.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.only(
                  left: 10, top: 6, bottom: 6, right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(account!.icon,
                      size: 14, color: account!.color),
                  const SizedBox(width: 4),
                  Text(
                    account!.name,
                    style: TextStyle(
                      fontSize: 13,
                      color: account!.color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: onClear,
            borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 6),
              child: Icon(Icons.close, size: 14, color: account!.color),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountCategorySelector extends StatelessWidget {
  final TransactionType type;
  final List<Account> accounts;
  final Account? selectedAccount;
  final Account? selectedToAccount;
  final List<Category> categories;
  final Category? selectedCategory;
  final VoidCallback onAccountTap;
  final VoidCallback onToAccountTap;
  final VoidCallback onCategoryTap;

  const _AccountCategorySelector({
    required this.type,
    required this.accounts,
    required this.selectedAccount,
    required this.selectedToAccount,
    required this.categories,
    required this.selectedCategory,
    required this.onAccountTap,
    required this.onToAccountTap,
    required this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: Row(
        children: [
          // Account selector
          Expanded(
            child: InkWell(
              onTap: onAccountTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 20),
                child: Row(
                  children: [
                    if (selectedAccount != null) ...[
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: selectedAccount!.color
                              .withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(selectedAccount!.icon,
                            color: selectedAccount!.color, size: 16),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          selectedAccount!.name,
                          style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else
                      const Text(
                        'เลือกบัญชี',
                        style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Middle divider with + / swap button
          Container(
            width: 1,
            height: 60,
            color: AppColors.divider,
          ),
          GestureDetector(
            onTap: type == TransactionType.transfer
                ? onToAccountTap
                : onCategoryTap,
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.divider),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                type == TransactionType.transfer
                    ? Icons.swap_horiz
                    : Icons.add,
                color: AppColors.textSecondary,
                size: 18,
              ),
            ),
          ),
          Container(
            width: 1,
            height: 60,
            color: AppColors.divider,
          ),
          // Category / To-Account selector
          Expanded(
            child: InkWell(
              onTap: type == TransactionType.transfer
                  ? onToAccountTap
                  : onCategoryTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 20),
                child: Row(
                  children: [
                    if (type == TransactionType.transfer &&
                        selectedToAccount != null) ...[
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: selectedToAccount!.color
                              .withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(selectedToAccount!.icon,
                            color: selectedToAccount!.color, size: 16),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          selectedToAccount!.name,
                          style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else if (type != TransactionType.transfer &&
                        selectedCategory != null) ...[
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: selectedCategory!.color
                              .withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(selectedCategory!.icon,
                            color: selectedCategory!.color, size: 16),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          selectedCategory!.name,
                          style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else
                      Text(
                        type == TransactionType.transfer
                            ? 'บัญชีปลายทาง'
                            : 'เลือกหมวดหมู่',
                        style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final int maxLines;

  const _FieldRow({
    required this.label,
    required this.controller,
    required this.icon,
    required this.hint,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: maxLines,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12),
              ),
              style: const TextStyle(fontSize: 15),
            ),
          ),
          Icon(icon, color: AppColors.textSecondary, size: 20),
        ],
      ),
    );
  }
}

class _DateTimeRow extends StatelessWidget {
  final DateTime dateTime;
  final VoidCallback onTap;

  const _DateTimeRow({required this.dateTime, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: AppColors.surface,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Text(
              'วันและเวลา',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              _formatThaiDateTime(dateTime),
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.calendar_today_outlined,
                color: AppColors.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }

  String _formatThaiDateTime(DateTime dt) {
    const thaiDays = ['จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา'];
    const thaiMonths = [
      'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.',
      'พ.ค.', 'มิ.ย.', 'ก.ค.', 'ส.ค.',
      'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
    ];
    final day = thaiDays[dt.weekday - 1];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$day. ${dt.day} ${thaiMonths[dt.month - 1]} ${dt.year + 543} $h:$m';
  }
}

class _RecordDateRow extends StatelessWidget {
  final DateTime? recordDate;
  final VoidCallback onTap;

  const _RecordDateRow(
      {required this.recordDate, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: AppColors.surface,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Text(
              'วันที่บันทึก',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              recordDate != null
                  ? _formatThaiDate(recordDate!)
                  : '-',
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.calendar_today_outlined,
                color: AppColors.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }

  String _formatThaiDate(DateTime dt) {
    const thaiDays = ['จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา'];
    const thaiMonths = [
      'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.',
      'พ.ค.', 'มิ.ย.', 'ก.ค.', 'ส.ค.',
      'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
    ];
    final day = thaiDays[dt.weekday - 1];
    return '$day. ${dt.day} ${thaiMonths[dt.month - 1]} ${dt.year + 543}';
  }
}

class _TagRow extends StatelessWidget {
  final TextEditingController controller;

  const _TagRow({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const SizedBox(
            width: 90,
            child: Text(
              'แท็ก',
              style: TextStyle(
                  fontSize: 15, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText:
                    'เพิ่มแท็กได้ตรงนี้ (พิมพ์ชื่อกดปุ่ม Enter เพื่อสร้างแท็ก)',
                hintStyle: TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const Icon(Icons.access_time,
              color: AppColors.textSecondary, size: 20),
        ],
      ),
    );
  }
}
