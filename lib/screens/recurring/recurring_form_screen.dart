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
import '../../widgets/account_picker_bottom_sheet.dart';
import '../../main.dart';
import '../../widgets/calculator_keyboard.dart';
import 'recurring_section.dart';
import '../../widgets/app_bar_buttons.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/icon_color_picker_sheet.dart';
import 'recurring_form_widgets.dart';
import 'recurring_form_pickers.dart';

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

  Future<void> _delete() async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'ลบรายการประจำ',
      message: 'คุณต้องการลบรายการประจำนี้ใช่หรือไม่?',
      confirmLabel: 'ลบ',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    final provider = context.read<RecurringTransactionProvider>();
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    setState(() => _isLoading = true);
    try {
      await provider.deleteRecurring(widget.recurring!.id);
      if (mounted) {
        _closeKeyboard();
        navigator.pop(); // Close form
      }
    } catch (e) {
      if (mounted) {
        _closeKeyboard();
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
        final dividerColor = AppColors.borderFor(isDark);

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
            leading: AppCloseButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      _closeKeyboard();
                      Navigator.pop(context);
                    },
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
                  RecurringTypeSegmentedControl(
                    selectedType: _type,
                    onChanged: (type) => setState(() {
                      _type = type;
                      _categoryId = null;
                      if (!type.requiresDebtAccount) _debtAccountId = null;
                      if (type != TransactionType.transfer) _toAccountId = null;
                    }),
                    onShowMore: () => _pickType(isDark),
                  ),
                  const SizedBox(height: 14),
                  RecurringAmountHeroCard(
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
                        RecurringRowTile(
                          label: 'บัญชี',
                          value: selectedAccount?.name ?? 'เลือกบัญชี',
                          onTap: () =>
                              _pickAccount(accounts, isDestination: false),
                        ),
                        Divider(height: 1, color: dividerColor),

                        // ── To Account (transfer only) ────────────────────────────────
                        if (_type.isTransferLike) ...[
                          RecurringRowTile(
                            label: 'บัญชีปลายทาง',
                            value:
                                (_type == TransactionType.debtTransfer
                                        ? selectedDebtAccount
                                        : selectedToAccount)
                                    ?.name ??
                                'เลือกบัญชี',
                            onTap: () => _type == TransactionType.debtTransfer
                                ? _pickDebtAccount()
                                : _pickAccount(accounts, isDestination: true),
                          ),
                          Divider(height: 1, color: dividerColor),
                        ],

                        // ── Debt Account (debtRepay only) ─────────────────────────────
                        if (_type == TransactionType.debtRepay) ...[
                          RecurringRowTile(
                            label: 'บัญชีหนี้สิน',
                            value:
                                selectedDebtAccount?.name ??
                                'เลือกบัญชีหนี้สิน',
                            onTap: _pickDebtAccount,
                          ),
                          Divider(height: 1, color: dividerColor),
                        ],

                        // ── Category (non-transfer) ────────────────────────────────────
                        if (_type.supportsCategory) ...[
                          RecurringRowTile(
                            label: 'หมวดหมู่',
                            value: selectedCategory?.name ?? 'ไม่ได้เลือก',
                            onTap: () => _pickCategory(categories, isDark),
                          ),
                          Divider(height: 1, color: dividerColor),
                        ],

                        // ── Day of month ──────────────────────────────────────────────
                        RecurringRowTile(
                          label: 'วันที่ในเดือน',
                          value: _dayOfMonth == 0
                              ? 'สิ้นเดือน'
                              : 'วันที่ $_dayOfMonth',
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
                        RecurringMonthRangeRows(
                          startLabel: _formatMonthYear(_startDate),
                          endLabel: _endDate != null
                              ? _formatMonthYear(_endDate!)
                              : null,
                          surfaceColor: surfaceColor,
                          dividerColor: dividerColor,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          onPickStart: () => _pickDate(isStart: true),
                          onPickEnd: () => _pickDate(isStart: false),
                          onClearEnd: () => setState(() => _endDate = null),
                        ),
                        Divider(height: 1, color: dividerColor),
                        IconPickerFormRow(
                          icon: _icon,
                          color: _color,
                          onTap: _pickIcon,
                        ),
                        Divider(height: 1, color: dividerColor),
                        ColorPickerFormRow(color: _color, onTap: _pickColor),
                      ],
                    ),
                  ),

                  RecurringSection(
                    title: 'การแจ้งเตือน',
                    inset: false,
                    child: Column(
                      children: [
                        RecurringToggleRow(
                          color: surfaceColor,
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
                          RecurringRowTile(
                            label: 'เวลาแจ้งเตือน',
                            value: _formatTime(_notificationTime),
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
                        RecurringToggleRow(
                          color: surfaceColor,
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

                  const SizedBox(height: 16),

                  if (_isEditing)
                    RecurringDeleteButton(
                      isDark: isDark,
                      surfaceColor: surfaceColor,
                      onDelete: _delete,
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

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : (_endDate ?? _startDate);
    final picked = await showRecurringMonthYearPicker(
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

  void _pickType(bool isDark) {
    showRecurringTypePicker(
      context,
      isDark,
      selected: _type,
      onSelected: (t) {
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
      },
    );
  }

  void _pickCategory(List<Category> categories, bool isDark) {
    showRecurringCategoryPicker(
      context,
      categories,
      isDark,
      selectedCategoryId: _categoryId,
      onSelected: (id) => setState(() => _categoryId = id),
    );
  }

  void _pickDayOfMonth(bool isDark) {
    showRecurringDayOfMonthPicker(
      context,
      isDark,
      selectedDay: _dayOfMonth,
      onSelected: (day) => setState(() => _dayOfMonth = day),
    );
  }

  Future<void> _pickNotificationTime(bool isDark) async {
    final picked = await showRecurringNotificationTimePicker(
      context,
      isDark,
      initialTime: _notificationTime,
    );

    if (picked == null) return;
    setState(() => _notificationTime = picked);
  }

  Future<void> _pickIcon() async {
    final icon = await showIconPickerSheet(
      context: context,
      title: 'เลือกไอคอน',
      selectedIcon: _icon,
      accentColor: _color,
    );
    if (icon == null || !mounted) return;
    setState(() => _icon = icon);
  }

  Future<void> _pickColor() async {
    final color = await showColorPickerSheet(
      context: context,
      title: 'เลือกสี',
      selectedColor: _color,
    );
    if (color == null || !mounted) return;
    setState(() => _color = color);
  }
}
