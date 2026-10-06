import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../widgets/calculator_keyboard_host.dart';
import 'account_form_pickers.dart';
import 'account_form_rows.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/account.dart';
import '../../providers/account_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/account_icon_storage_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../main.dart';
import '../../widgets/day_of_month_picker_sheet.dart';
import '../../utils/currency_utils.dart';
import '../../widgets/app_bar_buttons.dart';
import '../../widgets/app_inset_card.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/icon_color_picker_sheet.dart';
import '../../widgets/app_date_picker_sheet.dart';

class AccountFormScreen extends StatefulWidget {
  final Account? account;

  const AccountFormScreen({super.key, this.account});

  @override
  State<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends State<AccountFormScreen>
    with CalculatorKeyboardHost {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _amountFocusNode = FocusNode();

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
  int? _paymentDueDay;

  bool get _isEditing => widget.account != null;
  String get _effectiveSelectedCurrency => _selectedType.isPortfolio
      ? _selectedType.defaultCurrency
      : _selectedCurrency;
  bool _isDarkMode = false;
  bool _isLoading = false;

  @override
  GlobalKey<ScaffoldState> get calculatorScaffoldKey => _scaffoldKey;

  @override
  TextEditingController get calculatorController => _initialBalanceController;

  @override
  FocusNode get calculatorFocusNode => _amountFocusNode;

  @override
  Color get calculatorActionColor => _selectedColor;

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
    _paymentDueDay = acc?.paymentDueDay;

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

    attachCalculatorKeyboard();
  }

  @override
  void dispose() {
    detachCalculatorKeyboard();
    _amountFocusNode.dispose();
    _nameController.dispose();
    _initialBalanceController.dispose();
    _exchangeRateController.dispose();
    _noteController.dispose();
    super.dispose();
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
            paymentDueDay: _selectedType == AccountType.creditCard
                ? _paymentDueDay
                : null,
            clearStatementDay:
                _selectedType != AccountType.creditCard ||
                _statementDay == null,
            clearPaymentDueDay:
                _selectedType != AccountType.creditCard ||
                _paymentDueDay == null,
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
            paymentDueDay: _selectedType == AccountType.creditCard
                ? _paymentDueDay
                : null,
          ),
        );
      }

      if (mounted) {
        closeCalculatorKeyboard();
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
    closeCalculatorKeyboard();
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
                      closeCalculatorKeyboard();
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
              closeCalculatorKeyboard();
            },
            child: AbsorbPointer(
              absorbing: _isLoading,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                children: [
                  // 1. Hero Balance Card
                  buildAccountHeroBalanceCard(
                    selectedType: _selectedType,
                    effectiveSelectedCurrency: _effectiveSelectedCurrency,
                    initialBalanceController: _initialBalanceController,
                    amountFocusNode: _amountFocusNode,
                    isDarkMode: _isDarkMode,
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
                      buildAccountTextFieldRow(
                        controller: _nameController,
                        label: 'ชื่อบัญชี',
                        hintText: 'ระบุชื่อบัญชี',
                        icon: Icons.edit_note_rounded,
                        textPrimaryColor: textPrimaryColor,
                        textSecondaryColor: textSecondaryColor,
                      ),
                      const AppCardDivider(),
                      buildAccountPickerRow(
                        label: 'ชนิดบัญชี',
                        value: _selectedType.label,
                        icon: Icons.account_balance_wallet_outlined,
                        onTap: _pickAccountType,
                        textPrimaryColor: textPrimaryColor,
                        textSecondaryColor: textSecondaryColor,
                      ),
                      const AppCardDivider(),
                      if (_selectedType.isPortfolio)
                        buildAccountReadOnlyRow(
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
                        buildAccountPickerRow(
                          label: 'สกุลเงิน',
                          value: _getCurrencyDisplay(
                            _effectiveSelectedCurrency,
                          ),
                          icon: Icons.paid_outlined,
                          onTap: _pickCurrency,
                          textPrimaryColor: textPrimaryColor,
                          textSecondaryColor: textSecondaryColor,
                        ),
                      const AppCardDivider(),
                      buildAccountPickerRow(
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
                      IconPickerFormRow(
                        icon: _selectedIcon,
                        color: _selectedColor,
                        onTap: _pickIcon,
                        preview: _isUploadedIcon
                            ? _buildCustomIconPreview()
                            : null,
                      ),
                      const AppCardDivider(),
                      ColorPickerFormRow(
                        label: 'สีประจำบัญชี',
                        color: _selectedColor,
                        onTap: _pickColor,
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
                          buildAccountSwitchRow(
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
                            const AppCardDivider(),
                            buildAccountExchangeRateField(
                              exchangeRateController: _exchangeRateController,
                              textPrimaryColor: textPrimaryColor,
                              textSecondaryColor: textSecondaryColor,
                            ),
                          ],
                        ] else
                          buildAccountReadOnlyRow(
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
                        buildAccountDayPickerRow(
                          icon: Icons.credit_card_rounded,
                          label: 'วันสรุปยอดบิล',
                          value: _statementDay != null
                              ? 'ทุกวันที่ $_statementDay'
                              : 'ไม่ระบุ',
                          onTap: _pickStatementDay,
                          textPrimaryColor: textPrimaryColor,
                          textSecondaryColor: textSecondaryColor,
                        ),
                        const AppCardDivider(),
                        buildAccountDayPickerRow(
                          icon: Icons.event_available_rounded,
                          label: 'วันครบกำหนดชำระ',
                          value: _paymentDueDay != null
                              ? 'ทุกวันที่ $_paymentDueDay'
                              : 'สรุปยอด + 15 วัน',
                          onTap: _pickPaymentDueDay,
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
                      buildAccountSwitchRow(
                        label: 'ไม่รวมในทรัพย์สินสุทธิ',
                        subtitle:
                            'ไม่นำยอดเงินในบัญชีนี้ไปคำนวณในสินทรัพย์สุทธิ (Net Worth)',
                        value: _excludeFromNetWorth,
                        onChanged: (v) =>
                            setState(() => _excludeFromNetWorth = v),
                        textPrimaryColor: textPrimaryColor,
                        textSecondaryColor: textSecondaryColor,
                      ),
                      const AppCardDivider(),
                      buildAccountSwitchRow(
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
                    buildAccountDeleteCard(
                      isLoading: _isLoading,
                      onDelete: _delete,
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

  /// Check if the currently selected icon URL is a stored icon
  bool get _isUploadedIcon =>
      _selectedIconUrl.isNotEmpty &&
      AccountIconStorageService().isStoredIconUrl(_selectedIconUrl);

  Widget _buildCustomIconPreview() {
    final fallback = IconPickerPreview(
      icon: _selectedIcon,
      color: _selectedColor,
    );
    final placeholder = PickerPreviewBox(
      color: _selectedColor.withValues(alpha: 0.15),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
    // Match AccountIconWidget's workaround for Web image lifetime.
    final image = kIsWeb
        ? Image.network(
            _selectedIconUrl,
            width: pickerPreviewSize,
            height: pickerPreviewSize,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : placeholder,
            errorBuilder: (context, error, stackTrace) => fallback,
          )
        : CachedNetworkImage(
            imageUrl: _selectedIconUrl,
            width: pickerPreviewSize,
            height: pickerPreviewSize,
            fit: BoxFit.cover,
            placeholder: (context, url) => placeholder,
            errorWidget: (context, url, error) => fallback,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
          );
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.medium),
      child: image,
    );
  }

  Future<void> _pickStatementDay() async {
    final pick = await showDayOfMonthPickerSheet(
      context: context,
      title: 'เลือกวันสรุปยอด',
      selectedDay: _statementDay,
      clearLabel: 'ลบวันสรุปยอด',
    );
    if (pick == null || !mounted) return;
    setState(() => _statementDay = pick.day);
  }

  Future<void> _pickPaymentDueDay() async {
    final pick = await showDayOfMonthPickerSheet(
      context: context,
      title: 'เลือกวันครบกำหนดชำระ',
      selectedDay: _paymentDueDay,
      clearLabel: 'ใช้ค่าเริ่มต้น (สรุปยอด + 15 วัน)',
    );
    if (pick == null || !mounted) return;
    setState(() => _paymentDueDay = pick.day);
  }

  void _pickAccountType() {
    showAccountTypePicker(
      context,
      selected: _selectedType,
      onSelected: (type) {
        setState(() {
          _applyAccountTypeDefaults(type);
          _initialBalanceController.clear();
        });
      },
    );
  }

  void _pickCurrency() {
    if (_selectedType.isPortfolio) return;

    showAccountCurrencyPicker(
      context,
      selectedCurrency: _selectedCurrency,
      onSelected: (code) => setState(() => _selectedCurrency = code),
    );
  }

  void _pickIcon() {
    // First, show a menu to choose between icons or custom image
    showAccountIconSourceSheet(
      context,
      canRemoveUploadedIcon: _selectedIconUrl.isNotEmpty && _isUploadedIcon,
      onRemoveUploadedIcon: () {
        setState(() {
          _selectedIconUrl = '';
        });
      },
      onPickCustomIcon: _pickCustomIcon,
      onPickFromGrid: _showIconGrid,
    );
  }

  String _getCurrencyDisplay(String code) {
    return CurrencyUtils.getCurrencyDisplay(code);
  }

  Future<void> _pickDate() async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _startDate,
    );
    if (picked != null && mounted) {
      setState(() => _startDate = picked);
    }
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
      final contentType = accountIconMimeTypeForExtension(extension);

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

  Future<void> _showIconGrid() async {
    final icon = await showIconPickerSheet(
      context: context,
      title: 'เลือกไอคอน',
      selectedIcon: _selectedIcon,
      accentColor: _selectedColor,
    );
    if (icon == null || !mounted) return;
    setState(() {
      _selectedIcon = icon;
      _selectedIconUrl = '';
    });
  }

  Future<void> _pickColor() async {
    final color = await showColorPickerSheet(
      context: context,
      title: 'เลือกสี',
      selectedColor: _selectedColor,
    );
    if (color == null || !mounted) return;
    setState(() => _selectedColor = color);
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
