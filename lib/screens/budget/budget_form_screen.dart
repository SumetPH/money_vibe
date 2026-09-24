import 'package:flutter/cupertino.dart' show CupertinoSwitch;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/budget.dart';
import '../../models/category.dart';
import '../../providers/budget_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../main.dart';
import '../../widgets/app_modal_bottom_sheet.dart';
import '../../widgets/calculator_keyboard.dart';
import '../../widgets/calculator_text_field_config.dart';

class BudgetFormScreen extends StatefulWidget {
  final Budget? budget;

  const BudgetFormScreen({super.key, this.budget});

  @override
  State<BudgetFormScreen> createState() => _BudgetFormScreenState();
}

class _BudgetFormScreenState extends State<BudgetFormScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _amountFocusNode = FocusNode();
  PersistentBottomSheetController? _keyboardController;
  TextEditingController? _activeKeyboardController;
  bool _isUpdatingController = false;

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
    _groupController.dispose();
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

  String _buildBudgetConflictMessage(
    BudgetCategoryConflictException error,
    CategoryProvider categoryProvider,
  ) {
    final categoryName =
        categoryProvider.findById(error.categoryId)?.name ?? 'หมวดหมู่นี้';
    return '$categoryName ใช้อยู่ในงบ "${error.budgetName}" แล้ว';
  }

  Future<bool> _confirmCategoryTransfer(
    BuildContext context, {
    required Category category,
    required Budget sourceBudget,
    required bool isDark,
  }) async {
    final editedName = _nameController.text.trim();
    final targetBudgetName = editedName.isNotEmpty
        ? editedName
        : widget.budget?.name ?? 'งบปัจจุบัน';
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;

    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.xLarge),
            ),
            title: Text(
              'ย้ายหมวดหมู่',
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Text(
              'หมวดหมู่ "${category.name}" ใช้อยู่ในงบ '
              '"${sourceBudget.name}"\n\n'
              'หากยืนยัน หมวดหมู่นี้จะถูกย้ายมาอยู่ในงบ '
              '"$targetBudgetName" เมื่อบันทึก',
              style: TextStyle(color: textSecondary, fontSize: 14),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text('ยกเลิก', style: TextStyle(color: textSecondary)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: isDark
                      ? AppColors.darkIncome
                      : AppColors.income,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.full),
                  ),
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('ย้ายมา'),
              ),
            ],
          ),
        ) ??
        false;
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
        _closeKeyboard();
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

  void _delete() {
    final settingsProvider = context.read<SettingsProvider>();
    final isDarkMode = settingsProvider.isDarkMode;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final textSecondary = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDarkMode ? AppColors.darkSurface : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xLarge),
        ),
        title: Text(
          'ลบงบประมาณ',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'คุณต้องการลบงบประมาณ "${widget.budget?.name}" ใช่หรือไม่? รายการธุรกรรมเดิมจะไม่ได้รับผลกระทบ',
          style: TextStyle(color: textSecondary, fontSize: 14),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ยกเลิก', style: TextStyle(color: textSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: isDarkMode
                  ? AppColors.darkExpense
                  : AppColors.expense,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.full),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            ),
            onPressed: () async {
              final provider = context.read<BudgetProvider>();
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              setState(() => _isLoading = true);
              try {
                await provider.deleteBudget(widget.budget!.id);
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
            },
            child: const Text(
              'ลบงบประมาณ',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
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
        final incomeColor = isDark ? AppColors.darkIncome : AppColors.income;

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
            leading: Center(
              child: Material(
                color: surfaceColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.full),
                  side: BorderSide(
                    color: isDark
                        ? AppColors.darkDivider.withValues(alpha: 0.4)
                        : AppColors.divider.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: textPrimaryColor,
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
              _isEditing ? 'แก้ไขงบประมาณ' : 'เพิ่มงบประมาณใหม่',
              style: TextStyle(
                color: textPrimaryColor,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            actions: [
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
                                    Icons.check_rounded,
                                    size: 16,
                                    color: Colors.black,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'บันทึก',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
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
          body: AbsorbPointer(
            absorbing: _isLoading,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
              children: [
                // 1. Live Budget Preview Hero Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildLivePreviewCard(
                    surfaceColor: surfaceColor,
                    dividerColor: dividerColor,
                    textPrimaryColor: textPrimaryColor,
                    textSecondaryColor: textSecondaryColor,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(height: 12),

                // 2. Section: ข้อมูลทั่วไป
                _buildSectionHeader('ข้อมูลทั่วไป', textSecondaryColor),
                _buildInsetCard(
                  [
                    _buildInputFieldRow(
                      icon: Icons.edit_note_rounded,
                      label: 'ชื่อ',
                      hintText: 'ชื่องบประมาณ',
                      controller: _nameController,
                      textPrimaryColor: textPrimaryColor,
                      textSecondaryColor: textSecondaryColor,
                      onChanged: (_) => setState(() {}),
                    ),
                    _buildIndentedDivider(dividerColor),
                    _buildInputFieldRow(
                      icon: Icons.folder_outlined,
                      label: 'กลุ่ม',
                      hintText: 'ชื่อกลุ่ม (ไม่บังคับ)',
                      controller: _groupController,
                      textPrimaryColor: textPrimaryColor,
                      textSecondaryColor: textSecondaryColor,
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                  surfaceColor: surfaceColor,
                  dividerColor: dividerColor,
                ),

                // 3. Section: จำนวนเงินและประเภท
                _buildSectionHeader('จำนวนเงินและประเภท', textSecondaryColor),
                _buildInsetCard(
                  [
                    // Amount Input Box
                    _buildAmountInputRow(
                      surfaceColor: surfaceColor,
                      textPrimaryColor: textPrimaryColor,
                      textSecondaryColor: textSecondaryColor,
                      isDark: isDark,
                    ),
                    _buildIndentedDivider(dividerColor),
                    // Type Selector
                    _buildTypeSelectorRow(
                      surfaceColor: surfaceColor,
                      textPrimaryColor: textPrimaryColor,
                      textSecondaryColor: textSecondaryColor,
                      isDark: isDark,
                    ),
                    // Categories picker (Only if expense type)
                    if (_selectedType == BudgetType.expense) ...[
                      _buildIndentedDivider(dividerColor),
                      _buildPickerRow(
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
                    _buildIndentedDivider(dividerColor),
                    // Hide Budget Switch (CupertinoSwitch)
                    _buildSwitchRow(
                      icon: Icons.visibility_off_outlined,
                      title: 'ซ่อนงบประมาณนี้',
                      subtitle: 'ไม่แสดงในหน้ารวมงบประมาณหลัก',
                      value: _isHidden,
                      activeTrackColor: incomeColor,
                      isDark: isDark,
                      textColor: textPrimaryColor,
                      textSecondary: textSecondaryColor,
                      onChanged: (val) => setState(() => _isHidden = val),
                    ),
                  ],
                  surfaceColor: surfaceColor,
                  dividerColor: dividerColor,
                ),

                // 4. Section: รูปลักษณ์
                _buildSectionHeader('รูปลักษณ์', textSecondaryColor),
                _buildInsetCard(
                  [
                    _buildIconPickerRow(
                      surfaceColor: surfaceColor,
                      textPrimaryColor: textPrimaryColor,
                      textSecondaryColor: textSecondaryColor,
                      isDark: isDark,
                    ),
                    _buildIndentedDivider(dividerColor),
                    _buildColorPickerRow(
                      surfaceColor: surfaceColor,
                      textPrimaryColor: textPrimaryColor,
                      textSecondaryColor: textSecondaryColor,
                      isDark: isDark,
                    ),
                  ],
                  surfaceColor: surfaceColor,
                  dividerColor: dividerColor,
                ),

                // 5. Section: การจัดการ (ถ้าอยู่ในโหมดแก้ไข)
                if (_isEditing) ...[
                  _buildSectionHeader('การจัดการ', textSecondaryColor),
                  _buildInsetCard(
                    [
                      _buildDeleteRow(
                        isDarkMode: isDark,
                        surfaceColor: surfaceColor,
                      ),
                    ],
                    surfaceColor: surfaceColor,
                    dividerColor: dividerColor,
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

  Widget _buildSectionHeader(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, top: 16, bottom: 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildInsetCard(
    List<Widget> children, {
    required Color surfaceColor,
    required Color dividerColor,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.xLarge),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(AppRadii.xLarge),
          border: Border.all(
            color: dividerColor.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }

  Widget _buildIndentedDivider(Color color) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 60,
      endIndent: 16,
      color: color.withValues(alpha: 0.3),
    );
  }

  Widget _buildLivePreviewCard({
    required Color surfaceColor,
    required Color dividerColor,
    required Color textPrimaryColor,
    required Color textSecondaryColor,
    required bool isDark,
  }) {
    final name = _nameController.text.trim();
    final displayName = name.isEmpty ? 'ตัวอย่างชื่องบประมาณ' : name;
    final group = _groupController.text.trim();
    final amountText = _amountController.text.trim();
    final isExpense = _selectedType == BudgetType.expense;
    final typeBadgeColor = isExpense
        ? (isDark ? AppColors.darkExpense : AppColors.expense)
        : (isDark ? AppColors.darkIncome : AppColors.income);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppRadii.xLarge),
        border: Border.all(
          color: dividerColor.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Icon Box
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _selectedColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadii.medium),
            ),
            child: Icon(_selectedIcon, color: _selectedColor, size: 26),
          ),
          const SizedBox(width: 14),

          // Name and Group
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: name.isEmpty
                        ? textSecondaryColor.withValues(alpha: 0.6)
                        : textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  group.isNotEmpty ? 'กลุ่ม: $group' : 'ไม่มีกลุ่ม',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),

          // Amount & Type Capsule
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: typeBadgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadii.full),
                ),
                child: Text(
                  isExpense ? 'รายจ่าย' : 'เงินออม',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: typeBadgeColor,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                amountText.isNotEmpty ? '฿$amountText' : '฿0.00',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textPrimaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputFieldRow({
    required IconData icon,
    required String label,
    required String hintText,
    required TextEditingController controller,
    required Color textPrimaryColor,
    required Color textSecondaryColor,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: textSecondaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadii.medium),
            ),
            child: Icon(icon, color: textSecondaryColor, size: 18),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 70,
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
              onChanged: onChanged,
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(
                  color: textSecondaryColor.withValues(alpha: 0.55),
                  fontSize: 14,
                ),
                hintTextDirection: TextDirection.rtl,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(AppRadii.large),
            ),
            child: Row(
              children: [
                _buildSegmentButton(
                  type: BudgetType.expense,
                  title: 'รายจ่าย',
                  isSelected: _selectedType == BudgetType.expense,
                  isDark: isDark,
                  accentColor: isDark
                      ? AppColors.darkExpense
                      : AppColors.expense,
                ),
                _buildSegmentButton(
                  type: BudgetType.savings,
                  title: 'เงินออม',
                  isSelected: _selectedType == BudgetType.savings,
                  isDark: isDark,
                  accentColor: isDark ? AppColors.darkIncome : AppColors.income,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required BudgetType type,
    required String title,
    required bool isSelected,
    required bool isDark,
    required Color accentColor,
  }) {
    return InkWell(
      onTap: () => setState(() => _selectedType = type),
      borderRadius: BorderRadius.circular(AppRadii.medium),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.darkSurfaceVariant : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.medium),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? accentColor
                    : accentColor.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? (isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary)
                    : (isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerRow({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
    required Color surfaceColor,
    required Color textPrimaryColor,
    required Color textSecondaryColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: textSecondaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadii.medium),
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
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: textSecondaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: textSecondaryColor.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Color activeTrackColor,
    required bool isDark,
    required Color textColor,
    required Color textSecondary,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: textSecondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadii.medium),
            ),
            child: Icon(icon, color: textSecondary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
              ],
            ),
          ),
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

  Widget _buildIconPickerRow({
    required Color surfaceColor,
    required Color textPrimaryColor,
    required Color textSecondaryColor,
    required bool isDark,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.xLarge),
      onTap: () => _pickIcon(isDark),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _selectedColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadii.medium),
              ),
              child: Icon(_selectedIcon, color: _selectedColor, size: 18),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ไอคอน',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'เลือกไอคอนสำหรับงบประมาณ',
                  style: TextStyle(fontSize: 12, color: textSecondaryColor),
                ),
              ],
            ),
            const Spacer(),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _selectedColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadii.medium),
                border: Border.all(
                  color: _selectedColor.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Icon(_selectedIcon, color: _selectedColor, size: 20),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: textSecondaryColor.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorPickerRow({
    required Color surfaceColor,
    required Color textPrimaryColor,
    required Color textSecondaryColor,
    required bool isDark,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.xLarge),
      onTap: () => _pickColor(isDark),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _selectedColor,
                borderRadius: BorderRadius.circular(AppRadii.medium),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'สีประจำงบประมาณ',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'เลือกโทนสีเพื่อการแยกแยะ',
                  style: TextStyle(fontSize: 12, color: textSecondaryColor),
                ),
              ],
            ),
            const Spacer(),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _selectedColor,
                borderRadius: BorderRadius.circular(AppRadii.medium),
                border: Border.all(
                  color: (isDark ? Colors.white : Colors.black).withValues(
                    alpha: 0.2,
                  ),
                  width: 1.5,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: textSecondaryColor.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteRow({
    required bool isDarkMode,
    required Color surfaceColor,
  }) {
    final deleteColor = isDarkMode ? AppColors.darkExpense : AppColors.expense;

    return InkWell(
      onTap: _delete,
      borderRadius: BorderRadius.circular(AppRadii.xLarge),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: deleteColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadii.xLarge),
              ),
              child: Icon(
                Icons.delete_outline_rounded,
                color: deleteColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'ลบงบประมาณนี้',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: deleteColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Modal Bottom Sheets ───────────────────────────────────────────────────

  void _pickCategories(
    BuildContext context,
    List<Category> categories,
    BudgetProvider budgetProvider,
    bool isDark,
  ) {
    final assignedBudgets = budgetProvider.expenseCategoryBudgetMap(
      excludingBudgetId: widget.budget?.id,
    );

    showAppModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          final textColor = isDark
              ? AppColors.darkTextPrimary
              : AppColors.textPrimary;
          final textSecondary = isDark
              ? AppColors.darkTextSecondary
              : AppColors.textSecondary;
          final dividerColor = isDark
              ? AppColors.darkDivider
              : AppColors.divider;
          final selectedColor = isDark
              ? AppColors.darkIncome
              : AppColors.income;

          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder: (_, sc) => Column(
              children: [
                const AppModalBottomSheetHeader(title: 'เลือกหมวดหมู่รายจ่าย'),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'เลือกหมวดหมู่ที่ต้องการนับรวมในงบนี้',
                        style: TextStyle(fontSize: 13, color: textSecondary),
                      ),
                      const Spacer(),
                      Text(
                        'เลือกแล้ว ${_selectedCategoryIds.length}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selectedColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: ListView.separated(
                    controller: sc,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: categories.length,
                    separatorBuilder: (context, i) => Divider(
                      height: 1,
                      color: AppColors.listDividerFor(isDark),
                    ),
                    itemBuilder: (_, i) {
                      final cat = categories[i];
                      final isSelected = _selectedCategoryIds.contains(cat.id);
                      final assignedBudget = assignedBudgets[cat.id];

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        leading: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: cat.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(
                              AppRadii.medium,
                            ),
                          ),
                          child: Icon(cat.icon, color: cat.color, size: 20),
                        ),
                        title: Text(
                          cat.name,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: assignedBudget == null
                            ? null
                            : Text(
                                isSelected
                                    ? 'จะย้ายมาจากงบ: ${assignedBudget.name}'
                                    : 'ใช้อยู่ในงบ: ${assignedBudget.name}',
                                style: TextStyle(
                                  color: isSelected
                                      ? (isDark
                                            ? AppColors.darkIncome
                                            : AppColors.income)
                                      : textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                        trailing: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? selectedColor
                                : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? selectedColor
                                  : dividerColor.withValues(alpha: 0.8),
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 16,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        onTap: () async {
                          if (!isSelected && assignedBudget != null) {
                            final confirmed = await _confirmCategoryTransfer(
                              context,
                              category: cat,
                              sourceBudget: assignedBudget,
                              isDark: isDark,
                            );
                            if (!confirmed || !mounted) return;
                          }

                          setModalState(() {
                            if (isSelected) {
                              _selectedCategoryIds.remove(cat.id);
                            } else {
                              _selectedCategoryIds.add(cat.id);
                            }
                          });
                          setState(() {});
                        },
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: isDark
                              ? AppColors.darkFabYellow
                              : AppColors.fabYellow,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadii.full),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'เสร็จสิ้น',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _pickIcon(bool isDark) {
    showAppModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        final textSecondary = isDark
            ? AppColors.darkTextSecondary
            : AppColors.textSecondary;

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppModalBottomSheetHeader(title: 'เลือกไอคอนงบประมาณ'),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: AppColors.accountIcons.length,
                  itemBuilder: (_, i) {
                    final icon = AppColors.accountIcons[i];
                    final selected = icon == _selectedIcon;
                    return InkWell(
                      onTap: () {
                        setState(() => _selectedIcon = icon);
                        Navigator.pop(context);
                      },
                      child: Icon(
                        icon,
                        color: selected ? _selectedColor : textSecondary,
                        size: 24,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _pickColor(bool isDark) {
    showAppModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppModalBottomSheetHeader(title: 'เลือกสีประจำงบประมาณ'),
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
                        borderRadius: BorderRadius.circular(AppRadii.large),
                        side: selected
                            ? const BorderSide(color: Colors.white, width: 2.5)
                            : BorderSide.none,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          setState(() => _selectedColor = color);
                          Navigator.pop(context);
                        },
                        child: selected
                            ? Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.large,
                                  ),
                                  color: Colors.black.withValues(alpha: 0.2),
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
