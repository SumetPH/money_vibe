import 'package:flutter/material.dart';
import '../../widgets/calculator_keyboard_host.dart';
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
import '../../main.dart';
import '../../widgets/account_picker_bottom_sheet.dart';
import '../../widgets/category_picker_bottom_sheet.dart';
import '../../widgets/app_bar_buttons.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_date_picker_sheet.dart';
import 'transaction_type_picker.dart';
import 'transaction_amount_hero_card.dart';
import 'transaction_selection_group_card.dart';
import 'transaction_meta_info_card.dart';
import 'transaction_conversion_controller.dart';
import 'transaction_delete_button.dart';
import 'transaction_form_accounts.dart';
import 'transaction_keyboard_host.dart';
import 'transaction_foreign_currency.dart';
import '../../utils/exchange_rate_utils.dart';
import '../../utils/user_error_message.dart';

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

class _TransactionFormScreenState extends State<TransactionFormScreen>
    with TransactionKeyboardHost, TransactionForeignCurrencyHost {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _amountFocusNode = FocusNode();
  final _toAmountFocusNode = FocusNode();
  final _rateFocusNode = FocusNode();
  bool _isUpdatingController = false;
  late TextEditingValue _previousAmountValue;
  late TextEditingValue _previousToAmountValue;
  late TextEditingValue _previousRateValue;

  final _amountController = TextEditingController();
  // cross-currency: ยอดปลายทางและ rate
  late final _conversion = TransactionConversionController(
    fromController: _amountController,
  );
  TextEditingController get _toAmountController => _conversion.toController;
  TextEditingController get _rateController => _conversion.rateController;
  final _noteController = TextEditingController();

  late TransactionType _type;
  String? _selectedAccountId;
  String? _selectedCategoryId;
  String? _selectedToAccountId;
  String? _selectedDebtAccountId;
  late DateTime _selectedDateTime;

  double _accountBalance = 0.0;
  bool _isLoading = false;

  @override
  GlobalKey<ScaffoldState> get keyboardScaffoldKey => _scaffoldKey;

  @override
  Color get keyboardActionColor => _getActionButtonColor();

  @override
  late final Map<FocusNode, TextEditingController> keyboardFields = {
    _amountFocusNode: _amountController,
    _toAmountFocusNode: _toAmountController,
    _rateFocusNode: _rateController,
  };

  bool get _isEditing => widget.transaction != null;
  bool get _isAdjustment => _type.isIncreaseBalance || _type.isDecreaseBalance;

  double _balanceBeforeAdjustment() {
    if (_selectedAccountId == null) return 0;
    final transactions = context.read<TransactionProvider>().transactions;
    return context.read<AccountProvider>().getBalance(
      _selectedAccountId!,
      _isEditing
          ? transactions.where((tx) => tx.id != widget.transaction!.id).toList()
          : transactions,
    );
  }

  @override
  void initState() {
    super.initState();
    final tx = widget.transaction ?? widget.initialValues;
    _type = tx?.type ?? TransactionType.expense;
    _selectedAccountId = tx?.accountId;
    _selectedCategoryId = tx?.categoryId;
    _selectedToAccountId = _usesTargetAccount(_type) ? tx?.toAccountId : null;
    _selectedDebtAccountId = _type.requiresDebtAccount ? tx?.toAccountId : null;
    _selectedDateTime = tx?.dateTime ?? DateTime.now();
    _amountController.text = (tx != null && tx.amount > 0)
        ? formatAmount(tx.amount)
        : '';
    if (_supportsForeign(_type) && tx != null && tx.hasForeignAmount) {
      initForeignCurrency(tx.foreignCurrency);
    }
    _syncConversionCurrencies();
    final initialToAmount = foreignCurrency != null
        ? tx?.foreignAmount
        : tx?.toAmount;
    if (initialToAmount != null && initialToAmount > 0) {
      _conversion.seedFromAmounts(toAmount: initialToAmount);
    }
    _noteController.text = tx?.note ?? '';
    if (_isAdjustment && tx != null) {
      final balance = _balanceBeforeAdjustment();
      _amountController.text = formatAmount(
        balance + (tx.type.isIncreaseBalance ? tx.amount : -tx.amount),
      );
    }
    _previousAmountValue = _amountController.value;
    _previousToAmountValue = _toAmountController.value;
    _previousRateValue = _rateController.value;

    attachTransactionKeyboard();
    _amountController.addListener(_handleAmountChanged);
    _toAmountController.addListener(_handleToAmountChanged);
    _rateController.addListener(_handleRateChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateAccountBalance();
    });
  }

  @override
  void dispose() {
    detachTransactionKeyboard();
    _amountController.removeListener(_handleAmountChanged);
    _toAmountController.removeListener(_handleToAmountChanged);
    _rateController.removeListener(_handleRateChanged);
    _amountFocusNode.dispose();
    _toAmountFocusNode.dispose();
    _rateFocusNode.dispose();
    _conversion.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  static bool _usesTargetAccount(TransactionType type) =>
      type == TransactionType.transfer || type == TransactionType.exchange;

  void _syncConversionCurrencies() {
    final accountProvider = context.read<AccountProvider>();
    final from = _selectedAccountId == null
        ? null
        : accountProvider.findById(_selectedAccountId!);
    final to = _selectedToAccountId == null
        ? null
        : accountProvider.findById(_selectedToAccountId!);
    final isExchange = _type == TransactionType.exchange;
    final foreign = _supportsForeign(_type) ? foreignCurrency : null;
    _conversion.setCurrencies(
      fromCurrency: isExchange || foreign != null ? from?.currency : null,
      toCurrency: isExchange ? to?.currency : foreign,
    );
    _syncPreviousConversionValues();
  }

  static bool _supportsForeign(TransactionType type) =>
      type == TransactionType.expense || type == TransactionType.income;

  @override
  Account? get foreignSourceAccount => _selectedAccountId == null
      ? null
      : context.read<AccountProvider>().findById(_selectedAccountId!);

  @override
  TransactionConversionController get foreignConversion => _conversion;

  @override
  void onForeignCurrencyChanged() {
    _syncConversionCurrencies();
  }

  void _syncPreviousConversionValues() {
    _previousAmountValue = _amountController.value;
    _previousToAmountValue = _toAmountController.value;
    _previousRateValue = _rateController.value;
  }

  void _calculateAccountBalance() {
    if (_isAdjustment) {
      setState(() => _accountBalance = _balanceBeforeAdjustment());
    }
  }

  void _handleAmountChanged() {
    if (_isUpdatingController) return;
    _isUpdatingController = true;
    try {
      if (!_conversion.isWriting) {
        formatCalculatorAmountInput(
          _amountController,
          previousValue: _previousAmountValue,
        );
        _conversion.onUserEdited(ExchangeField.from);
      }
      _syncPreviousConversionValues();
      _calculateAccountBalance();
      if (_type.requiresDebtAccount) {
        setState(() {});
      }
    } finally {
      _isUpdatingController = false;
    }
  }

  void _handleToAmountChanged() =>
      _handleConversionFieldChanged(_toAmountController, ExchangeField.to);

  void _handleRateChanged() =>
      _handleConversionFieldChanged(_rateController, ExchangeField.rate);

  void _handleConversionFieldChanged(
    TextEditingController controller,
    ExchangeField field,
  ) {
    if (_isUpdatingController) return;
    _isUpdatingController = true;
    try {
      if (!_conversion.isWriting) {
        formatCalculatorAmountInput(
          controller,
          previousValue: field == ExchangeField.rate
              ? _previousRateValue
              : _previousToAmountValue,
        );
        _conversion.onUserEdited(field);
      }
      _syncPreviousConversionValues();
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
      case TransactionType.exchange:
        return AppColors.exchangeFor(isDarkMode);
      case TransactionType.debtRepay:
        return isDarkMode ? AppColors.darkDebtRepay : AppColors.debtRepay;
      case TransactionType.debtTransfer:
        return isDarkMode ? AppColors.darkDebtTransfer : AppColors.debtTransfer;
    }
  }

  Future<void> _save() async {
    final amountText = _amountController.text.replaceAll(',', '').trim();
    var amount = double.tryParse(amountText);
    if (amount == null || !amount.isFinite || (!_isAdjustment && amount <= 0)) {
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
    if (_isAdjustment) {
      final difference = amount - _balanceBeforeAdjustment();
      if (difference.abs() < 0.005) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ยอดที่ต้องการเท่ากับยอดบัญชีเดิม')),
        );
        return;
      }
      if ((_type.isIncreaseBalance && difference < 0) ||
          (_type.isDecreaseBalance && difference > 0)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _type.isIncreaseBalance
                  ? 'ปรับเพิ่ม: กรุณากรอกยอดที่สูงกว่ายอดก่อนปรับ'
                  : 'ปรับลด: กรุณากรอกยอดที่ต่ำกว่ายอดก่อนปรับ',
            ),
          ),
        );
        return;
      }
      amount = difference.abs();
    }

    String? toAccountId;
    if (_usesTargetAccount(_type)) {
      toAccountId = _selectedToAccountId;
    } else if (_type.requiresDebtAccount) {
      toAccountId = _selectedDebtAccountId;
    }

    // แลกเงินเก็บยอดปลายทางใน toAmount, รายรับ/รายจ่ายสกุลต่างประเทศเก็บใน foreignAmount
    final activeForeign = _supportsForeign(_type) ? foreignCurrency : null;
    final conversionError = validateTransactionConversion(
      type: _type,
      source: accountProvider.findById(_selectedAccountId!),
      target: toAccountId == null
          ? null
          : accountProvider.findById(toAccountId),
      foreignCurrency: activeForeign,
      convertedAmount: _conversion.toAmount,
    );
    if (conversionError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(conversionError)));
      return;
    }
    final isExchange = _type == TransactionType.exchange;
    final toAmount = isExchange ? _conversion.toAmount : null;
    final foreignAmount = activeForeign != null ? _conversion.toAmount : null;

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
      foreignAmount: foreignAmount,
      foreignCurrency: activeForeign,
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
        closeTransactionKeyboard();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userErrorMessage(e, action: 'บันทึก')),
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

    closeTransactionKeyboard();
    Navigator.pop(context); // Close form
  }

  void _selectType(TransactionType t) {
    closeTransactionKeyboard();
    final wasAdjustment = _isAdjustment;
    setState(() {
      _type = t;
      if (wasAdjustment != _isAdjustment) _amountController.clear();
      _selectedCategoryId = null;
      if (!_usesTargetAccount(t)) {
        _selectedToAccountId = null;
      }
      _dropInvalidAccountSelections();
      if (!t.requiresDebtAccount) {
        _selectedDebtAccountId = null;
      }
      _calculateAccountBalance();
    });
    if (!_supportsForeign(t) && foreignCurrency != null) {
      setForeignCurrency(null);
    }
    _syncConversionCurrencies();
  }

  /// ล้างบัญชีที่เลือกไว้ถ้าไม่อยู่ในรายการที่เลือกได้ของประเภทปัจจุบัน
  void _dropInvalidAccountSelections() {
    final accountProvider = context.read<AccountProvider>();
    final sources = transactionSourceAccounts(
      _type,
      accountProvider.visibleAccounts,
    );
    if (_selectedAccountId != null &&
        !sources.any((a) => a.id == _selectedAccountId)) {
      _selectedAccountId = null;
    }
    final source = _selectedAccountId == null
        ? null
        : accountProvider.findById(_selectedAccountId!);
    final targets = transactionTargetAccounts(_type, sources, source);
    if (_selectedToAccountId != null &&
        !targets.any((a) => a.id == _selectedToAccountId)) {
      _selectedToAccountId = null;
    }
    final debtTargets = _debtTargetAccounts(accountProvider, source);
    if (_selectedDebtAccountId != null &&
        !debtTargets.any((a) => a.id == _selectedDebtAccountId)) {
      _selectedDebtAccountId = null;
    }
  }

  List<Account> _debtTargetAccounts(
    AccountProvider accountProvider,
    Account? source,
  ) => transactionTargetAccounts(_type, accountProvider.debtAccounts, source);

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

        final accounts = transactionSourceAccounts(_type, allVisibleAccounts);

        final selectedAccount = _selectedAccountId != null
            ? accountProvider.findById(_selectedAccountId!)
            : null;
        final selectedToAccount = _selectedToAccountId != null
            ? accountProvider.findById(_selectedToAccountId!)
            : null;
        final targetAccounts = transactionTargetAccounts(
          _type,
          accounts,
          selectedAccount,
        );
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
                      closeTransactionKeyboard();
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
              closeTransactionKeyboard();
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
                      closeTransactionKeyboard();
                      showTransactionTypePicker(
                        context,
                        currentType: _type,
                        onSelected: _selectType,
                      );
                    },
                  ),
                  const SizedBox(height: 14),

                  // 2. Amount Hero Card
                  if (!_isAdjustment)
                    TransactionAmountHeroCard(
                      type: _type,
                      amountController: _amountController,
                      amountFocusNode: _amountFocusNode,
                      toAmountController: _toAmountController,
                      toAmountFocusNode: _toAmountFocusNode,
                      rateController: _rateController,
                      rateFocusNode: _rateFocusNode,
                      selectedAccount: selectedAccount,
                      selectedToAccount: selectedToAccount,
                      accountBalance: _isAdjustment
                          ? _balanceBeforeAdjustment()
                          : _accountBalance,
                      isDarkMode: isDarkMode,
                      foreignCurrency: foreignCurrency,
                      onToggleForeign: toggleForeignCurrency,
                      onPickForeignCurrency: pickForeignCurrency,
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
                    onPickAccount: (isTarget) => _pickAccount(
                      context,
                      isTarget ? targetAccounts : accounts,
                      isTarget,
                    ),
                    onPickDebtAccount: () =>
                        _pickDebtAccount(context, accountProvider),
                    onClearAccount: () =>
                        setState(() => _selectedAccountId = null),
                    onPickCategory: () => _pickCategory(context, categories),
                  ),
                  const SizedBox(height: 18),
                  if (_isAdjustment) ...[
                    TransactionAmountHeroCard(
                      type: _type,
                      amountController: _amountController,
                      amountFocusNode: _amountFocusNode,
                      toAmountController: _toAmountController,
                      toAmountFocusNode: _toAmountFocusNode,
                      rateController: _rateController,
                      rateFocusNode: _rateFocusNode,
                      selectedAccount: selectedAccount,
                      selectedToAccount: selectedToAccount,
                      accountBalance: _balanceBeforeAdjustment(),
                      isDarkMode: isDarkMode,
                    ),
                    const SizedBox(height: 18),
                  ],

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
                    TransactionDeleteButton(
                      isDarkMode: isDarkMode,
                      onPressed: _isLoading ? null : _delete,
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
    closeTransactionKeyboard();
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
          _dropInvalidAccountSelections();
        }
      });
      if (!isTarget && foreignSourceAccount?.currency == foreignCurrency) {
        setForeignCurrency(null);
      }
      _syncConversionCurrencies();
      _calculateAccountBalance();
    }
  }

  Future<void> _pickDebtAccount(
    BuildContext context,
    AccountProvider accountProvider,
  ) async {
    closeTransactionKeyboard();
    final selectedId = await AccountPickerBottomSheet.show(
      context,
      title: 'เลือกบัญชีหนี้สิน',
      selectedAccountId: _selectedDebtAccountId,
      isDebtOnly: true,
      accountsOverride: _debtTargetAccounts(
        accountProvider,
        _selectedAccountId == null
            ? null
            : accountProvider.findById(_selectedAccountId!),
      ),
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
    closeTransactionKeyboard();
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
    closeTransactionKeyboard();
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
