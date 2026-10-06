import 'package:flutter/material.dart';
import 'package:money_vibe/providers/recurring_transaction_provider.dart';
import 'package:provider/provider.dart';
import '../../models/transaction.dart';
import '../../models/account.dart';
import '../../models/category.dart';
import '../../providers/account_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../main.dart';
import '../../widgets/account_picker_bottom_sheet.dart';
import '../../widgets/category_picker_bottom_sheet.dart';
import '../../widgets/calculator_keyboard.dart';
import '../../widgets/app_bar_buttons.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_date_picker_sheet.dart';
import 'transaction_type_picker.dart';
import 'transaction_amount_hero_card.dart';
import 'transaction_selection_group_card.dart';
import 'transaction_meta_info_card.dart';

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
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _amountFocusNode = FocusNode();
  final _toAmountFocusNode = FocusNode();
  PersistentBottomSheetController? _keyboardController;
  TextEditingController? _activeKeyboardController;
  bool _isUpdatingController = false;

  final _amountController = TextEditingController();
  final _toAmountController =
      TextEditingController(); // cross-currency transfer
  final _noteController = TextEditingController();

  late TransactionType _type;
  String? _selectedAccountId;
  String? _selectedCategoryId;
  String? _selectedToAccountId;
  String? _selectedDebtAccountId;
  late DateTime _selectedDateTime;

  double _accountBalance = 0.0;
  bool _isLoading = false;

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
    _toAmountController.text = (tx?.toAmount != null && tx!.toAmount! > 0)
        ? formatAmount(tx.toAmount!)
        : '';
    _noteController.text = tx?.note ?? '';

    _amountFocusNode.addListener(_onFocusChange);
    _toAmountFocusNode.addListener(_onFocusChange);
    _amountController.addListener(_handleAmountChanged);
    _toAmountController.addListener(_handleToAmountChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateAccountBalance();
    });
  }

  @override
  void dispose() {
    _amountFocusNode.removeListener(_onFocusChange);
    _toAmountFocusNode.removeListener(_onFocusChange);
    _amountController.removeListener(_handleAmountChanged);
    _toAmountController.removeListener(_handleToAmountChanged);
    _amountFocusNode.dispose();
    _toAmountFocusNode.dispose();
    _amountController.dispose();
    _toAmountController.dispose();
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

  void _onFocusChange() {
    if (!mounted) return;

    final hasAmountFocus = _amountFocusNode.hasFocus;
    final hasToAmountFocus = _toAmountFocusNode.hasFocus;

    if (hasAmountFocus) {
      _showKeyboard(_amountController);
    } else if (hasToAmountFocus) {
      _showKeyboard(_toAmountController);
    } else {
      _closeKeyboard();
    }
  }

  void _handleAmountChanged() {
    if (_isUpdatingController) return;
    _isUpdatingController = true;
    try {
      final text = _amountController.text;
      final hasOperator = RegExp(r'[+\-*/]').hasMatch(text);

      if (!hasOperator) {
        _formatAmountInput(text);
      } else {
        // Strip commas if operator is present
        final sanitized = text.replaceAll(',', '');
        if (text != sanitized) {
          final selection = _amountController.selection;
          int commasBeforeCursor = 0;
          if (selection.isValid) {
            final textBeforeCursor = text.substring(0, selection.end);
            commasBeforeCursor = ','.allMatches(textBeforeCursor).length;
          }
          final newOffset = selection.isValid
              ? (selection.end - commasBeforeCursor).clamp(0, sanitized.length)
              : sanitized.length;

          _amountController.value = TextEditingValue(
            text: sanitized,
            selection: TextSelection.collapsed(offset: newOffset),
          );
        }
      }

      _calculateAccountBalance();
      if (_type.requiresDebtAccount) {
        setState(() {});
      }
    } finally {
      _isUpdatingController = false;
    }
  }

  void _handleToAmountChanged() {
    if (_isUpdatingController) return;
    _isUpdatingController = true;
    try {
      final text = _toAmountController.text;
      final hasOperator = RegExp(r'[+\-*/]').hasMatch(text);

      if (!hasOperator) {
        _formatToAmountInput(text);
      } else {
        // Strip commas if operator is present
        final sanitized = text.replaceAll(',', '');
        if (text != sanitized) {
          final selection = _toAmountController.selection;
          int commasBeforeCursor = 0;
          if (selection.isValid) {
            final textBeforeCursor = text.substring(0, selection.end);
            commasBeforeCursor = ','.allMatches(textBeforeCursor).length;
          }
          final newOffset = selection.isValid
              ? (selection.end - commasBeforeCursor).clamp(0, sanitized.length)
              : sanitized.length;

          _toAmountController.value = TextEditingValue(
            text: sanitized,
            selection: TextSelection.collapsed(offset: newOffset),
          );
        }
      }

      setState(() {});
    } finally {
      _isUpdatingController = false;
    }
  }

  Color _getActionButtonColor() {
    final isDarkMode = context.read<SettingsProvider>().isDarkMode;
    switch (_type) {
      case TransactionType.income:
      case TransactionType.increaseBalance:
        return isDarkMode ? AppColors.darkIncome : AppColors.income;
      case TransactionType.expense:
      case TransactionType.decreaseBalance:
        return isDarkMode ? AppColors.darkExpense : AppColors.expense;
      case TransactionType.transfer:
        return isDarkMode ? AppColors.darkTransfer : AppColors.transfer;
      case TransactionType.debtRepay:
        return isDarkMode ? AppColors.darkDebtRepay : AppColors.debtRepay;
      case TransactionType.debtTransfer:
        return isDarkMode ? AppColors.darkDebtTransfer : AppColors.debtTransfer;
    }
  }

  void _showKeyboard(TextEditingController controller) {
    if (_keyboardController != null) {
      if (_activeKeyboardController == controller) {
        return;
      }
      _closeKeyboard();
    }

    _activeKeyboardController = controller;
    final actionColor = _getActionButtonColor();

    _keyboardController = _scaffoldKey.currentState?.showBottomSheet(
      (context) {
        return CalculatorKeyboard(
          controller: controller,
          actionButtonColor: actionColor,
          onDone: () {
            _closeKeyboard();
          },
        );
      },
      backgroundColor: Colors.transparent,
      elevation: 0,
    );

    _keyboardController?.closed.then((_) {
      _keyboardController = null;
      _activeKeyboardController = null;
      if (mounted) {
        if (_amountFocusNode.hasFocus) {
          _amountFocusNode.unfocus();
        }
        if (_toAmountFocusNode.hasFocus) {
          _toAmountFocusNode.unfocus();
        }
      }
    });
  }

  void _closeKeyboard() {
    if (_keyboardController != null) {
      _keyboardController?.close();
      _keyboardController = null;
      _activeKeyboardController = null;
    }
    if (_amountFocusNode.hasFocus) {
      _amountFocusNode.unfocus();
    }
    if (_toAmountFocusNode.hasFocus) {
      _toAmountFocusNode.unfocus();
    }
  }

  /// Format amount with commas while typing
  void _formatAmountInput(String value) {
    final raw = value.replaceAll(',', '');
    if (raw.isEmpty) {
      if (_amountController.text.isNotEmpty) {
        _amountController.text = '';
        _amountController.selection = const TextSelection.collapsed(offset: 0);
      }
      return;
    }

    final hasDecimal = raw.contains('.');
    final parts = raw.split('.');
    final intPart = parts[0];

    final formattedInt = intPart.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );

    String formatted;
    if (hasDecimal && parts.length > 1) {
      formatted = '$formattedInt.${parts[1]}';
    } else {
      formatted = formattedInt;
    }

    if (_amountController.text != formatted) {
      _amountController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  void _formatToAmountInput(String value) {
    final raw = value.replaceAll(',', '');
    if (raw.isEmpty) {
      if (_toAmountController.text.isNotEmpty) {
        _toAmountController.text = '';
        _toAmountController.selection = const TextSelection.collapsed(
          offset: 0,
        );
      }
      return;
    }

    final hasDecimal = raw.contains('.');
    final parts = raw.split('.');
    final intPart = parts[0];

    final formattedInt = intPart.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );

    String formatted;
    if (hasDecimal && parts.length > 1) {
      formatted = '$formattedInt.${parts[1]}';
    } else {
      formatted = formattedInt;
    }

    if (_toAmountController.text != formatted) {
      _toAmountController.value = TextEditingValue(
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
    final accountProvider = context.read<AccountProvider>();

    String? toAccountId;
    if (_type == TransactionType.transfer) {
      toAccountId = _selectedToAccountId;
    } else if (_type.requiresDebtAccount) {
      toAccountId = _selectedDebtAccountId;
    }

    // cross-currency: ตรวจสอบว่า from/to account ต่างสกุลเงินกัน
    double? toAmount;
    if (_type == TransactionType.transfer && toAccountId != null) {
      final fromAcc = accountProvider.findById(_selectedAccountId!);
      final toAcc = accountProvider.findById(toAccountId);
      if (fromAcc != null &&
          toAcc != null &&
          fromAcc.currency != toAcc.currency) {
        final toAmountText = _toAmountController.text
            .replaceAll(',', '')
            .trim();
        toAmount = double.tryParse(toAmountText);
        if (toAmount == null || toAmount <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('กรุณากรอกจำนวนที่ได้รับ')),
          );
          return;
        }
      }
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
      toAmount: toAmount,
    );

    setState(() => _isLoading = true);

    try {
      if (_isEditing) {
        await txProvider.updateTransaction(tx);
      } else {
        await txProvider.addTransaction(tx);
      }

      widget.onSaved?.call(tx.id);
      if (mounted) {
        _closeKeyboard();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'เกิดข้อผิดพลาดในการบันทึก: $e',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'ลบรายการ',
      message: 'คุณต้องการที่จะลบรายการนี้ใช่หรือไม่?',
      confirmLabel: 'ลบ',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    final transactionId = widget.transaction!.id;

    // Check if this transaction is linked to a recurring occurrence
    final recurProvider = context.read<RecurringTransactionProvider>();
    final occ = recurProvider.findOccurrenceByTransactionId(transactionId);

    // Delete the transaction
    context.read<TransactionProvider>().deleteTransaction(transactionId);

    // If linked to a recurring occurrence, undo it
    if (occ != null) {
      recurProvider.undoOccurrence(occ.recurringId, occ.dueDate);
    }

    _closeKeyboard();
    Navigator.pop(context); // Close form
  }

  void _selectType(TransactionType t) {
    _closeKeyboard();
    setState(() {
      _type = t;
      _selectedCategoryId = null;
      if (t != TransactionType.transfer) {
        _selectedToAccountId = null;
      }
      if (!t.requiresDebtAccount) {
        _selectedDebtAccountId = null;
      }
      _calculateAccountBalance();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<SettingsProvider>().isDarkMode;
    final textPrimary = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final textSecondary = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final bgColor = isDarkMode
        ? AppColors.darkBackground
        : AppColors.background;

    return Consumer3<AccountProvider, TransactionProvider, CategoryProvider>(
      builder: (context, accountProvider, txProvider, catProvider, _) {
        final allVisibleAccounts = accountProvider.visibleAccounts;

        final accounts = switch (_type) {
          TransactionType.debtTransfer =>
            allVisibleAccounts
                .where(
                  (a) =>
                      (a.type == AccountType.debt ||
                          a.type == AccountType.creditCard) &&
                      !a.isPortfolio,
                )
                .toList(),
          TransactionType.income ||
          TransactionType.expense ||
          TransactionType.debtRepay =>
            allVisibleAccounts
                .where((a) => a.type != AccountType.debt && !a.isPortfolio)
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
          key: _scaffoldKey,
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: bgColor,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: true,
            leadingWidth: 64,
            leading: AppCloseButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      _closeKeyboard();
                      Navigator.pop(context);
                    },
            ),
            title: Text(
              _isEditing ? 'แก้ไขรายการ' : 'บันทึกรายการ',
              style: TextStyle(
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            actions: [AppSaveButton(onPressed: _save, isLoading: _isLoading)],
          ),
          body: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              FocusScope.of(context).unfocus();
              _closeKeyboard();
            },
            child: AbsorbPointer(
              absorbing: _isLoading,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                children: [
                  // 1. iOS Type Selector (Segmented Tabs)
                  TransactionTypeSegmentedControl(
                    selectedType: _type,
                    onChanged: _selectType,
                    onShowMore: () {
                      _closeKeyboard();
                      showTransactionTypePicker(
                        context,
                        currentType: _type,
                        onSelected: _selectType,
                      );
                    },
                  ),
                  const SizedBox(height: 14),

                  // 2. Amount Hero Card
                  TransactionAmountHeroCard(
                    type: _type,
                    amountController: _amountController,
                    amountFocusNode: _amountFocusNode,
                    toAmountController: _toAmountController,
                    toAmountFocusNode: _toAmountFocusNode,
                    selectedAccount: selectedAccount,
                    selectedToAccount: selectedToAccount,
                    accountBalance: _accountBalance,
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 18),

                  // 3. Selection Section (Grouped Inset Card)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'ข้อมูลรายการ',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TransactionSelectionGroupCard(
                    type: _type,
                    accounts: accounts,
                    selectedAccount: selectedAccount,
                    selectedToAccount: selectedToAccount,
                    selectedDebtAccount: selectedDebtAccount,
                    selectedCategory: selectedCategory,
                    categories: categories,
                    accountProvider: accountProvider,
                    transactions: txProvider.transactions,
                    isDarkMode: isDarkMode,
                    onPickAccount: (isTarget) =>
                        _pickAccount(context, accounts, isTarget),
                    onPickDebtAccount: () =>
                        _pickDebtAccount(context, accountProvider),
                    onClearAccount: () =>
                        setState(() => _selectedAccountId = null),
                    onPickCategory: () => _pickCategory(context, categories),
                  ),
                  const SizedBox(height: 18),

                  // 4. Meta Information Section (Date & Note)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'รายละเอียดเพิ่มเติม',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TransactionMetaInfoCard(
                    selectedDateTime: _selectedDateTime,
                    noteController: _noteController,
                    isDarkMode: isDarkMode,
                    onPickDateTime: () => _pickDateTime(context),
                  ),

                  // 5. Destructive delete button at bottom (iOS Settings pattern)
                  if (_isEditing) ...[
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? AppColors.darkSurface
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadii.xLarge),
                        border: Border.all(
                          color: AppColors.borderFor(isDarkMode),
                          width: 1,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadii.xLarge),
                        onTap: _isLoading ? null : _delete,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                size: 20,
                                color: isDarkMode
                                    ? AppColors.darkExpense
                                    : AppColors.expense,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'ลบรายการนี้',
                                style: TextStyle(
                                  color: isDarkMode
                                      ? AppColors.darkExpense
                                      : AppColors.expense,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAccount(
    BuildContext context,
    List<Account> accounts,
    bool isTarget,
  ) async {
    _closeKeyboard();
    final selectedId = await AccountPickerBottomSheet.show(
      context,
      title: isTarget ? 'เลือกบัญชีปลายทาง' : 'เลือกบัญชี',
      selectedAccountId: isTarget ? _selectedToAccountId : _selectedAccountId,
      accountsOverride: accounts,
    );

    if (selectedId != null && mounted) {
      setState(() {
        if (isTarget) {
          _selectedToAccountId = selectedId;
        } else {
          _selectedAccountId = selectedId;
        }
      });
      _calculateAccountBalance();
    }
  }

  Future<void> _pickDebtAccount(
    BuildContext context,
    AccountProvider accountProvider,
  ) async {
    _closeKeyboard();
    final selectedId = await AccountPickerBottomSheet.show(
      context,
      title: 'เลือกบัญชีหนี้สิน',
      selectedAccountId: _selectedDebtAccountId,
      isDebtOnly: true,
    );

    if (selectedId != null && mounted) {
      setState(() {
        _selectedDebtAccountId = selectedId;
      });
    }
  }

  Future<void> _pickCategory(
    BuildContext context,
    List<Category> categories,
  ) async {
    _closeKeyboard();
    final selectedId = await CategoryPickerBottomSheet.show(
      context,
      selectedCategoryId: _selectedCategoryId,
      categories: categories,
    );

    if (selectedId != null && mounted) {
      setState(() {
        _selectedCategoryId = selectedId;
      });
    }
  }

  Future<void> _pickDateTime(BuildContext context) async {
    _closeKeyboard();
    final initialDt = _selectedDateTime;
    final picked = await showAppDatePicker(
      context: context,
      initialDate: initialDt,
      title: 'เลือกวันและเวลา',
      includeTime: true,
    );
    if (picked == null || !mounted) return;

    setState(() => _selectedDateTime = picked);
  }
}
