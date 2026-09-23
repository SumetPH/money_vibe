import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/recurring_transaction.dart';
import '../../models/transaction.dart';
import '../../models/account.dart';
import '../../models/category.dart';
import '../../providers/recurring_transaction_provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/recurring_notification_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../widgets/account_picker_bottom_sheet.dart';
import '../../widgets/app_modal_bottom_sheet.dart';
import '../../main.dart';
import '../../widgets/calculator_keyboard.dart';
import '../../widgets/calculator_text_field_config.dart';
import 'recurring_section.dart';

class RecurringFormScreen extends StatefulWidget {
  final RecurringTransaction? recurring;

  const RecurringFormScreen({super.key, this.recurring});

  @override
  State<RecurringFormScreen> createState() => _RecurringFormScreenState();
}

class _RecurringFormScreenState extends State<RecurringFormScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _amountFocusNode = FocusNode();
  PersistentBottomSheetController? _keyboardController;
  TextEditingController? _activeKeyboardController;
  bool _isUpdatingController = false;

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
  bool _notificationEnabled = false;
  TimeOfDay _notificationTime = const TimeOfDay(hour: 9, minute: 0);
  bool _isLoading = false;

  bool get _isEditing => widget.recurring != null;

  @override
  void initState() {
    super.initState();
    final r = widget.recurring;
    _nameController.text = r?.name ?? '';
    _amountController.text = r != null ? formatAmount(r.amount) : '';
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
    _notificationEnabled = r?.notificationEnabled ?? false;
    _notificationTime = TimeOfDay(
      hour: r?.notificationHour ?? 9,
      minute: r?.notificationMinute ?? 0,
    );

    _amountFocusNode.addListener(_onFocusChange);
    _amountController.addListener(_handleAmountChanged);
  }

  @override
  void dispose() {
    _amountFocusNode.removeListener(_onFocusChange);
    _amountController.removeListener(_handleAmountChanged);
    _amountFocusNode.dispose();
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!mounted) return;
    if (_amountFocusNode.hasFocus) {
      _showKeyboard(_amountController);
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
    } finally {
      _isUpdatingController = false;
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
    final actionColor = _color;

    _keyboardController = _scaffoldKey.currentState?.showBottomSheet(
      (context) {
        return CalculatorKeyboard(
          controller: controller,
          actionButtonColor: actionColor,
          onDone: () {
            _amountFocusNode.unfocus();
          },
        );
      },
      backgroundColor: Colors.transparent,
      elevation: 0,
    );

    _keyboardController?.closed.then((_) {
      if (_activeKeyboardController == controller) {
        _keyboardController = null;
        _activeKeyboardController = null;
        if (_amountFocusNode.hasFocus) {
          _amountFocusNode.unfocus();
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
  }

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

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณากรอกชื่อรายการ')));
      return;
    }
    final rawAmount = _amountController.text.replaceAll(',', '').trim();
    final amount = double.tryParse(rawAmount);
    if (rawAmount.isEmpty || amount == null || amount < 0) {
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
    final notificationService = RecurringNotificationService.instance;
    final note = _noteController.text.trim().isEmpty
        ? null
        : _noteController.text.trim();

    final toAccountId = _type.requiresDebtAccount
        ? _debtAccountId
        : _toAccountId;

    final recurring = _isEditing
        ? widget.recurring!.copyWith(
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
            notificationEnabled: _notificationEnabled,
            notificationHour: _notificationTime.hour,
            notificationMinute: _notificationTime.minute,
          )
        : RecurringTransaction(
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
            notificationEnabled: _notificationEnabled,
            notificationHour: _notificationTime.hour,
            notificationMinute: _notificationTime.minute,
          );

    setState(() => _isLoading = true);

    try {
      if (_isEditing) {
        await provider.updateRecurring(recurring);
      } else {
        await provider.addRecurring(recurring);
      }

      final notificationGranted = await notificationService
          .syncRecurringNotification(
            recurring: recurring,
            occurrences: provider.occurrencesFor(recurring.id),
          );

      if (!mounted) return;

      if (_notificationEnabled && !notificationGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('บันทึกรายการแล้ว แต่ยังไม่ได้รับสิทธิ์แจ้งเตือน'),
          ),
        );
      }

      _closeKeyboard();
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'บันทึกรายการไม่สำเร็จ: $e',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: AppColors.expense,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _delete() {
    showDialog(
      context: context,
      builder: (_) => Consumer<SettingsProvider>(
        builder: (context, sp, _) {
          final isDark = sp.isDarkMode;
          return AlertDialog(
            backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
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
                onPressed: () async {
                  final provider = context.read<RecurringTransactionProvider>();
                  final navigator = Navigator.of(context);
                  final scaffoldMessenger = ScaffoldMessenger.of(context);

                  setState(() => _isLoading = true);
                  try {
                    await provider.deleteRecurring(widget.recurring!.id);
                    if (mounted) {
                      _closeKeyboard();
                      navigator.pop(); // Close dialog
                      navigator.pop(); // Close form
                    }
                  } catch (e) {
                    if (mounted) {
                      _closeKeyboard();
                      navigator.pop(); // Close dialog
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text('ลบรายการไม่สำเร็จ: $e'),
                          backgroundColor: AppColors.expense,
                        ),
                      );
                    }
                  } finally {
                    if (mounted) {
                      setState(() => _isLoading = false);
                    }
                  }
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
        final dividerColor = isDark
            ? AppColors.darkDivider.withValues(alpha: 0.4)
            : AppColors.divider.withValues(alpha: 0.4);

        final accounts = switch (_type) {
          TransactionType.debtTransfer =>
            accountProvider.visibleAccounts
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
            accountProvider.visibleAccounts
                .where((a) => a.type != AccountType.debt && !a.isPortfolio)
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
          key: _scaffoldKey,
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: bgColor,
            foregroundColor: textPrimary,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: true,
            leadingWidth: 64,
            leading: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Material(
                color: surfaceColor,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
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
              _isEditing ? 'แก้ไขรายการประจำ' : 'เพิ่มรายการประจำ',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
            ),
            actions: [
              if (_isEditing)
                Material(
                  color: surfaceColor,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: isDark ? AppColors.darkExpense : AppColors.expense,
                    ),
                    onPressed: _isLoading ? null : _delete,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Material(
                    color: isDark
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
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
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
                  _RecurringTypeSegmentedControl(
                    selectedType: _type,
                    isDarkMode: isDark,
                    onChanged: (type) => setState(() {
                      _type = type;
                      _categoryId = null;
                      if (!type.requiresDebtAccount) _debtAccountId = null;
                      if (type != TransactionType.transfer) _toAccountId = null;
                    }),
                    onShowMore: () => _pickType(isDark),
                  ),
                  const SizedBox(height: 14),
                  _RecurringAmountHeroCard(
                    type: _type,
                    amountController: _amountController,
                    amountFocusNode: _amountFocusNode,
                    selectedAccount: selectedAccount,
                    isDarkMode: isDark,
                  ),
                  const SizedBox(height: 10),
                  RecurringSection(
                    title: 'ชื่อรายการ',
                    inset: false,
                    child: Column(
                      children: [
                        Container(
                          color: surfaceColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: TextField(
                            controller: _nameController,
                            onTapOutside: (_) =>
                                FocusScope.of(context).unfocus(),
                            decoration: InputDecoration(
                              hintText: 'ชื่อรายการ',
                              hintStyle: TextStyle(color: textSecondary),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                            ),
                            style: TextStyle(fontSize: 16, color: textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),

                  RecurringSection(
                    title: 'การตัดรายการ',
                    inset: false,
                    child: Column(
                      children: [
                        // ── Account ───────────────────────────────────────────────────
                        _RowTile(
                          label: 'บัญชี',
                          value: selectedAccount?.name ?? 'เลือกบัญชี',
                          surfaceColor: surfaceColor,
                          textSecondary: textSecondary,
                          onTap: () =>
                              _pickAccount(accounts, isDestination: false),
                        ),
                        Divider(height: 1, color: dividerColor),

                        // ── To Account (transfer only) ────────────────────────────────
                        if (_type.isTransferLike) ...[
                          _RowTile(
                            label: 'บัญชีปลายทาง',
                            value:
                                (_type == TransactionType.debtTransfer
                                        ? selectedDebtAccount
                                        : selectedToAccount)
                                    ?.name ??
                                'เลือกบัญชี',
                            surfaceColor: surfaceColor,
                            textSecondary: textSecondary,
                            onTap: () => _type == TransactionType.debtTransfer
                                ? _pickDebtAccount()
                                : _pickAccount(accounts, isDestination: true),
                          ),
                          Divider(height: 1, color: dividerColor),
                        ],

                        // ── Debt Account (debtRepay only) ─────────────────────────────
                        if (_type == TransactionType.debtRepay) ...[
                          _RowTile(
                            label: 'บัญชีหนี้สิน',
                            value:
                                selectedDebtAccount?.name ??
                                'เลือกบัญชีหนี้สิน',
                            surfaceColor: surfaceColor,
                            textSecondary: textSecondary,
                            onTap: _pickDebtAccount,
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
                          value: _dayOfMonth == 0
                              ? 'สิ้นเดือน'
                              : 'วันที่ $_dayOfMonth',
                          surfaceColor: surfaceColor,
                          textSecondary: textSecondary,
                          onTap: () => _pickDayOfMonth(isDark),
                        ),
                      ],
                    ),
                  ),

                  RecurringSection(
                    title: 'กำหนดการและหน้าตา',
                    inset: false,
                    child: Column(
                      children: [
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
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: textSecondary,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _formatMonthYear(_startDate),
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.chevron_right,
                                  color: textSecondary,
                                  size: 18,
                                ),
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
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: textSecondary,
                                  ),
                                ),
                                const Spacer(),
                                if (_endDate != null) ...[
                                  Text(
                                    _formatMonthYear(_endDate!),
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Material(
                                    color: Colors.transparent,
                                    child: InkResponse(
                                      onTap: () =>
                                          setState(() => _endDate = null),
                                      radius: 16,
                                      child: Icon(
                                        Icons.close,
                                        size: 16,
                                        color: textSecondary,
                                      ),
                                    ),
                                  ),
                                ] else
                                  Text(
                                    'ไม่ได้เลือก',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: textSecondary.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.chevron_right,
                                  color: textSecondary,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Divider(height: 1, color: dividerColor),
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
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: textSecondary,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: _color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.large,
                                    ),
                                  ),
                                  child: Icon(_icon, color: _color, size: 26),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.chevron_right,
                                  color: textSecondary,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Divider(height: 1, color: dividerColor),
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
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: textSecondary,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: _color,
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.large,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.chevron_right,
                                  color: textSecondary,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  RecurringSection(
                    title: 'การแจ้งเตือน',
                    inset: false,
                    child: Column(
                      children: [
                        _ToggleRow(
                          color: surfaceColor,
                          activeTrackColor: isDark
                              ? AppColors.darkIncome
                              : AppColors.income,
                          value: _notificationEnabled,
                          onChanged: (v) =>
                              setState(() => _notificationEnabled = v),
                          title: Text(
                            'แจ้งเตือนเมื่อถึงกำหนด',
                            style: TextStyle(fontSize: 16, color: textPrimary),
                          ),
                          subtitle: Text(
                            _notificationEnabled
                                ? 'เตือนบนเครื่องนี้เวลา ${_formatTime(_notificationTime)}'
                                : 'ปิดการแจ้งเตือนอยู่',
                            style: TextStyle(
                              fontSize: 13,
                              color: textSecondary,
                            ),
                          ),
                        ),
                        if (_notificationEnabled) ...[
                          Divider(height: 1, color: dividerColor),
                          _RowTile(
                            label: 'เวลาแจ้งเตือน',
                            value: _formatTime(_notificationTime),
                            surfaceColor: surfaceColor,
                            textSecondary: textSecondary,
                            onTap: () => _pickNotificationTime(isDark),
                          ),
                          Divider(height: 1, color: dividerColor),
                        ],
                      ],
                    ),
                  ),

                  RecurringSection(
                    title: 'เพิ่มเติม',
                    inset: false,
                    child: Column(
                      children: [
                        Container(
                          color: surfaceColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: TextField(
                            controller: _noteController,
                            onTapOutside: (_) =>
                                FocusScope.of(context).unfocus(),
                            maxLines: 2,
                            decoration: InputDecoration(
                              hintText: 'โน้ต (ไม่บังคับ)',
                              hintStyle: TextStyle(color: textSecondary),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                            ),
                            style: TextStyle(fontSize: 16, color: textPrimary),
                          ),
                        ),

                        Divider(height: 1, color: dividerColor),
                        _ToggleRow(
                          color: surfaceColor,
                          activeTrackColor: isDark
                              ? AppColors.darkIncome
                              : AppColors.income,
                          value: _isHidden,
                          onChanged: (v) => setState(() => _isHidden = v),
                          title: Text(
                            'ซ่อนรายการนี้',
                            style: TextStyle(fontSize: 16, color: textPrimary),
                          ),
                          subtitle: Text(
                            'ซ่อนจากรายการประจำ (แต่ยังทำงานอยู่)',
                            style: TextStyle(
                              fontSize: 13,
                              color: textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Pickers ────────────────────────────────────────────────────────────────

  void _pickType(bool isDark) {
    final bgColor = isDark ? AppColors.darkSurface : AppColors.surface;
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final dividerColor = isDark
        ? AppColors.darkDivider.withValues(alpha: 0.4)
        : AppColors.divider.withValues(alpha: 0.4);
    final selectedColor = isDark ? AppColors.darkIncome : AppColors.header;

    showAppModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, sc) => Column(
          children: [
            const AppModalBottomSheetHeader(title: 'เลือกประเภทรายการ'),
            Expanded(
              child: ListView(
                controller: sc,
                children: TransactionType.values
                    .map(
                      (t) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            tileColor: bgColor,
                            title: Text(
                              t.label,
                              style: TextStyle(color: textColor),
                            ),
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
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAccount(
    List<Account> accounts, {
    required bool isDestination,
  }) async {
    final selectedId = await AccountPickerBottomSheet.show(
      context,
      title: isDestination ? 'บัญชีปลายทาง' : 'เลือกบัญชี',
      selectedAccountId: isDestination ? _toAccountId : _accountId,
      accountsOverride: accounts,
    );

    if (selectedId == null || !mounted) return;

    setState(() {
      if (isDestination) {
        _toAccountId = selectedId;
      } else {
        _accountId = selectedId;
      }
    });
  }

  Future<void> _pickDebtAccount() async {
    final selectedId = await AccountPickerBottomSheet.show(
      context,
      title: 'เลือกบัญชีหนี้สิน',
      selectedAccountId: _debtAccountId,
      isDebtOnly: true,
    );

    if (selectedId == null || !mounted) return;

    setState(() {
      _debtAccountId = selectedId;
    });
  }

  void _pickCategory(List<Category> categories, bool isDark) {
    final bgColor = isDark ? AppColors.darkSurface : AppColors.surface;
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final dividerColor = isDark ? AppColors.darkDivider : AppColors.divider;
    final selectedColor = isDark ? AppColors.darkIncome : AppColors.header;

    showAppModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, sc) => Column(
          children: [
            const AppModalBottomSheetHeader(title: 'เลือกหมวดหมู่'),
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
                    Divider(height: 1, color: AppColors.listDividerFor(isDark)),
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
    final bgColor = isDark ? AppColors.darkSurface : AppColors.surface;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final selectedColor = isDark ? AppColors.darkIncome : AppColors.header;

    showAppModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, sc) => Column(
          children: [
            const AppModalBottomSheetHeader(title: 'วันที่ในเดือน'),
            Expanded(
              child: GridView.builder(
                controller: sc,
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
                  return Material(
                    color: isSelected ? selectedColor : bgColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: isSelected
                          ? BorderSide.none
                          : BorderSide(
                              color: isDark
                                  ? AppColors.darkDivider
                                  : AppColors.divider,
                            ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        setState(() => _dayOfMonth = day);
                        Navigator.pop(context);
                      },
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
    final bgColor = isDark ? AppColors.darkSurface : AppColors.surface;
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final selectedColor = isDark ? AppColors.darkIncome : AppColors.header;

    int selectedYear = initialDate.year;

    return showAppModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                    return Material(
                      color: isSelected ? selectedColor : bgColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: isSelected
                            ? BorderSide.none
                            : BorderSide(
                                color: isDark
                                    ? AppColors.darkDivider
                                    : AppColors.divider,
                              ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
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

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _pickNotificationTime(bool isDark) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _notificationTime,
      builder: (context, child) {
        final actionColor = isDark ? AppColors.darkIncome : AppColors.header;
        final pickerBg = isDark ? AppColors.darkSurface : AppColors.surface;
        final textColor = isDark
            ? AppColors.darkTextPrimary
            : AppColors.textPrimary;
        final secondaryTextColor = isDark
            ? AppColors.darkTextSecondary
            : AppColors.textSecondary;
        final selectedBg = isDark
            ? AppColors.darkSurfaceVariant
            : AppColors.background;
        final dialTextColor = WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return textColor;
        });
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: isDark ? AppColors.darkHeader : AppColors.header,
              surface: pickerBg,
              onSurface: textColor,
              onPrimary: Colors.white,
            ),
            dialogTheme: DialogThemeData(backgroundColor: pickerBg),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: actionColor),
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: pickerBg,
              hourMinuteColor: selectedBg,
              hourMinuteTextColor: textColor,
              dayPeriodColor: selectedBg,
              dayPeriodTextColor: textColor,
              dayPeriodBorderSide: BorderSide(
                color: isDark ? AppColors.darkDivider : AppColors.divider,
              ),
              dialHandColor: actionColor,
              dialBackgroundColor: selectedBg,
              dialTextColor: dialTextColor,
              entryModeIconColor: actionColor,
              helpTextStyle: TextStyle(color: secondaryTextColor),
              hourMinuteShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDark ? AppColors.darkDivider : AppColors.divider,
                ),
              ),
              dayPeriodShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isDark ? AppColors.darkDivider : AppColors.divider,
                ),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;
    setState(() => _notificationTime = picked);
  }

  void _pickIcon(bool isDark) {
    final bgColor = isDark ? AppColors.darkBackground : AppColors.background;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;

    showAppModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, sc) => Column(
          children: [
            const AppModalBottomSheetHeader(title: 'เลือกไอคอน'),
            Expanded(
              child: GridView.builder(
                controller: sc,
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
                  return Material(
                    color: selected ? _color.withValues(alpha: 0.15) : bgColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: selected
                          ? BorderSide(color: _color, width: 2)
                          : BorderSide.none,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        setState(() => _icon = icon);
                        Navigator.pop(context);
                      },
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
    showAppModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, sc) => Column(
          children: [
            const AppModalBottomSheetHeader(title: 'เลือกสี'),
            Expanded(
              child: GridView.builder(
                controller: sc,
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
                  return Material(
                    color: color,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: selected
                          ? const BorderSide(color: Colors.black45, width: 2)
                          : BorderSide.none,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        setState(() => _color = color);
                        Navigator.pop(context);
                      },
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
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _RecurringTypeSegmentedControl extends StatelessWidget {
  final TransactionType selectedType;
  final bool isDarkMode;
  final ValueChanged<TransactionType> onChanged;
  final VoidCallback onShowMore;

  const _RecurringTypeSegmentedControl({
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.xLarge),
        side: BorderSide(
          color: isDarkMode
              ? AppColors.darkDivider.withValues(alpha: 0.4)
              : AppColors.divider.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            _tab(
              'รายจ่าย',
              selectedType == TransactionType.expense,
              TransactionType.expense,
              selectedSurface,
              primary,
              secondary,
            ),
            _tab(
              'รายรับ',
              selectedType == TransactionType.income,
              TransactionType.income,
              selectedSurface,
              primary,
              secondary,
            ),
            _tab(
              'โอน',
              selectedType == TransactionType.transfer,
              TransactionType.transfer,
              selectedSurface,
              primary,
              secondary,
            ),
            Expanded(
              child: _segment(
                otherLabel,
                !isPrimary,
                selectedSurface,
                primary,
                secondary,
                onShowMore,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tab(
    String label,
    bool isSelected,
    TransactionType type,
    Color selectedSurface,
    Color primary,
    Color secondary,
  ) => Expanded(
    child: _segment(
      label,
      isSelected,
      selectedSurface,
      primary,
      secondary,
      () => onChanged(type),
    ),
  );

  Widget _segment(
    String label,
    bool isSelected,
    Color selectedSurface,
    Color primary,
    Color secondary,
    VoidCallback onTap,
  ) => Material(
    color: isSelected ? selectedSurface : Colors.transparent,
    borderRadius: BorderRadius.circular(AppRadii.large),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? primary : secondary,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    ),
  );
}

class _RecurringAmountHeroCard extends StatelessWidget {
  final TransactionType type;
  final TextEditingController amountController;
  final FocusNode amountFocusNode;
  final Account? selectedAccount;
  final bool isDarkMode;

  const _RecurringAmountHeroCard({
    required this.type,
    required this.amountController,
    required this.amountFocusNode,
    required this.selectedAccount,
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
    final typeColor = switch (type) {
      TransactionType.income || TransactionType.increaseBalance =>
        isDarkMode ? AppColors.darkIncome : AppColors.income,
      TransactionType.expense || TransactionType.decreaseBalance =>
        isDarkMode ? AppColors.darkExpense : AppColors.expense,
      TransactionType.transfer || TransactionType.debtRepay =>
        isDarkMode ? AppColors.darkTransfer : AppColors.transfer,
      TransactionType.debtTransfer =>
        isDarkMode ? AppColors.darkDebtTransfer : AppColors.debtTransfer,
    };
    final currency = selectedAccount?.currency == 'USD' ? 'USD' : 'THB';

    return Material(
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.xLarge),
        side: BorderSide(
          color: isDarkMode
              ? AppColors.darkDivider.withValues(alpha: 0.4)
              : AppColors.divider.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => amountFocusNode.requestFocus(),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'จำนวนเงิน',
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
                      currency,
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
              Row(
                children: [
                  Text(
                    currency == 'USD' ? '\$ ' : '฿ ',
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
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
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
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        filled: false,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 6,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget title;
  final Widget subtitle;
  final Color color;
  final Color activeTrackColor;

  const _ToggleRow({
    required this.value,
    required this.onChanged,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.activeTrackColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<SettingsProvider>().isDarkMode;
    return Container(
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title, const SizedBox(height: 2), subtitle],
            ),
          ),
          const SizedBox(width: 12),
          CupertinoSwitch(
            value: value,
            activeTrackColor: activeTrackColor,
            inactiveTrackColor: isDark
                ? const Color(0xFF39393D)
                : const Color(0xFFE9E9EA),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _RowTile extends StatelessWidget {
  final String label;
  final String value;
  final Color surfaceColor;
  final Color textSecondary;
  final VoidCallback onTap;

  const _RowTile({
    required this.label,
    required this.value,
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
    final icon = switch (label) {
      'บัญชี' => Icons.account_balance_wallet_outlined,
      'บัญชีปลายทาง' => Icons.input_rounded,
      'บัญชีหนี้สิน' => Icons.credit_card_rounded,
      'หมวดหมู่' => Icons.category_outlined,
      'วันที่ในเดือน' => Icons.calendar_today_rounded,
      'เวลาแจ้งเตือน' => Icons.notifications_outlined,
      _ => Icons.tune_rounded,
    };

    return InkWell(
      onTap: onTap,
      child: Container(
        color: surfaceColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: textSecondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadii.large),
              ),
              child: Icon(icon, color: textSecondary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      color: textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}
