import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/budget.dart';
import '../../models/category.dart';
import '../../providers/budget_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../main.dart';
import '../../widgets/app_bar_action_button.dart';
import '../../widgets/calculator_keyboard.dart';

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
  bool _isLoading = false;

  bool get _isEditing => widget.budget != null;

  @override
  void initState() {
    super.initState();
    final b = widget.budget;
    _nameController.text = b?.name ?? '';
    _amountController.text = b != null ? formatAmount(b.amount) : '';
    _groupController.text = b?.groupName ?? '';
    _selectedIcon = b?.icon ?? Icons.savings;
    _selectedColor = b?.color ?? AppColors.accountColors.first;
    _selectedCategoryIds = Set<String>.from(b?.categoryIds ?? []);
    _selectedType = b?.type ?? BudgetType.expense;

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

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณากรอกชื่องบประมาณ')));
      return;
    }
    final rawAmount = _amountController.text.replaceAll(',', '').trim();
    final amount = double.tryParse(rawAmount) ?? -1;
    if (amount < 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณากรอกจำนวนเงิน')));
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
        await provider.updateBudget(
          widget.budget!.copyWith(
            name: name,
            amount: amount,
            categoryIds: _selectedCategoryIds.toList(),
            icon: _selectedIcon,
            color: _selectedColor,
            groupName: groupName,
            clearGroupName: groupName == null,
            type: _selectedType,
          ),
        );
      } else {
        await provider.addBudget(
          Budget(
            id: provider.generateId(),
            name: name,
            amount: amount,
            categoryIds: _selectedCategoryIds.toList(),
            icon: _selectedIcon,
            color: _selectedColor,
            groupName: groupName,
            type: _selectedType,
          ),
        );
      }
      if (mounted) {
        _closeKeyboard();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        final message = e is BudgetCategoryConflictException
            ? _buildBudgetConflictMessage(e, categoryProvider)
            : 'เกิดข้อผิดพลาดในการบันทึก: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message, style: const TextStyle(color: Colors.white)),
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
    showDialog(
      context: context,
      builder: (_) => Consumer<SettingsProvider>(
        builder: (context, sp, _) {
          final isDark = sp.isDarkMode;
          return AlertDialog(
            backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
            title: Text(
              'ลบงบประมาณ',
              style: TextStyle(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
            ),
            content: Text(
              'คุณต้องการลบงบประมาณนี้ใช่หรือไม่?',
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
    return Consumer3<CategoryProvider, BudgetProvider, SettingsProvider>(
      builder: (context, catProvider, budgetProvider, sp, _) {
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
        final dividerColor = isDark ? AppColors.darkDivider : AppColors.divider;

        final expenseCategories = catProvider.categoriesOfType(
          CategoryType.expense,
        );
        final selectedNames = expenseCategories
            .where((c) => _selectedCategoryIds.contains(c.id))
            .map((c) => c.name)
            .toList();
        final categoryLabel = _selectedCategoryIds.isEmpty
            ? 'ไม่ได้เลือก'
            : selectedNames.isEmpty
            ? '${_selectedCategoryIds.length} หมวดหมู่'
            : selectedNames.join(', ');

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: bgColor,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: _isLoading
                  ? null
                  : () {
                      _closeKeyboard();
                      Navigator.pop(context);
                    },
            ),
            title: Text(_isEditing ? 'แก้ไขงบประมาณ' : 'เพิ่มงบประมาณ'),
            actions: [
              if (_isEditing)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _isLoading ? null : _delete,
                ),
              AppBarActionButton(
                icon: const Icon(Icons.check),
                tooltip: 'บันทึก',
                isLoading: _isLoading,
                onPressed: _save,
              ),
            ],
          ),
          body: AbsorbPointer(
            absorbing: _isLoading,
            child: ListView(
              children: [
                const SizedBox(height: 8),
                // Name
                Container(
                  color: surfaceColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'ชื่อ',
                        style: TextStyle(fontSize: 16, color: textSecondary),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          textAlign: TextAlign.right,
                          decoration: InputDecoration(
                            hintText: 'ชื่องบประมาณ',
                            hintStyle: TextStyle(color: textSecondary),
                            hintTextDirection: TextDirection.rtl,
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
                Divider(height: 1, color: dividerColor),
                // Group Name
                Container(
                  color: surfaceColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'กลุ่ม',
                        style: TextStyle(fontSize: 16, color: textSecondary),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _groupController,
                          textAlign: TextAlign.right,
                          decoration: InputDecoration(
                            hintText: 'ชื่อกลุ่ม (ไม่บังคับ)',
                            hintStyle: TextStyle(color: textSecondary),
                            hintTextDirection: TextDirection.rtl,
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
                Divider(height: 1, color: dividerColor),
                // Amount
                Container(
                  color: surfaceColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'จำนวน',
                        style: TextStyle(fontSize: 16, color: textSecondary),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _amountController,
                          focusNode: _amountFocusNode,
                          readOnly: true,
                          showCursor: true,
                          textAlign: TextAlign.right,
                          decoration: InputDecoration(
                            hintText: '0.00',
                            hintStyle: TextStyle(color: textSecondary),
                            hintTextDirection: TextDirection.rtl,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                            suffixText: 'บาท',
                            suffixStyle: TextStyle(
                              color: textSecondary,
                              fontSize: 15,
                            ),
                          ),
                          style: TextStyle(fontSize: 16, color: textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Type selector
                Container(
                  color: surfaceColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'ประเภท',
                        style: TextStyle(fontSize: 16, color: textSecondary),
                      ),
                      const Spacer(),
                      ...BudgetType.values.map((t) {
                        final isSelected = _selectedType == t;
                        final accentColor = isDark
                            ? AppColors.darkHeader
                            : AppColors.header;
                        return Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Material(
                            color: isSelected
                                ? accentColor
                                : accentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => setState(() => _selectedType = t),
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                child: Text(
                                  t.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white
                                        : accentColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                Divider(height: 1, color: dividerColor),
                // Categories (shown only for expense type)
                if (_selectedType == BudgetType.expense) ...[
                  InkWell(
                    onTap: () => _pickCategories(
                      context,
                      expenseCategories,
                      budgetProvider,
                      isDark,
                    ),
                    child: Container(
                      color: surfaceColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Text(
                            'หมวดหมู่',
                            style: TextStyle(
                              fontSize: 16,
                              color: textSecondary,
                            ),
                          ),
                          SizedBox(width: 20),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Flexible(
                                  child: Text(
                                    categoryLabel,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    textAlign: TextAlign.end,
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
                        ],
                      ),
                    ),
                  ),
                  Divider(height: 1, color: dividerColor),
                ], // end if expense
                // Icon
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
                          style: TextStyle(fontSize: 16, color: textSecondary),
                        ),
                        const Spacer(),
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _selectedColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _selectedIcon,
                            color: _selectedColor,
                            size: 26,
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
                // Color
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
                          style: TextStyle(fontSize: 16, color: textSecondary),
                        ),
                        const Spacer(),
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _selectedColor,
                            borderRadius: BorderRadius.circular(10),
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
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  void _pickCategories(
    BuildContext context,
    List<Category> categories,
    BudgetProvider budgetProvider,
    bool isDark,
  ) {
    final assignedBudgets = budgetProvider.expenseCategoryBudgetMap(
      excludingBudgetId: widget.budget?.id,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          final handleColor = isDark
              ? AppColors.darkDivider
              : Colors.grey.shade300;
          final textColor = isDark
              ? AppColors.darkTextPrimary
              : AppColors.textPrimary;
          final dividerColor = isDark
              ? AppColors.darkDivider
              : AppColors.divider;
          final selectedColor = isDark
              ? AppColors.darkIncome
              : AppColors.header;

          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder: (_, sc) => Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: handleColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'เลือกหมวดหมู่',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 12),
                Divider(color: dividerColor),
                Expanded(
                  child: ListView.separated(
                    controller: sc,
                    itemCount: categories.length,
                    separatorBuilder: (context, i) =>
                        Divider(height: 1, color: dividerColor),
                    itemBuilder: (_, i) {
                      final cat = categories[i];
                      final isSelected = _selectedCategoryIds.contains(cat.id);
                      final assignedBudget = assignedBudgets[cat.id];
                      final isDisabled = assignedBudget != null && !isSelected;
                      final itemTextColor = isDisabled
                          ? textColor.withValues(alpha: 0.5)
                          : textColor;
                      final subtitleColor = isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary;
                      return ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: cat.color.withValues(
                              alpha: isDisabled ? 0.08 : 0.15,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            cat.icon,
                            color: isDisabled
                                ? cat.color.withValues(alpha: 0.45)
                                : cat.color,
                            size: 18,
                          ),
                        ),
                        title: Text(
                          cat.name,
                          style: TextStyle(color: itemTextColor),
                        ),
                        subtitle: assignedBudget == null
                            ? null
                            : Text(
                                'ใช้อยู่ในงบ: ${assignedBudget.name}',
                                style: TextStyle(
                                  color: isDisabled
                                      ? subtitleColor.withValues(alpha: 0.7)
                                      : subtitleColor,
                                ),
                              ),
                        trailing: Icon(
                          isSelected
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          color: isSelected
                              ? selectedColor
                              : isDisabled
                              ? dividerColor.withValues(alpha: 0.65)
                              : dividerColor,
                        ),
                        enabled: !isDisabled,
                        onTap: isDisabled
                            ? null
                            : () {
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
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('เสร็จสิ้น'),
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
    showModalBottomSheet(
      context: context,
      builder: (_) {
        final bgColor = isDark
            ? AppColors.darkBackground
            : AppColors.background;
        final textPrimary = isDark
            ? AppColors.darkTextPrimary
            : AppColors.textPrimary;
        final textSecondary = isDark
            ? AppColors.darkTextSecondary
            : AppColors.textSecondary;

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'เลือกไอคอน',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: textPrimary,
                  ),
                ),
              ),
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
                    return Material(
                      color: selected
                          ? _selectedColor.withValues(alpha: 0.15)
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
                          setState(() => _selectedIcon = icon);
                          Navigator.pop(context);
                        },
                        child: Icon(
                          icon,
                          color: selected ? _selectedColor : textSecondary,
                          size: 24,
                        ),
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
    showModalBottomSheet(
      context: context,
      builder: (_) {
        final textPrimary = isDark
            ? AppColors.darkTextPrimary
            : AppColors.textPrimary;

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'เลือกสี',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: textPrimary,
                  ),
                ),
              ),
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
        );
      },
    );
  }
}
