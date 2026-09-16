import 'package:flutter/material.dart';
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
import '../../theme/app_radii.dart';
import '../../main.dart';
import '../../widgets/account_icon_widget.dart';
import '../../widgets/app_modal_bottom_sheet.dart';
import '../../widgets/account_picker_bottom_sheet.dart';
import '../../widgets/category_picker_bottom_sheet.dart';
import '../../widgets/calculator_keyboard.dart';
import '../../widgets/calculator_text_field_config.dart';

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

  void _delete() {
    final isDarkMode = context.read<SettingsProvider>().isDarkMode;
    final bgColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
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

              _closeKeyboard();
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
            leading: Center(
              child: Material(
                color: isDarkMode ? AppColors.darkSurface : AppColors.surface,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: 'ปิด',
                  onPressed: _isLoading
                      ? null
                      : () {
                          _closeKeyboard();
                          Navigator.pop(context);
                        },
                ),
              ),
            ),
            title: Text(
              _isEditing ? 'แก้ไขรายการ' : 'บันทึกรายการ',
              style: TextStyle(
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            actions: [
              if (_isEditing)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Material(
                    color: isDarkMode
                        ? AppColors.darkSurface
                        : AppColors.surface,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: IconButton(
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        size: 20,
                        color: isDarkMode
                            ? AppColors.darkExpense
                            : AppColors.expense,
                      ),
                      onPressed: _isLoading ? null : _delete,
                      tooltip: 'ลบรายการ',
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Material(
                    color: isDarkMode
                        ? AppColors.darkFabYellow
                        : AppColors.fabYellow,
                    borderRadius: BorderRadius.circular(AppRadii.full),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: _isLoading ? null : _save,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.black,
                                  ),
                                ),
                              )
                            : const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Colors.black,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'บันทึก',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
                  _TypeSegmentedControl(
                    selectedType: _type,
                    isDarkMode: isDarkMode,
                    onChanged: _selectType,
                    onShowMore: () => _showAllTypePicker(context),
                  ),
                  const SizedBox(height: 14),

                  // 2. Amount Hero Card
                  _AmountHeroCard(
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
                  _SelectionGroupCard(
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
                  _MetaInfoCard(
                    selectedDateTime: _selectedDateTime,
                    noteController: _noteController,
                    isDarkMode: isDarkMode,
                    onPickDateTime: () => _pickDateTime(context),
                  ),

                  // 5. Destructive delete button at bottom (iOS Settings pattern)
                  if (_isEditing) ...[
                    const SizedBox(height: 20),
                    Material(
                      color: isDarkMode
                          ? AppColors.darkSurface
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadii.xLarge),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
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

  void _showAllTypePicker(BuildContext context) {
    _closeKeyboard();
    final isDarkMode = context.read<SettingsProvider>().isDarkMode;
    final textPrimary = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;
    final colorScheme = Theme.of(context).colorScheme;

    showAppModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            const AppModalBottomSheetHeader(title: 'เลือกประเภทรายการ'),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: TransactionType.values.length,
                separatorBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(left: 68),
                  child: Divider(height: 1, color: dividerColor),
                ),
                itemBuilder: (context, index) {
                  final type = TransactionType.values[index];
                  final (icon, color) = _getTypeStyle(type, isDarkMode);
                  final isSelected = _type == type;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(AppRadii.large),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    title: Text(
                      type.label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: textPrimary,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: colorScheme.primary,
                            size: 22,
                          )
                        : null,
                    onTap: () {
                      _selectType(type);
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

  static (IconData, Color) _getTypeStyle(
    TransactionType type,
    bool isDarkMode,
  ) {
    switch (type) {
      case TransactionType.income:
        return (
          Icons.arrow_downward_rounded,
          isDarkMode ? AppColors.darkIncome : AppColors.income,
        );
      case TransactionType.expense:
        return (
          Icons.arrow_upward_rounded,
          isDarkMode ? AppColors.darkExpense : AppColors.expense,
        );
      case TransactionType.transfer:
        return (
          Icons.swap_horiz_rounded,
          isDarkMode ? AppColors.darkTransfer : AppColors.transfer,
        );
      case TransactionType.debtRepay:
        return (
          Icons.payment_rounded,
          isDarkMode ? AppColors.darkDebtRepay : AppColors.debtRepay,
        );
      case TransactionType.debtTransfer:
        return (
          Icons.account_tree_rounded,
          isDarkMode ? AppColors.darkDebtTransfer : AppColors.debtTransfer,
        );
      case TransactionType.increaseBalance:
        return (
          Icons.add_rounded,
          isDarkMode ? AppColors.darkIncome : AppColors.income,
        );
      case TransactionType.decreaseBalance:
        return (
          Icons.remove_rounded,
          isDarkMode ? AppColors.darkExpense : AppColors.expense,
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. iOS Segmented Type Control
// ─────────────────────────────────────────────────────────────────────────────
class _TypeSegmentedControl extends StatelessWidget {
  final TransactionType selectedType;
  final bool isDarkMode;
  final ValueChanged<TransactionType> onChanged;
  final VoidCallback onShowMore;

  const _TypeSegmentedControl({
    required this.selectedType,
    required this.isDarkMode,
    required this.onChanged,
    required this.onShowMore,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final selectedSurface = isDarkMode
        ? AppColors.darkSurfaceVariant
        : AppColors.sectionHeader;
    final primary = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final secondary = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;

    // Check if the current type is one of the 3 primary ones
    final isPrimary =
        selectedType == TransactionType.expense ||
        selectedType == TransactionType.income ||
        selectedType == TransactionType.transfer;

    final otherLabel = switch (selectedType) {
      TransactionType.debtRepay => 'ชำระหนี้ ▾',
      TransactionType.debtTransfer => 'โอนหนี้ ▾',
      TransactionType.increaseBalance => 'ปรับเพิ่ม ▾',
      TransactionType.decreaseBalance => 'ปรับลด ▾',
      _ => 'อื่นๆ ▾',
    };

    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(AppRadii.xLarge),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            _buildTab(
              label: 'รายจ่าย',
              isSelected: selectedType == TransactionType.expense,
              selectedSurface: selectedSurface,
              primary: primary,
              secondary: secondary,
              onTap: () => onChanged(TransactionType.expense),
            ),
            _buildTab(
              label: 'รายรับ',
              isSelected: selectedType == TransactionType.income,
              selectedSurface: selectedSurface,
              primary: primary,
              secondary: secondary,
              onTap: () => onChanged(TransactionType.income),
            ),
            _buildTab(
              label: 'โอน',
              isSelected: selectedType == TransactionType.transfer,
              selectedSurface: selectedSurface,
              primary: primary,
              secondary: secondary,
              onTap: () => onChanged(TransactionType.transfer),
            ),
            _buildTab(
              label: otherLabel,
              isSelected: !isPrimary,
              selectedSurface: selectedSurface,
              primary: primary,
              secondary: secondary,
              onTap: onShowMore,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab({
    required String label,
    required bool isSelected,
    required Color selectedSurface,
    required Color primary,
    required Color secondary,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: isSelected ? selectedSurface : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.large),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isSelected ? primary : secondary,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Amount Hero Card (The Core Financial Input)
// ─────────────────────────────────────────────────────────────────────────────
class _AmountHeroCard extends StatelessWidget {
  final TransactionType type;
  final TextEditingController amountController;
  final FocusNode amountFocusNode;
  final TextEditingController toAmountController;
  final FocusNode toAmountFocusNode;
  final Account? selectedAccount;
  final Account? selectedToAccount;
  final double accountBalance;
  final bool isDarkMode;

  const _AmountHeroCard({
    required this.type,
    required this.amountController,
    required this.amountFocusNode,
    required this.toAmountController,
    required this.toAmountFocusNode,
    required this.selectedAccount,
    required this.selectedToAccount,
    required this.accountBalance,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final surfaceVariant = isDarkMode
        ? AppColors.darkSurfaceVariant
        : AppColors.sectionHeader;
    final textPrimary = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final textSecondary = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;

    final fromCurrency = selectedAccount?.currency == 'USD' ? 'USD' : 'THB';
    final toCurrency = selectedToAccount?.currency == 'USD' ? 'USD' : 'THB';
    final isCrossCurrency =
        type == TransactionType.transfer &&
        selectedAccount != null &&
        selectedToAccount != null &&
        selectedAccount!.currency != selectedToAccount!.currency;

    final isAdjust =
        type == TransactionType.increaseBalance ||
        type == TransactionType.decreaseBalance;

    final typeColor = switch (type) {
      TransactionType.income || TransactionType.increaseBalance =>
        isDarkMode ? AppColors.darkIncome : AppColors.income,
      TransactionType.expense || TransactionType.decreaseBalance =>
        isDarkMode ? AppColors.darkExpense : AppColors.expense,
      TransactionType.transfer =>
        isDarkMode ? AppColors.darkTransfer : AppColors.transfer,
      TransactionType.debtRepay || TransactionType.debtTransfer =>
        isDarkMode ? AppColors.darkDebtTransfer : AppColors.debtTransfer,
    };

    final amountLabel = switch (type) {
      TransactionType.debtRepay => 'เงินต้น',
      TransactionType.debtTransfer => 'ยอดโยก',
      TransactionType.increaseBalance => 'ยอดปรับเพิ่ม',
      TransactionType.decreaseBalance => 'ยอดปรับลด',
      _ => 'จำนวนเงิน',
    };

    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(AppRadii.sheet),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (!amountFocusNode.hasFocus) {
            amountFocusNode.requestFocus();
          }
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.sheet),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row inside card: Label + Currency badge
              Row(
                children: [
                  Text(
                    amountLabel,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: surfaceVariant,
                      borderRadius: BorderRadius.circular(AppRadii.small),
                    ),
                    child: Text(
                      fromCurrency,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Primary amount row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    fromCurrency == 'USD' ? '\$ ' : '฿ ',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: typeColor,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: amountController,
                      focusNode: amountFocusNode,
                      readOnly: calculatorTextFieldReadOnly,
                      showCursor: true,
                      keyboardType: calculatorTextInputType,
                      inputFormatters: calculatorTextInputFormatters,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                        letterSpacing: -0.5,
                      ),
                      decoration: InputDecoration(
                        hintText: '0.00',
                        hintStyle: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: isDarkMode
                              ? AppColors.darkDivider
                              : AppColors.divider,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 6,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Cross-currency conversion field
              if (isCrossCurrency) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: dividerColor),
                ),
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_downward_rounded,
                        size: 14,
                        color: typeColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'จำนวนที่ได้รับปลายทาง',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: surfaceVariant,
                        borderRadius: BorderRadius.circular(AppRadii.small),
                      ),
                      child: Text(
                        toCurrency,
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      toCurrency == 'USD' ? '\$ ' : '฿ ',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: typeColor,
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: toAmountController,
                        focusNode: toAmountFocusNode,
                        readOnly: calculatorTextFieldReadOnly,
                        showCursor: true,
                        keyboardType: calculatorTextInputType,
                        inputFormatters: calculatorTextInputFormatters,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                          letterSpacing: -0.5,
                        ),
                        decoration: InputDecoration(
                          hintText: '0.00',
                          hintStyle: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: isDarkMode
                                ? AppColors.darkDivider
                                : AppColors.divider,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              // Balance preview badge (for increase/decrease balance)
              if (isAdjust) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: surfaceVariant,
                    borderRadius: BorderRadius.circular(AppRadii.large),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 16,
                        color: textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ยอดคงเหลือหลังปรับ:',
                        style: TextStyle(color: textSecondary, fontSize: 13),
                      ),
                      const Spacer(),
                      Text(
                        '฿ ${NumberFormat('#,##0.00').format(accountBalance)}',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. Selection Group Card (Grouped Inset Card for Account & Category)
// ─────────────────────────────────────────────────────────────────────────────
class _SelectionGroupCard extends StatelessWidget {
  final TransactionType type;
  final List<Account> accounts;
  final Account? selectedAccount;
  final Account? selectedToAccount;
  final Account? selectedDebtAccount;
  final Category? selectedCategory;
  final List<Category> categories;
  final AccountProvider accountProvider;
  final List<AppTransaction> transactions;
  final bool isDarkMode;
  final ValueChanged<bool> onPickAccount;
  final VoidCallback onPickDebtAccount;
  final VoidCallback onClearAccount;
  final VoidCallback onPickCategory;

  const _SelectionGroupCard({
    required this.type,
    required this.accounts,
    required this.selectedAccount,
    required this.selectedToAccount,
    required this.selectedDebtAccount,
    required this.selectedCategory,
    required this.categories,
    required this.accountProvider,
    required this.transactions,
    required this.isDarkMode,
    required this.onPickAccount,
    required this.onPickDebtAccount,
    required this.onClearAccount,
    required this.onPickCategory,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;

    final bool isDebtRepay = type == TransactionType.debtRepay;
    final bool isDebtTransfer = type == TransactionType.debtTransfer;
    final bool isTransfer = type == TransactionType.transfer;
    final bool isAdjust =
        type == TransactionType.increaseBalance ||
        type == TransactionType.decreaseBalance;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppRadii.sheet),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (isDebtRepay) ...[
            // 1. Debt Account
            _SelectionRow(
              title: selectedDebtAccount?.name ?? 'เลือกบัญชีหนี้สิน',
              subtitle: selectedDebtAccount != null
                  ? 'ยอดหนี้ ฿ ${formatAmount(accountProvider.getBalance(selectedDebtAccount!.id, transactions))}'
                  : 'หนี้สินที่ต้องการชำระ',
              subtitleColor: selectedDebtAccount != null
                  ? AppColors.getAmountColor(
                      accountProvider.getBalance(
                        selectedDebtAccount!.id,
                        transactions,
                      ),
                      isDarkMode,
                    )
                  : null,
              iconWidget: selectedDebtAccount != null
                  ? AccountIconWidget(
                      account: selectedDebtAccount!,
                      size: 40,
                      isDarkMode: isDarkMode,
                    )
                  : _defaultIconBox(
                      Icons.credit_card_rounded,
                      Colors.orange,
                      isDarkMode,
                    ),
              onTap: onPickDebtAccount,
              isDarkMode: isDarkMode,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 68),
              child: Divider(height: 1, color: dividerColor),
            ),
            // 2. Payment Source Account
            _SelectionRow(
              title: selectedAccount?.name ?? 'เลือกบัญชีที่ใช้ชำระ',
              subtitle: selectedAccount != null
                  ? 'คงเหลือ ฿ ${formatAmount(accountProvider.getBalance(selectedAccount!.id, transactions))}'
                  : 'ปล่อยว่างได้หากชำระภายนอก',
              subtitleColor: selectedAccount != null
                  ? AppColors.getAmountColor(
                      accountProvider.getBalance(
                        selectedAccount!.id,
                        transactions,
                      ),
                      isDarkMode,
                    )
                  : null,
              iconWidget: selectedAccount != null
                  ? AccountIconWidget(
                      account: selectedAccount!,
                      size: 40,
                      isDarkMode: isDarkMode,
                    )
                  : _defaultIconBox(
                      Icons.account_balance_wallet_outlined,
                      isDarkMode
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                      isDarkMode,
                    ),
              trailing: selectedAccount != null
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'ล้างบัญชี',
                      onPressed: onClearAccount,
                    )
                  : null,
              onTap: () => onPickAccount(false),
              isDarkMode: isDarkMode,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 68),
              child: Divider(height: 1, color: dividerColor),
            ),
            // 3. Category (Optional)
            _SelectionRow(
              title: selectedCategory?.name ?? 'เลือกหมวดหมู่',
              subtitle: selectedCategory != null
                  ? 'หมวดหมู่รายการ'
                  : 'ปล่อยว่างได้',
              iconWidget: selectedCategory != null
                  ? _categoryIconBox(selectedCategory!)
                  : _defaultIconBox(
                      Icons.category_outlined,
                      isDarkMode
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                      isDarkMode,
                    ),
              onTap: onPickCategory,
              isDarkMode: isDarkMode,
            ),
          ] else if (isDebtTransfer) ...[
            // 1. From Debt Account
            _SelectionRow(
              title: selectedAccount?.name ?? 'เลือกบัญชีหนี้สินต้นทาง',
              subtitle: selectedAccount != null
                  ? 'ยอดหนี้ ฿ ${formatAmount(accountProvider.getBalance(selectedAccount!.id, transactions))}'
                  : 'โอนออกจากหนี้สินนี้',
              subtitleColor: selectedAccount != null
                  ? AppColors.getAmountColor(
                      accountProvider.getBalance(
                        selectedAccount!.id,
                        transactions,
                      ),
                      isDarkMode,
                    )
                  : null,
              iconWidget: selectedAccount != null
                  ? AccountIconWidget(
                      account: selectedAccount!,
                      size: 40,
                      isDarkMode: isDarkMode,
                    )
                  : _defaultIconBox(
                      Icons.account_tree_outlined,
                      Colors.orange,
                      isDarkMode,
                    ),
              onTap: () => onPickAccount(false),
              isDarkMode: isDarkMode,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 68),
              child: Divider(height: 1, color: dividerColor),
            ),
            // 2. To Debt Account
            _SelectionRow(
              title: selectedDebtAccount?.name ?? 'เลือกบัญชีหนี้สินปลายทาง',
              subtitle: selectedDebtAccount != null
                  ? 'ยอดหนี้ ฿ ${formatAmount(accountProvider.getBalance(selectedDebtAccount!.id, transactions))}'
                  : 'โอนเข้าสู่หนี้สินนี้',
              subtitleColor: selectedDebtAccount != null
                  ? AppColors.getAmountColor(
                      accountProvider.getBalance(
                        selectedDebtAccount!.id,
                        transactions,
                      ),
                      isDarkMode,
                    )
                  : null,
              iconWidget: selectedDebtAccount != null
                  ? AccountIconWidget(
                      account: selectedDebtAccount!,
                      size: 40,
                      isDarkMode: isDarkMode,
                    )
                  : _defaultIconBox(
                      Icons.account_tree_rounded,
                      Colors.orange,
                      isDarkMode,
                    ),
              onTap: onPickDebtAccount,
              isDarkMode: isDarkMode,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 68),
              child: Divider(height: 1, color: dividerColor),
            ),
            // 3. Category (Optional)
            _SelectionRow(
              title: selectedCategory?.name ?? 'เลือกหมวดหมู่',
              subtitle: selectedCategory != null
                  ? 'หมวดหมู่รายการ'
                  : 'ปล่อยว่างได้',
              iconWidget: selectedCategory != null
                  ? _categoryIconBox(selectedCategory!)
                  : _defaultIconBox(
                      Icons.category_outlined,
                      isDarkMode
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                      isDarkMode,
                    ),
              onTap: onPickCategory,
              isDarkMode: isDarkMode,
            ),
          ] else if (isTransfer) ...[
            // Transfer: From Account
            _SelectionRow(
              title: selectedAccount?.name ?? 'เลือกบัญชีต้นทาง',
              subtitle: selectedAccount != null
                  ? 'คงเหลือ ฿ ${formatAmount(accountProvider.getBalance(selectedAccount!.id, transactions))}'
                  : 'โอนออกจากบัญชีนี้',
              subtitleColor: selectedAccount != null
                  ? AppColors.getAmountColor(
                      accountProvider.getBalance(
                        selectedAccount!.id,
                        transactions,
                      ),
                      isDarkMode,
                    )
                  : null,
              iconWidget: selectedAccount != null
                  ? AccountIconWidget(
                      account: selectedAccount!,
                      size: 40,
                      isDarkMode: isDarkMode,
                    )
                  : _defaultIconBox(
                      Icons.account_balance_wallet_outlined,
                      Colors.blue,
                      isDarkMode,
                    ),
              onTap: () => onPickAccount(false),
              isDarkMode: isDarkMode,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 68),
              child: Divider(height: 1, color: dividerColor),
            ),
            // Transfer: To Account
            _SelectionRow(
              title: selectedToAccount?.name ?? 'เลือกบัญชีปลายทาง',
              subtitle: selectedToAccount != null
                  ? 'คงเหลือ ฿ ${formatAmount(accountProvider.getBalance(selectedToAccount!.id, transactions))}'
                  : 'โอนเข้าสู่บัญชีนี้',
              subtitleColor: selectedToAccount != null
                  ? AppColors.getAmountColor(
                      accountProvider.getBalance(
                        selectedToAccount!.id,
                        transactions,
                      ),
                      isDarkMode,
                    )
                  : null,
              iconWidget: selectedToAccount != null
                  ? AccountIconWidget(
                      account: selectedToAccount!,
                      size: 40,
                      isDarkMode: isDarkMode,
                    )
                  : _defaultIconBox(
                      Icons.input_rounded,
                      Colors.blue,
                      isDarkMode,
                    ),
              onTap: () => onPickAccount(true),
              isDarkMode: isDarkMode,
            ),
          ] else if (isAdjust) ...[
            // Adjust balance: Only Account
            _SelectionRow(
              title: selectedAccount?.name ?? 'เลือกบัญชี',
              subtitle: selectedAccount != null
                  ? 'คงเหลือปัจจุบัน ฿ ${formatAmount(accountProvider.getBalance(selectedAccount!.id, transactions))}'
                  : 'แตะเพื่อเลือกบัญชี',
              subtitleColor: selectedAccount != null
                  ? AppColors.getAmountColor(
                      accountProvider.getBalance(
                        selectedAccount!.id,
                        transactions,
                      ),
                      isDarkMode,
                    )
                  : null,
              iconWidget: selectedAccount != null
                  ? AccountIconWidget(
                      account: selectedAccount!,
                      size: 40,
                      isDarkMode: isDarkMode,
                    )
                  : _defaultIconBox(
                      Icons.account_balance_wallet_outlined,
                      isDarkMode
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                      isDarkMode,
                    ),
              onTap: () => onPickAccount(false),
              isDarkMode: isDarkMode,
            ),
          ] else ...[
            // Default: Income & Expense
            // Row 1: Account
            _SelectionRow(
              title: selectedAccount?.name ?? 'เลือกบัญชี',
              subtitle: selectedAccount != null
                  ? 'คงเหลือ ฿ ${formatAmount(accountProvider.getBalance(selectedAccount!.id, transactions))}'
                  : 'แตะเพื่อเลือกบัญชี',
              subtitleColor: selectedAccount != null
                  ? AppColors.getAmountColor(
                      accountProvider.getBalance(
                        selectedAccount!.id,
                        transactions,
                      ),
                      isDarkMode,
                    )
                  : null,
              iconWidget: selectedAccount != null
                  ? AccountIconWidget(
                      account: selectedAccount!,
                      size: 40,
                      isDarkMode: isDarkMode,
                    )
                  : _defaultIconBox(
                      Icons.account_balance_wallet_outlined,
                      isDarkMode
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                      isDarkMode,
                    ),
              onTap: () => onPickAccount(false),
              isDarkMode: isDarkMode,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 68),
              child: Divider(height: 1, color: dividerColor),
            ),
            // Row 2: Category
            _SelectionRow(
              title: selectedCategory?.name ?? 'เลือกหมวดหมู่',
              subtitle: selectedCategory != null
                  ? 'หมวดหมู่รายการ'
                  : 'แตะเพื่อเลือกหมวดหมู่',
              iconWidget: selectedCategory != null
                  ? _categoryIconBox(selectedCategory!)
                  : _defaultIconBox(
                      Icons.category_outlined,
                      isDarkMode
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                      isDarkMode,
                    ),
              onTap: onPickCategory,
              isDarkMode: isDarkMode,
            ),
          ],
        ],
      ),
    );
  }

  static Widget _defaultIconBox(IconData icon, Color color, bool isDarkMode) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadii.large),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  static Widget _categoryIconBox(Category cat) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: cat.color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadii.large),
      ),
      child: Icon(cat.icon, color: cat.color, size: 20),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. Inset Selection Row (iOS list tile style)
// ─────────────────────────────────────────────────────────────────────────────
class _SelectionRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color? subtitleColor;
  final Widget iconWidget;
  final Widget? trailing;
  final VoidCallback onTap;
  final bool isDarkMode;

  const _SelectionRow({
    required this.title,
    required this.subtitle,
    this.subtitleColor,
    required this.iconWidget,
    this.trailing,
    required this.onTap,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final textSecondary = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            iconWidget,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: subtitleColor ?? textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: textSecondary,
                ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. Meta Information Card (Date & Time, Note)
// ─────────────────────────────────────────────────────────────────────────────
class _MetaInfoCard extends StatelessWidget {
  final DateTime selectedDateTime;
  final TextEditingController noteController;
  final bool isDarkMode;
  final VoidCallback onPickDateTime;

  const _MetaInfoCard({
    required this.selectedDateTime,
    required this.noteController,
    required this.isDarkMode,
    required this.onPickDateTime,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final surfaceVariant = isDarkMode
        ? AppColors.darkSurfaceVariant
        : AppColors.sectionHeader;
    final textPrimary = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final textSecondary = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppRadii.sheet),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Row 1: Date & Time
          InkWell(
            onTap: onPickDateTime,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: surfaceVariant,
                      borderRadius: BorderRadius.circular(AppRadii.large),
                    ),
                    child: Icon(
                      Icons.calendar_today_rounded,
                      color: textPrimary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'วันและเวลา',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatThaiDateTime(selectedDateTime),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: textSecondary,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 68),
            child: Divider(height: 1, color: dividerColor),
          ),
          // Row 2: Note
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: surfaceVariant,
                    borderRadius: BorderRadius.circular(AppRadii.large),
                  ),
                  child: Icon(
                    Icons.edit_note_rounded,
                    color: textPrimary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextField(
                    controller: noteController,
                    maxLines: 3,
                    minLines: 1,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'บันทึกโน้ตหรือรายละเอียด...',
                      hintStyle: TextStyle(fontSize: 15, color: textSecondary),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
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

  static String _formatThaiDateTime(DateTime dt) {
    const thaiDays = [
      'จันทร์',
      'อังคาร',
      'พุธ',
      'พฤหัสบดี',
      'ศุกร์',
      'เสาร์',
      'อาทิตย์',
    ];
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
    return '${dt.day} ${thaiMonths[dt.month - 1]} ${dt.year} · $day $h:$m';
  }
}
