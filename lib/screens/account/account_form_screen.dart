import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/account.dart';
import '../../providers/account_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/account_icon_storage_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../main.dart';
import '../../widgets/app_modal_bottom_sheet.dart';
import '../../utils/currency_utils.dart';
import '../../widgets/calculator_keyboard.dart';
import '../../widgets/calculator_text_field_config.dart';
import '../../widgets/app_switch.dart';
import '../../widgets/app_bar_buttons.dart';
import '../../widgets/app_inset_card.dart';
import '../../widgets/app_confirm_dialog.dart';

class AccountFormScreen extends StatefulWidget {
  final Account? account;

  const AccountFormScreen({super.key, this.account});

  @override
  State<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends State<AccountFormScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _amountFocusNode = FocusNode();
  PersistentBottomSheetController? _keyboardController;
  TextEditingController? _activeKeyboardController;
  bool _isUpdatingController = false;

  final _nameController = TextEditingController();
  final _initialBalanceController = TextEditingController();
  final _exchangeRateController = TextEditingController();
  final _noteController = TextEditingController();

  late AccountType _selectedType;
  late String _selectedCurrency;
  late DateTime _startDate;
  late IconData _selectedIcon;
  String _selectedIconUrl = '';
  late Color _selectedColor;
  late bool _excludeFromNetWorth;
  late bool _isHidden;
  late bool _autoUpdateRate;
  int? _statementDay;

  bool get _isEditing => widget.account != null;
  String get _effectiveSelectedCurrency => _selectedType.isPortfolio
      ? _selectedType.defaultCurrency
      : _selectedCurrency;
  bool _isDarkMode = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final acc = widget.account;
    _nameController.text = acc?.name ?? '';
    _selectedType = acc?.type ?? AccountType.cash;
    _selectedCurrency = acc?.currency ?? 'THB';
    _startDate = acc?.startDate ?? DateTime.now();
    _selectedIcon = acc?.icon ?? Icons.account_balance_wallet;
    _selectedIconUrl = acc?.iconUrl ?? '';
    _selectedColor = acc?.color ?? AppColors.accountColors.first;
    _excludeFromNetWorth = acc?.excludeFromNetWorth ?? false;
    _isHidden = acc?.isHidden ?? false;
    _autoUpdateRate = acc?.autoUpdateRate ?? true;
    _statementDay = acc?.statementDay;

    if (_selectedType.isPortfolio) {
      _initialBalanceController.text = acc != null
          ? formatAmount(acc.cashBalance)
          : '';
      _exchangeRateController.text = acc != null
          ? acc.exchangeRate.toString()
          : '1.0';
    } else {
      _initialBalanceController.text = acc != null
          ? formatAmount(acc.initialBalance)
          : '';
      _exchangeRateController.text = '1';
    }

    _amountFocusNode.addListener(_onFocusChange);
    _initialBalanceController.addListener(_handleAmountChanged);
  }

  @override
  void dispose() {
    _amountFocusNode.removeListener(_onFocusChange);
    _initialBalanceController.removeListener(_handleAmountChanged);
    _amountFocusNode.dispose();
    _nameController.dispose();
    _initialBalanceController.dispose();
    _exchangeRateController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!mounted) return;
    if (_amountFocusNode.hasFocus) {
      _showKeyboard(_initialBalanceController);
    } else {
      _closeKeyboard();
    }
  }

  void _handleAmountChanged() {
    if (_isUpdatingController) return;
    _isUpdatingController = true;
    try {
      final text = _initialBalanceController.text;
      final hasOperator = RegExp(r'[+\-*/]').hasMatch(text);

      if (!hasOperator) {
        _formatAmountInput(text);
      } else {
        // Strip commas if operator is present
        final sanitized = text.replaceAll(',', '');
        if (text != sanitized) {
          final selection = _initialBalanceController.selection;
          int commasBeforeCursor = 0;
          if (selection.isValid) {
            final textBeforeCursor = text.substring(0, selection.end);
            commasBeforeCursor = ','.allMatches(textBeforeCursor).length;
          }
          final newOffset = selection.isValid
              ? (selection.end - commasBeforeCursor).clamp(0, sanitized.length)
              : sanitized.length;

          _initialBalanceController.value = TextEditingValue(
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
    final actionColor = _selectedColor;

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

  void _applyAccountTypeDefaults(AccountType type) {
    _selectedType = type;
    if (!type.isPortfolio) return;

    _selectedCurrency = type.defaultCurrency;
    if (type.isThaiPortfolio) {
      _autoUpdateRate = false;
      _exchangeRateController.text = '1';
    } else {
      _autoUpdateRate = true;
      if (_exchangeRateController.text.trim().isEmpty ||
          _exchangeRateController.text.trim() == '1') {
        _exchangeRateController.text = '1.0';
      }
    }
  }

  void _formatAmountInput(String value) {
    final raw = value.replaceAll(',', '');
    if (raw.isEmpty) {
      if (_initialBalanceController.text.isNotEmpty) {
        _initialBalanceController.text = '';
        _initialBalanceController.selection = const TextSelection.collapsed(
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

    if (_initialBalanceController.text != formatted) {
      _initialBalanceController.value = TextEditingValue(
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
      ).showSnackBar(const SnackBar(content: Text('กรุณากรอกชื่อบัญชี')));
      return;
    }

    final balanceText = _initialBalanceController.text
        .replaceAll(',', '')
        .trim();
    final balanceValue = double.tryParse(balanceText) ?? 0;
    final effectiveCurrency = _effectiveSelectedCurrency;
    final exchangeRate = effectiveCurrency == 'USD'
        ? double.tryParse(_exchangeRateController.text.trim()) ?? 1.0
        : 1.0;

    final isPortfolio = _selectedType.isPortfolio;
    final initialBalance = isPortfolio
        ? 0.0
        : !_isEditing && _selectedType == AccountType.debt
        ? -balanceValue.abs()
        : balanceValue;
    final cashBalance = isPortfolio ? balanceValue : 0.0;
    final autoUpdateRate = effectiveCurrency == 'USD' && _autoUpdateRate;

    final provider = context.read<AccountProvider>();

    setState(() => _isLoading = true);

    try {
      if (_isEditing) {
        await provider.updateAccount(
          widget.account!.copyWith(
            name: name,
            type: _selectedType,
            initialBalance: initialBalance,
            currency: effectiveCurrency,
            startDate: _startDate,
            iconUrl: _selectedIconUrl,
            icon: _selectedIcon,
            color: _selectedColor,
            excludeFromNetWorth: _excludeFromNetWorth,
            isHidden: _isHidden,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
            cashBalance: cashBalance,
            exchangeRate: exchangeRate,
            autoUpdateRate: autoUpdateRate,
            statementDay: _selectedType == AccountType.creditCard
                ? _statementDay
                : null,
          ),
        );
      } else {
        await provider.addAccount(
          Account(
            id: provider.generateId(),
            name: name,
            type: _selectedType,
            initialBalance: initialBalance,
            currency: effectiveCurrency,
            startDate: _startDate,
            iconUrl: _selectedIconUrl,
            icon: _selectedIcon,
            color: _selectedColor,
            excludeFromNetWorth: _excludeFromNetWorth,
            isHidden: _isHidden,
            cashBalance: cashBalance,
            exchangeRate: exchangeRate,
            autoUpdateRate: autoUpdateRate,
            statementDay: _selectedType == AccountType.creditCard
                ? _statementDay
                : null,
          ),
        );
      }

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
      title: 'ลบบัญชี',
      message: 'คุณต้องการที่จะลบบัญชีนี้ใช่หรือไม่?',
      confirmLabel: 'ลบ',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    context.read<AccountProvider>().deleteAccount(widget.account!.id);
    _closeKeyboard();
    Navigator.pop(context); // Close form
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

        final expenseColor = _isDarkMode
            ? AppColors.darkExpense
            : AppColors.expense;

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
              _isEditing ? 'แก้ไขบัญชี' : 'เพิ่มบัญชีใหม่',
              style: TextStyle(
                color: textPrimaryColor,
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
                  // 1. Hero Balance Card
                  _buildHeroBalanceCard(
                    surfaceColor: surfaceColor,
                    textPrimaryColor: textPrimaryColor,
                    textSecondaryColor: textSecondaryColor,
                    dividerColor: dividerColor,
                  ),

                  // 2. ข้อมูลบัญชี
                  AppSectionHeader(
                    'ข้อมูลบัญชี',
                    padding: EdgeInsets.fromLTRB(4, 16, 4, 6),
                  ),
                  AppInsetCard(
                    margin: EdgeInsets.zero,
                    children: [
                      _buildTextFieldRow(
                        controller: _nameController,
                        label: 'ชื่อบัญชี',
                        hintText: 'ระบุชื่อบัญชี',
                        icon: Icons.edit_note_rounded,
                        textPrimaryColor: textPrimaryColor,
                        textSecondaryColor: textSecondaryColor,
                      ),
                      const AppCardDivider(indent: 60, endIndent: 16),
                      _buildPickerRow(
                        label: 'ชนิดบัญชี',
                        value: _selectedType.label,
                        icon: Icons.account_balance_wallet_outlined,
                        onTap: _pickAccountType,
                        textPrimaryColor: textPrimaryColor,
                        textSecondaryColor: textSecondaryColor,
                      ),
                      const AppCardDivider(indent: 60, endIndent: 16),
                      if (_selectedType.isPortfolio)
                        _buildReadOnlyRow(
                          label: 'สกุลเงิน',
                          value: _getCurrencyDisplay(
                            _effectiveSelectedCurrency,
                          ),
                          icon: Icons.paid_outlined,
                          badge: 'พอร์ต',
                          textPrimaryColor: textPrimaryColor,
                          textSecondaryColor: textSecondaryColor,
                        )
                      else
                        _buildPickerRow(
                          label: 'สกุลเงิน',
                          value: _getCurrencyDisplay(
                            _effectiveSelectedCurrency,
                          ),
                          icon: Icons.paid_outlined,
                          onTap: _pickCurrency,
                          textPrimaryColor: textPrimaryColor,
                          textSecondaryColor: textSecondaryColor,
                        ),
                      const AppCardDivider(indent: 60, endIndent: 16),
                      _buildPickerRow(
                        label: 'เริ่มวันที่',
                        value: _formatThaiDate(_startDate),
                        icon: Icons.calendar_today_outlined,
                        onTap: _pickDate,
                        textPrimaryColor: textPrimaryColor,
                        textSecondaryColor: textSecondaryColor,
                      ),
                    ],
                  ),

                  // 3. รูปลักษณ์
                  AppSectionHeader(
                    'รูปลักษณ์',
                    padding: EdgeInsets.fromLTRB(4, 16, 4, 6),
                  ),
                  AppInsetCard(
                    margin: EdgeInsets.zero,
                    children: [
                      _buildIconRow(
                        textPrimaryColor: textPrimaryColor,
                        textSecondaryColor: textSecondaryColor,
                      ),
                      const AppCardDivider(indent: 60, endIndent: 16),
                      _buildColorRow(
                        textPrimaryColor: textPrimaryColor,
                        textSecondaryColor: textSecondaryColor,
                      ),
                    ],
                  ),

                  // 4. พอร์ตการลงทุน (USD only or portfolio)
                  if (_effectiveSelectedCurrency == 'USD' ||
                      _selectedType.isPortfolio) ...[
                    AppSectionHeader(
                      'พอร์ตการลงทุน',
                      padding: EdgeInsets.fromLTRB(4, 16, 4, 6),
                    ),
                    AppInsetCard(
                      margin: EdgeInsets.zero,
                      children: [
                        if (_effectiveSelectedCurrency == 'USD') ...[
                          _buildSwitchRow(
                            label: 'อัปเดตอัตราแลกเปลี่ยนอัตโนมัติ',
                            subtitle:
                                'ดึงอัตราแลกเปลี่ยน USD/THB จากระบบโดยอัตโนมัติ',
                            value: _autoUpdateRate,
                            onChanged: (v) =>
                                setState(() => _autoUpdateRate = v),
                            textPrimaryColor: textPrimaryColor,
                            textSecondaryColor: textSecondaryColor,
                          ),
                          if (!_autoUpdateRate) ...[
                            const AppCardDivider(indent: 60, endIndent: 16),
                            _buildExchangeRateField(
                              textPrimaryColor: textPrimaryColor,
                              textSecondaryColor: textSecondaryColor,
                            ),
                          ],
                        ] else
                          _buildReadOnlyRow(
                            label: 'อัตราแลกเปลี่ยน',
                            value: '1.0 (THB)',
                            icon: Icons.currency_exchange_rounded,
                            badge: 'สกุลบาท',
                            textPrimaryColor: textPrimaryColor,
                            textSecondaryColor: textSecondaryColor,
                          ),
                      ],
                    ),
                  ],

                  // 5. บัตรเครดิต
                  if (_selectedType == AccountType.creditCard) ...[
                    AppSectionHeader(
                      'บัตรเครดิต',
                      padding: EdgeInsets.fromLTRB(4, 16, 4, 6),
                    ),
                    AppInsetCard(
                      margin: EdgeInsets.zero,
                      children: [
                        _buildStatementDayPicker(
                          textPrimaryColor: textPrimaryColor,
                          textSecondaryColor: textSecondaryColor,
                        ),
                      ],
                    ),
                  ],

                  // 6. สวิตช์การแสดงผลและคำนวณ
                  AppSectionHeader(
                    'การแสดงผลและคำนวณ',
                    padding: EdgeInsets.fromLTRB(4, 16, 4, 6),
                  ),
                  AppInsetCard(
                    margin: EdgeInsets.zero,
                    children: [
                      _buildSwitchRow(
                        label: 'ไม่รวมในทรัพย์สินสุทธิ',
                        subtitle:
                            'ไม่นำยอดเงินในบัญชีนี้ไปคำนวณในสินทรัพย์สุทธิ (Net Worth)',
                        value: _excludeFromNetWorth,
                        onChanged: (v) =>
                            setState(() => _excludeFromNetWorth = v),
                        textPrimaryColor: textPrimaryColor,
                        textSecondaryColor: textSecondaryColor,
                      ),
                      const AppCardDivider(indent: 60, endIndent: 16),
                      _buildSwitchRow(
                        label: 'ซ่อนบัญชีนี้',
                        subtitle: 'ซ่อนบัญชีนี้จากหน้ารายการบัญชีหลัก',
                        value: _isHidden,
                        onChanged: (v) => setState(() => _isHidden = v),
                        textPrimaryColor: textPrimaryColor,
                        textSecondaryColor: textSecondaryColor,
                      ),
                    ],
                  ),

                  // 7. Delete card if editing
                  if (_isEditing)
                    _buildDeleteCard(
                      surfaceColor: surfaceColor,
                      expenseColor: expenseColor,
                      dividerColor: dividerColor,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeroBalanceCard({
    required Color surfaceColor,
    required Color textPrimaryColor,
    required Color textSecondaryColor,
    required Color dividerColor,
  }) {
    final isPortfolio = _selectedType.isPortfolio;
    final isDebt = _selectedType == AccountType.debt;
    final currencyText = _effectiveSelectedCurrency == 'USD' ? 'USD' : 'THB';

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppRadii.xLarge),
        border: Border.all(
          color: dividerColor.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isPortfolio ? 'เงินสดใน Broker' : 'ยอดเงินเริ่มต้น',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textSecondaryColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: dividerColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppRadii.full),
                ),
                child: Text(
                  currencyText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: textPrimaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _initialBalanceController,
            focusNode: _amountFocusNode,
            readOnly: calculatorTextFieldReadOnly,
            showCursor: true,
            keyboardType: calculatorTextInputType,
            inputFormatters: calculatorTextInputFormatters,
            textAlign: TextAlign.left,
            decoration: InputDecoration(
              hintText: '0.00',
              hintStyle: TextStyle(
                color: textSecondaryColor.withValues(alpha: 0.5),
                fontSize: 34,
                fontWeight: FontWeight.w700,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
              filled: false,
            ),
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: isDebt
                  ? (_isDarkMode ? AppColors.darkExpense : AppColors.expense)
                  : textPrimaryColor,
            ),
          ),
          if (isDebt) ...[
            const SizedBox(height: 8),
            Text(
              'ระบบจะบันทึกยอดหนี้สินเป็นยอดติดลบในทรัพย์สินสุทธิโดยอัตโนมัติ',
              style: TextStyle(
                fontSize: 12,
                color: _isDarkMode ? AppColors.darkExpense : AppColors.expense,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextFieldRow({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData icon,
    required Color textPrimaryColor,
    required Color textSecondaryColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: textSecondaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: textSecondaryColor, size: 18),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: textPrimaryColor,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(
                  color: textSecondaryColor.withValues(alpha: 0.5),
                  fontSize: 15,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                isDense: true,
                filled: false,
              ),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: textPrimaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerRow({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
    required Color textPrimaryColor,
    required Color textSecondaryColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: textSecondaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: textSecondaryColor, size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: textPrimaryColor,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: textSecondaryColor,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right,
              color: textSecondaryColor.withValues(alpha: 0.5),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyRow({
    required String label,
    required String value,
    required IconData icon,
    String? badge,
    required Color textPrimaryColor,
    required Color textSecondaryColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: textSecondaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: textSecondaryColor, size: 18),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: textPrimaryColor,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: textSecondaryColor,
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: textSecondaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadii.full),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: textSecondaryColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIconRow({
    required Color textPrimaryColor,
    required Color textSecondaryColor,
  }) {
    return InkWell(
      onTap: _pickIcon,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: textSecondaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.palette_outlined,
                color: textSecondaryColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'ไอคอน',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: textPrimaryColor,
              ),
            ),
            const Spacer(),
            if (_selectedIconUrl.isNotEmpty && _isUploadedIcon)
              _buildCustomIconPreview()
            else
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _selectedColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_selectedIcon, color: _selectedColor, size: 22),
              ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right,
              color: textSecondaryColor.withValues(alpha: 0.5),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  /// Check if the currently selected icon URL is a stored icon
  bool get _isUploadedIcon =>
      _selectedIconUrl.isNotEmpty &&
      AccountIconStorageService().isStoredIconUrl(_selectedIconUrl);

  Widget _buildCustomIconPreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: CachedNetworkImage(
        imageUrl: _selectedIconUrl,
        width: 36,
        height: 36,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _selectedColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (context, url, error) => Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _selectedColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_selectedIcon, color: _selectedColor, size: 22),
        ),
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
      ),
    );
  }

  Widget _buildColorRow({
    required Color textPrimaryColor,
    required Color textSecondaryColor,
  }) {
    return InkWell(
      onTap: _pickColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: textSecondaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.color_lens_outlined,
                color: textSecondaryColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'สีประจำบัญชี',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: textPrimaryColor,
              ),
            ),
            const Spacer(),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _selectedColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: _selectedColor.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right,
              color: textSecondaryColor.withValues(alpha: 0.5),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchRow({
    required String label,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color textPrimaryColor,
    required Color textSecondaryColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: textPrimaryColor,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: textSecondaryColor),
                  ),
                ],
              ],
            ),
          ),
          AppSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildExchangeRateField({
    required Color textPrimaryColor,
    required Color textSecondaryColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: textSecondaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.currency_exchange_rounded,
              color: textSecondaryColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'USD / THB',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: textPrimaryColor,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 100,
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
                hintText: '1.0',
                hintStyle: TextStyle(
                  color: textSecondaryColor.withValues(alpha: 0.5),
                  fontSize: 15,
                ),
                suffixText: ' บาท',
                suffixStyle: TextStyle(color: textSecondaryColor, fontSize: 14),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                isDense: true,
                filled: false,
              ),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: textPrimaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatementDayPicker({
    required Color textPrimaryColor,
    required Color textSecondaryColor,
  }) {
    return InkWell(
      onTap: _pickStatementDay,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: textSecondaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.credit_card_rounded,
                color: textSecondaryColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'วันสรุปยอดบิล',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: textPrimaryColor,
              ),
            ),
            const Spacer(),
            Text(
              _statementDay != null ? 'ทุกวันที่ $_statementDay' : 'ไม่ระบุ',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: textSecondaryColor,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right,
              color: textSecondaryColor.withValues(alpha: 0.5),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteCard({
    required Color surfaceColor,
    required Color expenseColor,
    required Color dividerColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(AppRadii.xLarge),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _isLoading ? null : _delete,
          borderRadius: BorderRadius.circular(AppRadii.xLarge),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.xLarge),
              border: Border.all(
                color: expenseColor.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.delete_outline_rounded,
                  color: expenseColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'ลบบัญชีนี้',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: expenseColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _pickStatementDay() {
    showAppModalBottomSheet(
      context: context,
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

          return SafeArea(
            child: Container(
              color: surfaceColor,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppModalBottomSheetHeader(title: 'เลือกวันสรุปยอด'),
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
                        return Material(
                          color: selected
                              ? headerColor.withValues(alpha: 0.2)
                              : surfaceColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: selected
                                ? BorderSide(color: headerColor, width: 2)
                                : BorderSide(
                                    color: textSecondaryColor.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () {
                              setState(() => _statementDay = day);
                              Navigator.pop(context);
                            },
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
    showAppModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Consumer<SettingsProvider>(
        builder: (context, settingsProvider, _) {
          final isDarkMode = settingsProvider.isDarkMode;
          final textPrimaryColor = isDarkMode
              ? AppColors.darkTextPrimary
              : AppColors.textPrimary;
          final headerColor = isDarkMode
              ? AppColors.darkIncome
              : AppColors.header;

          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.75,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppModalBottomSheetHeader(title: 'เลือกชนิดบัญชี'),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: AccountType.values.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        color: AppColors.listDividerFor(isDarkMode),
                      ),
                      itemBuilder: (_, i) {
                        final type = AccountType.values[i];
                        final isSelected = _selectedType == type;
                        return ListTile(
                          title: Text(
                            type.label,
                            style: TextStyle(
                              color: textPrimaryColor,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(Icons.check, color: headerColor)
                              : null,
                          onTap: () {
                            setState(() {
                              _applyAccountTypeDefaults(type);
                              _initialBalanceController.clear();
                            });
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
        },
      ),
    );
  }

  String _getCurrencyDisplay(String code) {
    return CurrencyUtils.getCurrencyDisplay(code);
  }

  void _pickCurrency() {
    if (_selectedType.isPortfolio) return;

    showAppModalBottomSheet(
      context: context,
      isScrollControlled: true,
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

          return AppDraggableSheet(
            builder: (context, scrollController) => SafeArea(
              child: CustomScrollView(
                controller: scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: AppModalBottomSheetHeader(title: 'เลือกสกุลเงิน'),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate((_, i) {
                      final currency = CurrencyUtils.currencies[i];
                      final code = currency['code']!;
                      final symbol = currency['symbol']!;
                      final name = currency['name']!;
                      final selected = code == _selectedCurrency;
                      return ListTile(
                        tileColor: surfaceColor,
                        title: Text(
                          '$code - $name',
                          style: TextStyle(
                            color: textPrimaryColor,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          'สัญลักษณ์: $symbol',
                          style: TextStyle(
                            color: textSecondaryColor,
                            fontSize: 13,
                          ),
                        ),
                        trailing: selected
                            ? Icon(Icons.check, color: headerColor)
                            : null,
                        onTap: () {
                          setState(() => _selectedCurrency = code);
                          Navigator.pop(context);
                        },
                      );
                    }, childCount: CurrencyUtils.currencies.length),
                  ),
                ],
              ),
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
    // First, show a menu to choose between icons or custom image
    showAppModalBottomSheet(
      context: context,
      builder: (_) => Consumer<SettingsProvider>(
        builder: (context, settingsProvider, _) {
          final isDarkMode = settingsProvider.isDarkMode;
          final textColor = isDarkMode
              ? AppColors.darkTextPrimary
              : AppColors.textPrimary;
          final textSecondary = isDarkMode
              ? AppColors.darkTextSecondary
              : AppColors.textSecondary;
          final dividerColor = isDarkMode
              ? AppColors.darkDivider
              : AppColors.divider;
          final incomeColor = isDarkMode
              ? AppColors.darkIncome
              : AppColors.income;
          final expenseColor = isDarkMode
              ? AppColors.darkExpense
              : AppColors.expense;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppModalBottomSheetHeader(title: 'รูปและไอคอน'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadii.xLarge),
                      border: Border.all(
                        color: dividerColor.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        if (_selectedIconUrl.isNotEmpty && _isUploadedIcon) ...[
                          ListTile(
                            leading: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: expenseColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(
                                  AppRadii.medium,
                                ),
                              ),
                              child: Icon(
                                Icons.delete_outline_rounded,
                                color: expenseColor,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              'ลบรูปที่อัปโหลด',
                              style: TextStyle(
                                color: expenseColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onTap: () {
                              setState(() {
                                _selectedIconUrl = '';
                              });
                              Navigator.pop(context);
                            },
                          ),
                          Divider(
                            height: 1,
                            indent: 58,
                            endIndent: 16,
                            color: dividerColor.withValues(alpha: 0.3),
                          ),
                        ],
                        ListTile(
                          leading: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: incomeColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(
                                AppRadii.medium,
                              ),
                            ),
                            child: Icon(
                              Icons.image_outlined,
                              color: incomeColor,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            'อัปโหลดรูปภาพ',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            'เลือกรูปจากคลังภาพในเครื่อง',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _pickCustomIcon();
                          },
                        ),
                        Divider(
                          height: 1,
                          indent: 58,
                          endIndent: 16,
                          color: dividerColor.withValues(alpha: 0.3),
                        ),
                        ListTile(
                          leading: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: textColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(
                                AppRadii.medium,
                              ),
                            ),
                            child: Icon(
                              Icons.grid_view_rounded,
                              color: textColor,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            'เลือกไอคอน',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            'เลือกจากชุดไอคอนมาตรฐาน',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _showIconGrid();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickCustomIcon() async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
      );

      if (pickedFile == null) return;

      final bytes = await pickedFile.readAsBytes();
      final extension = pickedFile.name.contains('.')
          ? pickedFile.name.split('.').last.toLowerCase()
          : 'png';
      final contentType = _mimeTypeForExtension(extension);

      if (bytes.isEmpty) return;

      // Generate a temporary ID for the upload (for new accounts)
      final tempId =
          widget.account?.id ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';

      final storageService = AccountIconStorageService();
      final publicUrl = await storageService.uploadAccountIcon(
        accountId: tempId,
        bytes: bytes,
        extension: extension,
        contentType: contentType,
      );

      if (publicUrl != null && mounted) {
        setState(() {
          _selectedIconUrl = publicUrl;
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่สามารถอัปโหลดรูปภาพได้')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
      }
    }
  }

  String _mimeTypeForExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/png';
    }
  }

  void _showIconGrid() {
    showAppModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Consumer<SettingsProvider>(
        builder: (context, settingsProvider, _) {
          final isDarkMode = settingsProvider.isDarkMode;
          final bgColor = isDarkMode
              ? AppColors.darkBackground
              : AppColors.background;
          final textSecondaryColor = isDarkMode
              ? AppColors.darkTextSecondary
              : AppColors.textSecondary;

          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.65,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppModalBottomSheetHeader(title: 'เลือกไอคอน'),
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
                        return Material(
                          color: selected
                              ? _selectedColor.withValues(alpha: 0.2)
                              : bgColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: selected
                                ? BorderSide(color: _selectedColor, width: 2)
                                : BorderSide.none,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedIcon = icon;
                                _selectedIconUrl = '';
                              });
                              Navigator.pop(context);
                            },
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
            ),
          );
        },
      ),
    );
  }

  void _pickColor() {
    showAppModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.55,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppModalBottomSheetHeader(title: 'เลือกสี'),
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
                    final selected =
                        color.toARGB32() == _selectedColor.toARGB32();
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
                          setState(() => _selectedColor = color);
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
