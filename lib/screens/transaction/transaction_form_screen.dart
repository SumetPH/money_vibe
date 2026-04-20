import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/transaction.dart';
import '../../models/account.dart';
import '../../models/category.dart';
import '../../providers/account_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/recurring_transaction_provider.dart';
import '../../theme/app_colors.dart';
import '../../main.dart';

class TransactionFormScreen extends StatefulWidget {
  final AppTransaction? transaction;
  final AppTransaction? initialValues; // pre-fill without triggering edit mode
  final void Function(String transactionId)? onSaved;

  const TransactionFormScreen({
    super.key,
    this.transaction,
    this.initialValues,
    this.onSaved,
  });

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  late TransactionType _type;
  String? _selectedAccountId;
  String? _selectedCategoryId;
  String? _selectedToAccountId;
  String? _selectedDebtAccountId;
  late DateTime _selectedDateTime;

  double _accountBalance = 0.0;

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    final tx = widget.transaction ?? widget.initialValues;
    _type = tx?.type ?? TransactionType.expense;
    _selectedAccountId = tx?.accountId;
    _selectedCategoryId = tx?.categoryId;
    _selectedToAccountId = _type == TransactionType.transfer
        ? tx?.toAccountId
        : null;
    _selectedDebtAccountId = _type.requiresDebtAccount ? tx?.toAccountId : null;
    _selectedDateTime = tx?.dateTime ?? DateTime.now();
    _amountController.text = (tx != null && tx.amount > 0)
        ? formatAmount(tx.amount)
        : '';
    _noteController.text = tx?.note ?? '';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateAccountBalance();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _calculateAccountBalance() {
    if (_selectedAccountId != null &&
        (_type == TransactionType.increaseBalance ||
            _type == TransactionType.decreaseBalance)) {
      final amount =
          double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;
      final currentBalance = context.read<AccountProvider>().getBalance(
        _selectedAccountId!,
        context.read<TransactionProvider>().transactions,
      );

      final originalAmount = _isEditing ? widget.transaction!.amount : 0;

      if (_type == TransactionType.increaseBalance) {
        setState(() {
          _accountBalance = (currentBalance - originalAmount) + amount;
        });
      } else if (_type == TransactionType.decreaseBalance) {
        setState(() {
          _accountBalance = (currentBalance + originalAmount) - amount;
        });
      }
    }
  }

  /// Format amount with commas while typing
  void _formatAmountInput(String value) {
    // Remove commas and get raw digits
    final raw = value.replaceAll(',', '');
    if (raw.isEmpty) {
      _amountController.text = '';
      _amountController.selection = const TextSelection.collapsed(offset: 0);
      return;
    }

    // Parse as double to handle decimal point
    final hasDecimal = raw.contains('.');
    final parts = raw.split('.');
    final intPart = parts[0];

    // Add commas to integer part
    final formattedInt = intPart.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );

    // Reconstruct with decimal if present
    String formatted;
    if (hasDecimal && parts.length > 1) {
      formatted = '$formattedInt.${parts[1]}';
    } else {
      formatted = formattedInt;
    }

    // Update text if different
    if (_amountController.text != formatted) {
      _amountController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  Future<void> _save() async {
    final amountText = _amountController.text.replaceAll(',', '').trim();
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณากรอกจำนวนเงิน')));
      return;
    }
    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณาเลือกบัญชี')));
      return;
    }
    if (_type.requiresDebtAccount && _selectedDebtAccountId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณาเลือกบัญชีหนี้สิน')));
      return;
    }

    final txProvider = context.read<TransactionProvider>();

    String? toAccountId;
    if (_type == TransactionType.transfer) {
      toAccountId = _selectedToAccountId;
    } else if (_type.requiresDebtAccount) {
      toAccountId = _selectedDebtAccountId;
    }

    final tx = AppTransaction(
      id: _isEditing ? widget.transaction!.id : txProvider.generateId(),
      type: _type,
      amount: amount,
      accountId: _selectedAccountId!,
      categoryId: _type.supportsCategory ? _selectedCategoryId : null,
      toAccountId: toAccountId,
      dateTime: _selectedDateTime,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    );

    if (_isEditing) {
      await txProvider.updateTransaction(tx);
    } else {
      await txProvider.addTransaction(tx);
    }

    widget.onSaved?.call(tx.id);
    if (mounted) Navigator.pop(context);
  }

  void _delete() {
    final isDarkMode = context.read<SettingsProvider>().isDarkMode;
    final bgColor = isDarkMode ? AppColors.darkSurface : Colors.white;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: bgColor,
        title: Text('ลบรายการ', style: TextStyle(color: textColor)),
        content: Text(
          'คุณต้องการที่จะลบรายการนี้ใช่หรือไม่?',
          style: TextStyle(color: textColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ยกเลิก', style: TextStyle(color: textColor)),
          ),
          TextButton(
            onPressed: () {
              final transactionId = widget.transaction!.id;

              // Check if this transaction is linked to a recurring occurrence
              final recurProvider = context
                  .read<RecurringTransactionProvider>();
              final occ = recurProvider.findOccurrenceByTransactionId(
                transactionId,
              );

              // Delete the transaction
              context.read<TransactionProvider>().deleteTransaction(
                transactionId,
              );

              // If linked to a recurring occurrence, undo it
              if (occ != null) {
                recurProvider.undoOccurrence(occ.recurringId, occ.dueDate);
              }

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
    return Consumer3<AccountProvider, TransactionProvider, CategoryProvider>(
      builder: (context, accountProvider, txProvider, catProvider, _) {
        // Filter out debt accounts for Income/Expense transactions
        final allVisibleAccounts = accountProvider.visibleAccounts;

        final accounts = switch (_type) {
          TransactionType.debtTransfer =>
            allVisibleAccounts
                .where(
                  (a) =>
                      (a.type == AccountType.debt ||
                          a.type == AccountType.creditCard) &&
                      a.type != AccountType.portfolio,
                )
                .toList(),
          TransactionType.income ||
          TransactionType.expense ||
          TransactionType.debtRepay =>
            allVisibleAccounts
                .where(
                  (a) =>
                      a.type != AccountType.debt &&
                      a.type != AccountType.portfolio,
                )
                .toList(),
          TransactionType.increaseBalance || TransactionType.decreaseBalance =>
            allVisibleAccounts
                .where(
                  (a) =>
                      a.type == AccountType.cash ||
                      a.type == AccountType.bankAccount ||
                      a.type == AccountType.asset ||
                      a.type == AccountType.debt,
                )
                .toList(),
          _ => allVisibleAccounts,
        };
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
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                if (t != TransactionType.transfer) {
                  _selectedToAccountId = null;
                }
                if (!t.requiresDebtAccount) {
                  _selectedDebtAccountId = null;
                }

                _calculateAccountBalance();
              }),
            ),
            actions: [
              if (_isEditing)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _delete,
                  tooltip: 'ลบรายการ',
                ),
              IconButton(icon: const Icon(Icons.check), onPressed: _save),
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
              type: _type,
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
    required TransactionType? type,
  }) {
    final bool isDebtRepay = _type == TransactionType.debtRepay;
    final bool isDebtTransfer = _type == TransactionType.debtTransfer;
    final bool usesDebtAccount = _type.requiresDebtAccount;
    final txProvider = context.read<TransactionProvider>();
    final transactions = txProvider.transactions;
    final isDarkMode = context.watch<SettingsProvider>().isDarkMode;
    final theme = Theme.of(context);

    return [
      // Amount section
      Container(
        color:
            theme.cardTheme.color ??
            (isDarkMode ? AppColors.darkSurface : AppColors.surface),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Text(
              isDebtRepay
                  ? 'เงินต้น'
                  : isDebtTransfer
                  ? 'ยอดโยก'
                  : 'จำนวน',
              style: TextStyle(
                fontSize: 15,
                color: isDarkMode
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w300),
                decoration: InputDecoration(
                  hintText: 'จำนวน',
                  hintStyle: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w300,
                    color: isDarkMode
                        ? AppColors.darkDivider
                        : AppColors.divider,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  filled: false,
                  suffixText: 'บาท',
                  suffixStyle: TextStyle(fontSize: 15),
                ),
                autofocus: !_isEditing,
                onChanged: (value) {
                  _formatAmountInput(value);
                  _calculateAccountBalance();
                  if (usesDebtAccount) setState(() {});
                },
              ),
            ),
          ],
        ),
      ),

      if (type == TransactionType.decreaseBalance ||
          type == TransactionType.increaseBalance)
        const SizedBox(height: 8),

      if (type == TransactionType.decreaseBalance ||
          type == TransactionType.increaseBalance)
        Container(
          color:
              theme.cardTheme.color ??
              (isDarkMode ? AppColors.darkSurface : AppColors.surface),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Text(
                'ยอดคงเหลือ',
                style: TextStyle(
                  fontSize: 15,
                  color: isDarkMode
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  '${NumberFormat('#,##0.00').format(_accountBalance)} บาท',
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),

      const SizedBox(height: 8),

      // Account section
      if (isDebtRepay)
        _DebtRepayAccountSection(
          selectedDebtAccount: selectedDebtAccount,
          selectedAccount: selectedAccount,
          selectedCategory: selectedCategory,
          onDebtAccountTap: () => _pickDebtAccount(context, accountProvider),
          onAccountTap: () => _pickAccount(context, accounts, false),
          onClearAccount: () => setState(() => _selectedAccountId = null),
          onCategoryTap: () => _pickCategory(context, categories),
        )
      else
        _AccountCategorySelector(
          type: _type,
          accounts: accounts,
          selectedAccount: selectedAccount,
          selectedToAccount: isDebtTransfer
              ? selectedDebtAccount
              : selectedToAccount,
          categories: categories,
          selectedCategory: selectedCategory,
          onAccountTap: () => _pickAccount(context, accounts, false),
          onToAccountTap: isDebtTransfer
              ? () => _pickDebtAccount(context, accountProvider)
              : () => _pickAccount(context, accounts, true),
          onCategoryTap: () => _pickCategory(context, categories),
          accountProvider: accountProvider,
          transactions: transactions,
        ),

      if (isDebtTransfer) ...[
        _buildDivider(),
        _CategorySelectionRow(
          selectedCategory: selectedCategory,
          onTap: () => _pickCategory(context, categories),
        ),
      ],

      const SizedBox(height: 8),

      _buildDivider(),

      // DateTime
      _DateTimeRow(
        dateTime: _selectedDateTime,
        onTap: () => _pickDateTime(context),
      ),
      _buildDivider(),

      // Note
      _FieldRow(
        label: 'โน้ต',
        controller: _noteController,
        icon: Icons.notes,
        hint: '',
        maxLines: 3,
      ),
      const SizedBox(height: 16),
    ];
  }

  Widget _buildDivider() => const Divider(height: 1);

  void _pickAccount(
    BuildContext context,
    List<Account> accounts,
    bool isTarget,
  ) {
    final txProvider = context.read<TransactionProvider>();
    final transactions = txProvider.transactions;
    final accountProvider = context.read<AccountProvider>();

    final isDarkMode = context.read<SettingsProvider>().isDarkMode;
    final colorScheme = Theme.of(context).colorScheme;

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
    const groupOrder = [
      'เงินสด / เงินฝาก',
      'บัตรเครดิต',
      'หนี้สิน',
      'ทรัพย์สิน',
      'ลงทุน',
    ];
    final orderedGroups = groupOrder
        .where(groupedAccounts.containsKey)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDarkMode ? AppColors.darkSurface : Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDarkMode
                    ? AppColors.darkDivider
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isTarget ? 'เลือกบัญชีปลายทาง' : 'เลือกบัญชี',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: isDarkMode
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: orderedGroups.length,
                padding: EdgeInsets.zero,
                itemBuilder: (ctx, groupIndex) {
                  final groupName = orderedGroups[groupIndex];
                  final groupAccounts = groupedAccounts[groupName]!;
                  final headerBgColor = isDarkMode
                      ? AppColors.darkBackground
                      : AppColors.background;
                  final headerTextColor = isDarkMode
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
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: headerTextColor,
                            ),
                          ),
                        ),
                      ),
                      // Account Items
                      ...groupAccounts.map((acc) {
                        final balance = accountProvider.getBalance(
                          acc.id,
                          transactions,
                        );
                        final selected =
                            (isTarget
                                ? _selectedToAccountId
                                : _selectedAccountId) ==
                            acc.id;
                        final surfaceColor = isDarkMode
                            ? AppColors.darkSurface
                            : AppColors.surface;
                        final textPrimaryColor = isDarkMode
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary;
                        final dividerColor = isDarkMode
                            ? AppColors.darkDivider
                            : AppColors.divider;

                        return Column(
                          children: [
                            InkWell(
                              onTap: () {
                                setState(() {
                                  if (isTarget) {
                                    _selectedToAccountId = acc.id;
                                  } else {
                                    _selectedAccountId = acc.id;
                                  }
                                });
                                _calculateAccountBalance();
                                Navigator.pop(context);
                              },
                              child: Container(
                                color: surfaceColor,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: acc.color.withValues(
                                          alpha: 0.15,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        acc.icon,
                                        color: acc.color,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            acc.name,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: textPrimaryColor,
                                            ),
                                          ),
                                          Text(
                                            formatAmount(balance),
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.getAmountColor(
                                                balance,
                                                isDarkMode,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (selected)
                                      Icon(
                                        Icons.check,
                                        color: colorScheme.primary,
                                      ),
                                  ],
                                ),
                              ),
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
            const SafeArea(top: false, child: SizedBox()),
          ],
        ),
      ),
    );
  }

  void _pickDebtAccount(BuildContext context, AccountProvider accountProvider) {
    final debtAccounts = accountProvider.debtAccounts;
    final txProvider = context.read<TransactionProvider>();
    final transactions = txProvider.transactions;
    final isDarkMode = context.read<SettingsProvider>().isDarkMode;
    final colorScheme = Theme.of(context).colorScheme;

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
      isScrollControlled: true,
      clipBehavior: Clip.antiAlias,
      backgroundColor: isDarkMode ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDarkMode
                    ? AppColors.darkDivider
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'เลือกบัญชีหนี้สิน',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: isDarkMode
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: orderedGroups.length,
                padding: EdgeInsets.zero,
                itemBuilder: (ctx, groupIndex) {
                  final groupName = orderedGroups[groupIndex];
                  final groupAccounts = groupedAccounts[groupName]!;
                  final headerBgColor = isDarkMode
                      ? AppColors.darkBackground
                      : AppColors.background;
                  final headerTextColor = isDarkMode
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
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: headerTextColor,
                            ),
                          ),
                        ),
                      ),
                      // Account Items
                      ...groupAccounts.map((acc) {
                        final balance = accountProvider.getBalance(
                          acc.id,
                          transactions,
                        );
                        final selected = _selectedDebtAccountId == acc.id;
                        final surfaceColor = isDarkMode
                            ? AppColors.darkSurface
                            : AppColors.surface;
                        final textPrimaryColor = isDarkMode
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary;
                        final dividerColor = isDarkMode
                            ? AppColors.darkDivider
                            : AppColors.divider;

                        return Column(
                          children: [
                            InkWell(
                              onTap: () {
                                setState(() => _selectedDebtAccountId = acc.id);
                                Navigator.pop(context);
                              },
                              child: Container(
                                color: surfaceColor,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: acc.color.withValues(
                                          alpha: 0.15,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        acc.icon,
                                        color: acc.color,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            acc.name,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: textPrimaryColor,
                                            ),
                                          ),
                                          Text(
                                            formatAmount(balance),
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.getAmountColor(
                                                balance,
                                                isDarkMode,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (selected)
                                      Icon(
                                        Icons.check,
                                        color: colorScheme.primary,
                                      ),
                                  ],
                                ),
                              ),
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
            const SafeArea(top: false, child: SizedBox()),
          ],
        ),
      ),
    );
  }

  void _pickCategory(BuildContext context, List<Category> categories) {
    final isDarkMode = context.read<SettingsProvider>().isDarkMode;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDarkMode ? AppColors.darkSurface : Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
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
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 12),
            const Divider(),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                itemCount: categories.length,
                separatorBuilder: (context, i) =>
                    Divider(height: 1, color: dividerColor),
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
                      child: Icon(cat.icon, color: cat.color, size: 20),
                    ),
                    title: Text(cat.name),
                    trailing: _selectedCategoryId == cat.id
                        ? Icon(Icons.check, color: colorScheme.primary)
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
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }
}

class _TypeSelector extends StatelessWidget {
  final TransactionType selectedType;
  final ValueChanged<TransactionType> onChanged;

  const _TypeSelector({required this.selectedType, required this.onChanged});

  (IconData, Color) _getTypeStyle(TransactionType type) {
    switch (type) {
      case TransactionType.income:
        return (Icons.arrow_downward, Colors.green);
      case TransactionType.expense:
        return (Icons.arrow_upward, Colors.red);
      case TransactionType.transfer:
        return (Icons.swap_horiz, Colors.blue);
      case TransactionType.debtRepay:
        return (Icons.payment, Colors.orange);
      case TransactionType.debtTransfer:
        return (Icons.account_tree, AppColors.debtTransfer);
      case TransactionType.increaseBalance:
        return (Icons.add, AppColors.income);
      case TransactionType.decreaseBalance:
        return (Icons.remove, AppColors.expense);
    }
  }

  void _showTypePicker(BuildContext context) {
    final isDarkMode = context.read<SettingsProvider>().isDarkMode;
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      clipBehavior: Clip.antiAlias,
      backgroundColor: isDarkMode ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'เลือกประเภทรายการ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: EdgeInsets.zero,
                itemCount: TransactionType.values.length,
                itemBuilder: (context, index) {
                  final type = TransactionType.values[index];
                  final (icon, color) = _getTypeStyle(type);
                  return ListTile(
                    leading: Icon(icon, color: color),
                    title: Text(type.label),
                    trailing: selectedType == type
                        ? Icon(Icons.check, color: colorScheme.primary)
                        : null,
                    onTap: () {
                      onChanged(type);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showTypePicker(context),
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
          const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
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
    final isDarkMode = context.watch<SettingsProvider>().isDarkMode;
    final theme = Theme.of(context);
    return Container(
      color:
          theme.cardTheme.color ??
          (isDarkMode ? AppColors.darkSurface : AppColors.surface),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // หนี้สิน row
          InkWell(
            onTap: onDebtAccountTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: Text(
                      'หนี้สิน',
                      style: TextStyle(
                        fontSize: 15,
                        color: isDarkMode
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (selectedDebtAccount != null) ...[
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: selectedDebtAccount!.color.withValues(
                          alpha: 0.15,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        selectedDebtAccount!.icon,
                        color: selectedDebtAccount!.color,
                        size: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        selectedDebtAccount!.name,
                        style: TextStyle(
                          fontSize: 15,
                          color: isDarkMode
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ] else
                    Expanded(
                      child: Text(
                        'เลือกบัญชีหนี้สิน',
                        style: TextStyle(
                          fontSize: 15,
                          color: isDarkMode
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  Icon(
                    Icons.arrow_drop_down,
                    color: isDarkMode
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          // บัญชี row
          InkWell(
            onTap: onAccountTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: Text(
                      'บัญชี',
                      style: TextStyle(
                        fontSize: 15,
                        color: isDarkMode
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (selectedAccount != null) ...[
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: selectedAccount!.color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        selectedAccount!.icon,
                        color: selectedAccount!.color,
                        size: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        selectedAccount!.name,
                        style: TextStyle(
                          fontSize: 15,
                          color: isDarkMode
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ] else
                    Expanded(
                      child: Text(
                        'เลือกบัญชี',
                        style: TextStyle(
                          fontSize: 15,
                          color: isDarkMode
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  Icon(
                    Icons.arrow_drop_down,
                    color: isDarkMode
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          // หมวดหมู่ row
          InkWell(
            onTap: onCategoryTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: Text(
                      'หมวดหมู่',
                      style: TextStyle(
                        fontSize: 15,
                        color: isDarkMode
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (selectedCategory != null) ...[
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: selectedCategory!.color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        selectedCategory!.icon,
                        color: selectedCategory!.color,
                        size: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        selectedCategory!.name,
                        style: TextStyle(
                          fontSize: 15,
                          color: isDarkMode
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ] else
                    Expanded(
                      child: Text(
                        'เลือกหมวดหมู่ (ปล่อยว่างได้)',
                        style: TextStyle(
                          fontSize: 15,
                          color: isDarkMode
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  Icon(
                    Icons.arrow_drop_down,
                    color: isDarkMode
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                    size: 20,
                  ),
                ],
              ),
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
  final AccountProvider accountProvider;
  final List<AppTransaction> transactions;

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
    required this.accountProvider,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<SettingsProvider>().isDarkMode;
    final theme = Theme.of(context);
    final balance = selectedAccount != null
        ? accountProvider.getBalance(selectedAccount!.id, transactions)
        : 0.0;

    return Container(
      color:
          theme.cardTheme.color ??
          (isDarkMode ? AppColors.darkSurface : AppColors.surface),
      child: Row(
        children: [
          // Account selector
          Expanded(
            child: InkWell(
              onTap: onAccountTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                child: Row(
                  children: [
                    if (selectedAccount != null) ...[
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: selectedAccount!.color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          selectedAccount!.icon,
                          color: selectedAccount!.color,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedAccount!.name,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDarkMode
                                    ? AppColors.darkTextPrimary
                                    : AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              formatAmount(balance),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.getAmountColor(
                                  balance,
                                  isDarkMode,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else
                      SizedBox(
                        height: 36,
                        child: Center(
                          child: Text(
                            'เลือกบัญชี',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDarkMode
                                  ? AppColors.darkTextSecondary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Middle divider
          if (type != TransactionType.increaseBalance &&
              type != TransactionType.decreaseBalance)
            Container(
              width: 1,
              height: 60,
              color: isDarkMode ? AppColors.darkDivider : AppColors.divider,
            ),
          // Category / To-Account selector
          if (type != TransactionType.increaseBalance &&
              type != TransactionType.decreaseBalance)
            Expanded(
              child: InkWell(
                onTap: type.isTransferLike
                    ? onToAccountTap
                    : (type.supportsCategory ? onCategoryTap : null),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  child: Row(
                    children: [
                      if (type.isTransferLike && selectedToAccount != null) ...[
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: selectedToAccount!.color.withValues(
                              alpha: 0.15,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            selectedToAccount!.icon,
                            color: selectedToAccount!.color,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            selectedToAccount!.name,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDarkMode
                                  ? AppColors.darkTextPrimary
                                  : AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ] else if (type.supportsCategory &&
                          selectedCategory != null) ...[
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: selectedCategory!.color.withValues(
                              alpha: 0.15,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            selectedCategory!.icon,
                            color: selectedCategory!.color,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            selectedCategory!.name,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDarkMode
                                  ? AppColors.darkTextPrimary
                                  : AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ] else
                        SizedBox(
                          height: 36,
                          child: Center(
                            child: Text(
                              type.isTransferLike
                                  ? 'บัญชีปลายทาง'
                                  : 'เลือกหมวดหมู่',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDarkMode
                                    ? AppColors.darkTextSecondary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
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
    final isDarkMode = context.watch<SettingsProvider>().isDarkMode;
    final theme = Theme.of(context);
    return Container(
      color:
          theme.cardTheme.color ??
          (isDarkMode ? AppColors.darkSurface : AppColors.surface),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
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
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                filled: false,
              ),
              style: const TextStyle(fontSize: 16),
            ),
          ),
          Icon(
            icon,
            color: isDarkMode
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _CategorySelectionRow extends StatelessWidget {
  final Category? selectedCategory;
  final VoidCallback onTap;

  const _CategorySelectionRow({
    required this.selectedCategory,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<SettingsProvider>().isDarkMode;
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        color:
            theme.cardTheme.color ??
            (isDarkMode ? AppColors.darkSurface : AppColors.surface),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(
                'หมวดหมู่',
                style: TextStyle(
                  fontSize: 16,
                  color: isDarkMode
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                ),
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  if (selectedCategory != null) ...[
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: selectedCategory!.color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        selectedCategory!.icon,
                        color: selectedCategory!.color,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      selectedCategory?.name ?? 'เลือกหมวดหมู่',
                      style: TextStyle(
                        fontSize: 15,
                        color: isDarkMode
                            ? (selectedCategory != null
                                  ? AppColors.darkTextPrimary
                                  : AppColors.darkTextSecondary)
                            : (selectedCategory != null
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDarkMode
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
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
    final isDarkMode = context.watch<SettingsProvider>().isDarkMode;
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        color:
            theme.cardTheme.color ??
            (isDarkMode ? AppColors.darkSurface : AppColors.surface),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text(
              'วันและเวลา',
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              _formatThaiDateTime(dateTime),
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.calendar_today_outlined,
              color: isDarkMode
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  String _formatThaiDateTime(DateTime dt) {
    const thaiDays = ['จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา'];
    const thaiMonths = [
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
    final day = thaiDays[dt.weekday - 1];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$day. ${dt.day} ${thaiMonths[dt.month - 1]} ${dt.year} $h:$m';
  }
}
