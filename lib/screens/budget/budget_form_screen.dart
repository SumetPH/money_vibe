import 'package:flutter/material.dart';
import '../../widgets/calculator_keyboard_host.dart';
import 'budget_category_picker_sheet.dart';
import 'budget_form_widgets.dart';
import 'package:provider/provider.dart';
import '../../models/budget.dart';
import '../../models/category.dart';
import '../../providers/budget_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../main.dart';
import '../../widgets/calculator_text_field_config.dart';
import '../../widgets/app_bar_buttons.dart';
import '../../widgets/app_inset_card.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/icon_color_picker_sheet.dart';
import '../../widgets/app_segmented_tabs.dart';

class BudgetFormScreen extends StatefulWidget {
  final Budget? budget;

  const BudgetFormScreen({super.key, this.budget});

  @override
  State<BudgetFormScreen> createState() => _BudgetFormScreenState();
}

class _BudgetFormScreenState extends State<BudgetFormScreen>
    with CalculatorKeyboardHost {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _amountFocusNode = FocusNode();

  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _groupController = TextEditingController();

  late IconData _selectedIcon;
  late Color _selectedColor;
  late Set<String> _selectedCategoryIds;
  late BudgetType _selectedType;
  late bool _isHidden;
  bool _isLoading = false;

  bool get _isEditing => widget.budget != null;

  @override
  GlobalKey<ScaffoldState> get calculatorScaffoldKey => _scaffoldKey;

  @override
  TextEditingController get calculatorController => _amountController;

  @override
  FocusNode get calculatorFocusNode => _amountFocusNode;

  @override
  Color get calculatorActionColor => _selectedColor;

  @override
  void initState() {
    super.initState();
    final b = widget.budget;
    _nameController.text = b?.name ?? '';
    _amountController.text = b != null ? formatAmount(b.amount) : '';
    _groupController.text = b?.groupName ?? '';
    _selectedIcon = b?.icon ?? Icons.savings_rounded;
    _selectedColor = b?.color ?? AppColors.accountColors.first;
    _selectedCategoryIds = Set<String>.from(b?.categoryIds ?? []);
    _selectedType = b?.type ?? BudgetType.expense;
    _isHidden = b?.isHidden ?? false;

    attachCalculatorKeyboard();
  }

  @override
  void dispose() {
    detachCalculatorKeyboard();
    _amountFocusNode.dispose();
    _nameController.dispose();
    _amountController.dispose();
    _groupController.dispose();
    super.dispose();
  }

  String _buildBudgetConflictMessage(
    BudgetCategoryConflictException error,
    CategoryProvider categoryProvider,
  ) {
    final categoryName =
        categoryProvider.findById(error.categoryId)?.name ?? 'หมวดหมู่นี้';
    return '$categoryName ใช้อยู่ในงบ "${error.budgetName}" แล้ว';
  }

  void _pickCategories(
    BuildContext context,
    List<Category> categories,
    BudgetProvider budgetProvider,
    bool isDark,
  ) {
    showBudgetCategoryPicker(
      context,
      categories,
      budgetProvider,
      isDark,
      selectedCategoryIds: _selectedCategoryIds,
      excludingBudgetId: widget.budget?.id,
      confirmCategoryTransfer: _confirmCategoryTransfer,
      isMounted: () => mounted,
      onChanged: () => setState(() {}),
    );
  }

  Future<bool> _confirmCategoryTransfer(
    BuildContext context, {
    required Category category,
    required Budget sourceBudget,
  }) {
    final editedName = _nameController.text.trim();
    final targetBudgetName = editedName.isNotEmpty
        ? editedName
        : widget.budget?.name ?? 'งบปัจจุบัน';

    return showAppConfirmDialog(
      context: context,
      title: 'ย้ายหมวดหมู่',
      message:
          'หมวดหมู่ "${category.name}" ใช้อยู่ในงบ '
          '"${sourceBudget.name}"\n\n'
          'หากยืนยัน หมวดหมู่นี้จะถูกย้ายมาอยู่ในงบ '
          '"$targetBudgetName" เมื่อบันทึก',
      confirmLabel: 'ย้ายมา',
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('กรุณากรอกชื่องบประมาณ'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
        ),
      );
      return;
    }

    final rawAmount = _amountController.text.replaceAll(',', '').trim();
    final amount = double.tryParse(rawAmount) ?? -1;
    if (amount < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('กรุณากรอกจำนวนเงิน'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
        ),
      );
      return;
    }

    final provider = context.read<BudgetProvider>();
    final categoryProvider = context.read<CategoryProvider>();
    final groupName = _groupController.text.trim().isEmpty
        ? null
        : _groupController.text.trim();

    setState(() => _isLoading = true);

    try {
      if (_isEditing) {
        await provider.updateBudgetWithCategoryTransfers(
          widget.budget!.copyWith(
            name: name,
            amount: amount,
            categoryIds: _selectedCategoryIds.toList(),
            icon: _selectedIcon,
            color: _selectedColor,
            groupName: groupName,
            clearGroupName: groupName == null,
            type: _selectedType,
            isHidden: _isHidden,
          ),
        );
      } else {
        await provider.addBudgetWithCategoryTransfers(
          Budget(
            id: provider.generateId(),
            name: name,
            amount: amount,
            categoryIds: _selectedCategoryIds.toList(),
            icon: _selectedIcon,
            color: _selectedColor,
            groupName: groupName,
            type: _selectedType,
            isHidden: _isHidden,
          ),
        );
      }
      if (mounted) {
        closeCalculatorKeyboard();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        final message = switch (e) {
          BudgetNameConflictException() =>
            'มีงบประมาณชื่อ "${e.name}" อยู่แล้ว',
          BudgetCategoryConflictException() => _buildBudgetConflictMessage(
            e,
            categoryProvider,
          ),
          _ => 'เกิดข้อผิดพลาดในการบันทึก: $e',
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message, style: const TextStyle(color: Colors.white)),
            backgroundColor: AppColors.expense,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.medium),
            ),
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
      title: 'ลบงบประมาณ',
      message:
          'คุณต้องการลบงบประมาณ "${widget.budget?.name}" ใช่หรือไม่? รายการธุรกรรมเดิมจะไม่ได้รับผลกระทบ',
      confirmLabel: 'ลบงบประมาณ',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    final provider = context.read<BudgetProvider>();
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    setState(() => _isLoading = true);
    try {
      await provider.deleteBudget(widget.budget!.id);
      if (mounted) {
        closeCalculatorKeyboard();
        navigator.pop(); // Close form
      }
    } catch (e) {
      if (mounted) {
        closeCalculatorKeyboard();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('ลบงบประมาณไม่สำเร็จ: $e'),
            backgroundColor: AppColors.expense,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.medium),
            ),
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
    return Consumer3<CategoryProvider, BudgetProvider, SettingsProvider>(
      builder: (context, catProvider, budgetProvider, sp, _) {
        final isDark = sp.isDarkMode;
        final bgColor = isDark
            ? AppColors.darkBackground
            : AppColors.background;
        final surfaceColor = isDark ? AppColors.darkSurface : AppColors.surface;
        final textPrimaryColor = isDark
            ? AppColors.darkTextPrimary
            : AppColors.textPrimary;
        final textSecondaryColor = isDark
            ? AppColors.darkTextSecondary
            : AppColors.textSecondary;
        final dividerColor = isDark ? AppColors.darkDivider : AppColors.divider;

        final expenseCategories = catProvider.categoriesOfType(
          CategoryType.expense,
        );
        final selectedNames = expenseCategories
            .where((c) => _selectedCategoryIds.contains(c.id))
            .map((c) => c.name)
            .toList();
        final categoryLabel = _selectedCategoryIds.isEmpty
            ? 'ยังไม่ได้เลือกหมวดหมู่'
            : selectedNames.isEmpty
            ? '${_selectedCategoryIds.length} หมวดหมู่'
            : selectedNames.join(', ');

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
              _isEditing ? 'แก้ไขงบประมาณ' : 'เพิ่มงบประมาณใหม่',
              style: TextStyle(
                color: textPrimaryColor,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            actions: [AppSaveButton(onPressed: _save, isLoading: _isLoading)],
          ),
          body: AbsorbPointer(
            absorbing: _isLoading,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
              children: [
                // 1. Live Budget Preview Hero Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: buildBudgetLivePreviewCard(
                    name: _nameController.text.trim(),
                    group: _groupController.text.trim(),
                    amountText: _amountController.text.trim(),
                    selectedType: _selectedType,
                    selectedColor: _selectedColor,
                    selectedIcon: _selectedIcon,
                    surfaceColor: surfaceColor,
                    dividerColor: dividerColor,
                    textPrimaryColor: textPrimaryColor,
                    textSecondaryColor: textSecondaryColor,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(height: 12),

                // 2. Section: ข้อมูลทั่วไป
                AppSectionHeader('ข้อมูลทั่วไป'),
                AppInsetCard(
                  children: [
                    buildBudgetInputFieldRow(
                      icon: Icons.edit_note_rounded,
                      label: 'ชื่อ',
                      hintText: 'ชื่องบประมาณ',
                      controller: _nameController,
                      textPrimaryColor: textPrimaryColor,
                      textSecondaryColor: textSecondaryColor,
                      onChanged: (_) => setState(() {}),
                    ),
                    const AppCardDivider(),
                    buildBudgetInputFieldRow(
                      icon: Icons.folder_outlined,
                      label: 'กลุ่ม',
                      hintText: 'ชื่อกลุ่ม (ไม่บังคับ)',
                      controller: _groupController,
                      textPrimaryColor: textPrimaryColor,
                      textSecondaryColor: textSecondaryColor,
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),

                // 3. Section: จำนวนเงินและประเภท
                AppSectionHeader('จำนวนเงินและประเภท'),
                AppInsetCard(
                  children: [
                    // Amount Input Box
                    _buildAmountInputRow(
                      surfaceColor: surfaceColor,
                      textPrimaryColor: textPrimaryColor,
                      textSecondaryColor: textSecondaryColor,
                      isDark: isDark,
                    ),
                    const AppCardDivider(),
                    // Type Selector
                    _buildTypeSelectorRow(
                      surfaceColor: surfaceColor,
                      textPrimaryColor: textPrimaryColor,
                      textSecondaryColor: textSecondaryColor,
                      isDark: isDark,
                    ),
                    // Categories picker (Only if expense type)
                    if (_selectedType == BudgetType.expense) ...[
                      const AppCardDivider(),
                      buildBudgetPickerRow(
                        icon: Icons.category_outlined,
                        label: 'หมวดหมู่',
                        value: categoryLabel,
                        onTap: () => _pickCategories(
                          context,
                          expenseCategories,
                          budgetProvider,
                          isDark,
                        ),
                        surfaceColor: surfaceColor,
                        textPrimaryColor: textPrimaryColor,
                        textSecondaryColor: textSecondaryColor,
                      ),
                    ],
                    const AppCardDivider(),
                    // Hide Budget Switch (CupertinoSwitch)
                    buildBudgetSwitchRow(
                      icon: Icons.visibility_off_outlined,
                      title: 'ซ่อนงบประมาณนี้',
                      subtitle: 'ไม่แสดงในหน้ารวมงบประมาณหลัก',
                      value: _isHidden,
                      isDark: isDark,
                      textColor: textPrimaryColor,
                      textSecondary: textSecondaryColor,
                      onChanged: (val) => setState(() => _isHidden = val),
                    ),
                  ],
                ),

                // 4. Section: รูปลักษณ์
                AppSectionHeader('รูปลักษณ์'),
                AppInsetCard(
                  children: [
                    IconPickerFormRow(
                      icon: _selectedIcon,
                      color: _selectedColor,
                      onTap: _pickIcon,
                    ),
                    const AppCardDivider(),
                    ColorPickerFormRow(
                      label: 'สีประจำงบประมาณ',
                      color: _selectedColor,
                      onTap: _pickColor,
                    ),
                  ],
                ),

                // 5. Section: การจัดการ (ถ้าอยู่ในโหมดแก้ไข)
                if (_isEditing) ...[
                  AppSectionHeader('การจัดการ'),
                  AppInsetCard(
                    children: [
                      buildBudgetDeleteRow(
                        onDelete: _delete,
                        isDarkMode: isDark,
                        surfaceColor: surfaceColor,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Helper Widgets ─────────────────────────────────────────────────────────

  Widget _buildAmountInputRow({
    required Color surfaceColor,
    required Color textPrimaryColor,
    required Color textSecondaryColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: textSecondaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadii.medium),
            ),
            child: Icon(
              Icons.payments_outlined,
              color: textSecondaryColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'จำนวนงบ',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: textPrimaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _amountController,
              focusNode: _amountFocusNode,
              readOnly: calculatorTextFieldReadOnly,
              showCursor: true,
              keyboardType: calculatorTextInputType,
              inputFormatters: calculatorTextInputFormatters,
              textAlign: TextAlign.right,
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: '0.00',
                hintStyle: TextStyle(
                  color: textSecondaryColor.withValues(alpha: 0.5),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                hintTextDirection: TextDirection.rtl,
                suffixText: ' บาท',
                suffixStyle: TextStyle(
                  color: textSecondaryColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
              ),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textPrimaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelectorRow({
    required Color surfaceColor,
    required Color textPrimaryColor,
    required Color textSecondaryColor,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: textSecondaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadii.medium),
            ),
            child: Icon(
              Icons.donut_large_outlined,
              color: textSecondaryColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'ประเภท',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: textPrimaryColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: AppSegmentedTabs(
              segments: [
                AppSegment(
                  label: 'รายจ่าย',
                  isSelected: _selectedType == BudgetType.expense,
                  onTap: () =>
                      setState(() => _selectedType = BudgetType.expense),
                ),
                AppSegment(
                  label: 'เงินออม',
                  isSelected: _selectedType == BudgetType.savings,
                  onTap: () =>
                      setState(() => _selectedType = BudgetType.savings),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Modal Bottom Sheets ───────────────────────────────────────────────────

  Future<void> _pickIcon() async {
    final icon = await showIconPickerSheet(
      context: context,
      title: 'เลือกไอคอนงบประมาณ',
      selectedIcon: _selectedIcon,
      accentColor: _selectedColor,
    );
    if (icon == null || !mounted) return;
    setState(() => _selectedIcon = icon);
  }

  Future<void> _pickColor() async {
    final color = await showColorPickerSheet(
      context: context,
      title: 'เลือกสีประจำงบประมาณ',
      selectedColor: _selectedColor,
    );
    if (color == null || !mounted) return;
    setState(() => _selectedColor = color);
  }
}
