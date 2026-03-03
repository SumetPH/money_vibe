import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/budget.dart';
import '../../models/category.dart';
import '../../providers/budget_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';

class BudgetFormScreen extends StatefulWidget {
  final Budget? budget;

  const BudgetFormScreen({super.key, this.budget});

  @override
  State<BudgetFormScreen> createState() => _BudgetFormScreenState();
}

class _BudgetFormScreenState extends State<BudgetFormScreen> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();

  late IconData _selectedIcon;
  late Color _selectedColor;
  late Set<String> _selectedCategoryIds;

  bool get _isEditing => widget.budget != null;

  @override
  void initState() {
    super.initState();
    final b = widget.budget;
    _nameController.text = b?.name ?? '';
    _amountController.text = b != null && b.amount > 0
        ? b.amount.toStringAsFixed(2)
        : '';
    _selectedIcon = b?.icon ?? Icons.savings;
    _selectedColor = b?.color ?? AppColors.accountColors.first;
    _selectedCategoryIds = Set<String>.from(b?.categoryIds ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณากรอกชื่องบประมาณ')));
      return;
    }
    final rawAmount = _amountController.text.replaceAll(',', '').trim();
    final amount = double.tryParse(rawAmount) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณากรอกจำนวนเงิน')));
      return;
    }

    final provider = context.read<BudgetProvider>();
    if (_isEditing) {
      provider.updateBudget(
        widget.budget!.copyWith(
          name: name,
          amount: amount,
          categoryIds: _selectedCategoryIds.toList(),
          icon: _selectedIcon,
          color: _selectedColor,
        ),
      );
    } else {
      provider.addBudget(
        Budget(
          id: provider.generateId(),
          name: name,
          amount: amount,
          categoryIds: _selectedCategoryIds.toList(),
          icon: _selectedIcon,
          color: _selectedColor,
        ),
      );
    }
    Navigator.pop(context);
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
                onPressed: () {
                  context.read<BudgetProvider>().deleteBudget(
                    widget.budget!.id,
                  );
                  Navigator.pop(context);
                  Navigator.pop(context);
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
    return Consumer2<CategoryProvider, SettingsProvider>(
      builder: (context, catProvider, sp, _) {
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
          backgroundColor: bgColor,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(_isEditing ? 'แก้ไขงบประมาณ' : 'เพิ่มงบประมาณ'),
            actions: [
              if (_isEditing)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _delete,
                ),
              IconButton(icon: const Icon(Icons.check), onPressed: _save),
            ],
          ),
          body: ListView(
            children: [
              const SizedBox(height: 8),
              // Name
              Container(
                color: surfaceColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'ชื่องบประมาณ',
                    hintStyle: TextStyle(color: textSecondary),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  style: TextStyle(fontSize: 15, color: textPrimary),
                ),
              ),
              Divider(height: 1, indent: 16, color: dividerColor),
              // Amount
              Container(
                color: surfaceColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: InputDecoration(
                    hintText: 'จำนวนเงินงบประมาณ',
                    hintStyle: TextStyle(color: textSecondary),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    suffixText: 'บาท',
                    suffixStyle: TextStyle(color: textSecondary, fontSize: 14),
                  ),
                  style: TextStyle(fontSize: 15, color: textPrimary),
                ),
              ),
              const SizedBox(height: 8),
              // Categories
              InkWell(
                onTap: () =>
                    _pickCategories(context, expenseCategories, isDark),
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
                        style: TextStyle(fontSize: 15, color: textSecondary),
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
                                  fontSize: 14,
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
              Divider(height: 1, indent: 16, color: dividerColor),
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
                        style: TextStyle(fontSize: 15, color: textSecondary),
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
                      Icon(Icons.chevron_right, color: textSecondary, size: 18),
                    ],
                  ),
                ),
              ),
              Divider(height: 1, indent: 16, color: dividerColor),
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
                        style: TextStyle(fontSize: 15, color: textSecondary),
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
                      Icon(Icons.chevron_right, color: textSecondary, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  void _pickCategories(
    BuildContext context,
    List<Category> categories,
    bool isDark,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          final bgColor = isDark ? AppColors.darkSurface : Colors.white;
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
                const SizedBox(height: 4),
                Divider(color: dividerColor),
                Expanded(
                  child: ListView.builder(
                    controller: sc,
                    itemCount: categories.length,
                    itemBuilder: (_, i) {
                      final cat = categories[i];
                      final isSelected = _selectedCategoryIds.contains(cat.id);
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
                        title: Text(
                          cat.name,
                          style: TextStyle(color: textColor),
                        ),
                        trailing: Icon(
                          isSelected
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          color: isSelected ? selectedColor : dividerColor,
                        ),
                        onTap: () {
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
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedIcon = icon);
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: selected
                              ? _selectedColor.withValues(alpha: 0.15)
                              : bgColor,
                          borderRadius: BorderRadius.circular(10),
                          border: selected
                              ? Border.all(color: _selectedColor, width: 2)
                              : null,
                        ),
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
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedColor = color);
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(10),
                          border: selected
                              ? Border.all(color: Colors.black45, width: 2)
                              : null,
                        ),
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
