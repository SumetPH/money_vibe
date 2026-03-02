import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/category.dart';
import '../../providers/category_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';

class CategoryFormScreen extends StatefulWidget {
  final Category? category;
  final CategoryType initialType;

  const CategoryFormScreen({
    super.key,
    this.category,
    this.initialType = CategoryType.expense,
  });

  @override
  State<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends State<CategoryFormScreen> {
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();

  late CategoryType _type;
  late IconData _selectedIcon;
  late Color _selectedColor;
  String? _parentId;

  bool get _isEditing => widget.category != null;

  @override
  void initState() {
    super.initState();
    final cat = widget.category;
    _type = cat?.type ?? widget.initialType;
    _nameController.text = cat?.name ?? '';
    _noteController.text = cat?.note ?? '';
    _selectedIcon = cat?.icon ?? Icons.category;
    _selectedColor = cat?.color ?? AppColors.accountColors.first;
    _parentId = cat?.parentId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณากรอกชื่อหมวดหมู่')));
      return;
    }

    final provider = context.read<CategoryProvider>();

    if (_isEditing) {
      provider.updateCategory(
        widget.category!.copyWith(
          name: name,
          icon: _selectedIcon,
          color: _selectedColor,
          parentId: _parentId,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
          clearParent: _parentId == null,
          clearNote: _noteController.text.trim().isEmpty,
        ),
      );
    } else {
      provider.addCategory(
        Category(
          id: provider.generateId(),
          name: name,
          icon: _selectedIcon,
          color: _selectedColor,
          type: _type,
          parentId: _parentId,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        ),
      );
    }

    Navigator.pop(context);
  }

  void _delete() {
    showDialog(
      context: context,
      builder: (_) => Consumer<SettingsProvider>(
        builder: (context, settingsProvider, _) {
          final isDarkMode = settingsProvider.isDarkMode;
          final dialogBgColor = isDarkMode ? AppColors.darkSurface : Colors.white;
          final textColor = isDarkMode ? AppColors.darkTextPrimary : AppColors.textPrimary;

          return AlertDialog(
            backgroundColor: dialogBgColor,
            title: Text('ลบหมวดหมู่', style: TextStyle(color: textColor)),
            content: Text('คุณต้องการที่จะลบหมวดหมู่นี้ใช่หรือไม่?', style: TextStyle(color: textColor)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('ยกเลิก', style: TextStyle(color: textColor)),
              ),
              TextButton(
                onPressed: () {
                  context.read<CategoryProvider>().deleteCategory(
                    widget.category!.id,
                  );
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                style: TextButton.styleFrom(
                  foregroundColor: isDarkMode ? AppColors.darkExpense : AppColors.expense,
                ),
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
      builder: (context, catProvider, settingsProvider, _) {
        final isDarkMode = settingsProvider.isDarkMode;
        final bgColor = isDarkMode ? AppColors.darkBackground : AppColors.background;
        final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
        final textPrimaryColor = isDarkMode ? AppColors.darkTextPrimary : AppColors.textPrimary;
        final textSecondaryColor = isDarkMode ? AppColors.darkTextSecondary : AppColors.textSecondary;
        final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;

        final parentCandidates = catProvider
            .mainCategoriesOfType(_type)
            .where((c) => c.id != widget.category?.id)
            .toList();
        final parentCategory = _parentId != null
            ? catProvider.findById(_parentId!)
            : null;

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(_isEditing ? 'แก้ไขหมวดหมู่' : 'เพิ่มหมวดหมู่ใหม่'),
            actions: [
              if (_isEditing)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _delete,
                  tooltip: 'ลบหมวดหมู่',
                ),
              IconButton(icon: const Icon(Icons.check), onPressed: _save),
            ],
          ),
          body: ListView(
            children: [
              const SizedBox(height: 8),
              // Name
              _buildTextField(controller: _nameController, hintText: 'ชื่อ', surfaceColor: surfaceColor, textSecondaryColor: textSecondaryColor),
              _buildDivider(color: dividerColor),
              // Parent category
              _buildPickerRow(
                label: 'เป็นหมวดหมู่ย่อยของ',
                value: parentCategory?.name ?? '(หมวดหมู่หลัก)',
                onTap: () => _pickParent(context, parentCandidates),
                surfaceColor: surfaceColor,
                textPrimaryColor: textPrimaryColor,
                textSecondaryColor: textSecondaryColor,
              ),
              _buildDivider(color: dividerColor),
              // Icon
              _buildIconRow(surfaceColor: surfaceColor, textSecondaryColor: textSecondaryColor),
              _buildDivider(color: dividerColor),
              // Color
              _buildColorRow(surfaceColor: surfaceColor, textSecondaryColor: textSecondaryColor),
              const SizedBox(height: 8),
              // Note
              _buildNoteField(surfaceColor: surfaceColor, textSecondaryColor: textSecondaryColor),
              const SizedBox(height: 16),
              // Edit history note (only when editing)
              if (_isEditing)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '*ยังไม่มีข้อมูลการแก้ไข',
                      style: TextStyle(
                        fontSize: 14,
                        color: textSecondaryColor,
                      ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required Color surfaceColor,
    required Color textSecondaryColor,
  }) {
    return Container(
      color: surfaceColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: textSecondaryColor),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          filled: false,
        ),
        style: TextStyle(fontSize: 15, color: textSecondaryColor),
      ),
    );
  }

  Widget _buildDivider({required Color color}) => Divider(height: 1, indent: 16, color: color);

  Widget _buildPickerRow({
    required String label,
    required String value,
    required VoidCallback onTap,
    required Color surfaceColor,
    required Color textPrimaryColor,
    required Color textSecondaryColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: surfaceColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: textSecondaryColor,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                color: textPrimaryColor,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              color: textSecondaryColor,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconRow({required Color surfaceColor, required Color textSecondaryColor}) {
    return InkWell(
      onTap: _pickIcon,
      child: Container(
        color: surfaceColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Text(
              'ไอคอน',
              style: TextStyle(fontSize: 15, color: textSecondaryColor),
            ),
            const Spacer(),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _selectedColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_selectedIcon, color: _selectedColor, size: 26),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              color: textSecondaryColor,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorRow({required Color surfaceColor, required Color textSecondaryColor}) {
    return InkWell(
      onTap: _pickColor,
      child: Container(
        color: surfaceColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Text(
              'สี',
              style: TextStyle(fontSize: 15, color: textSecondaryColor),
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
              color: textSecondaryColor,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteField({required Color surfaceColor, required Color textSecondaryColor}) {
    return Container(
      color: surfaceColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'โน้ต',
                style: TextStyle(
                  fontSize: 15,
                  color: textSecondaryColor,
                ),
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _noteController,
              maxLines: 4,
              minLines: 2,
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
                filled: false,
              ),
              style: TextStyle(fontSize: 15, color: textSecondaryColor),
            ),
          ),
          Icon(
            Icons.drag_handle,
            color: textSecondaryColor,
            size: 20,
          ),
        ],
      ),
    );
  }

  void _pickParent(BuildContext context, List<Category> candidates) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Consumer<SettingsProvider>(
        builder: (context, settingsProvider, _) {
          final isDarkMode = settingsProvider.isDarkMode;
          final bgColor = isDarkMode ? AppColors.darkSurface : Colors.white;
          final handleColor = isDarkMode ? AppColors.darkDivider : Colors.grey.shade300;
          final textColor = isDarkMode ? AppColors.darkTextPrimary : AppColors.textPrimary;
          final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;
          final headerColor = isDarkMode ? AppColors.darkIncome : AppColors.header;

          return DraggableScrollableSheet(
            initialChildSize: 0.5,
            minChildSize: 0.3,
            maxChildSize: 0.85,
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
                  'เลือกหมวดหมู่หลัก',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: textColor),
                ),
                const SizedBox(height: 4),
                Divider(color: dividerColor),
                Expanded(
                  child: ListView(
                    controller: sc,
                    children: [
                      ListTile(
                        tileColor: bgColor,
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: (isDarkMode ? AppColors.darkTextSecondary : AppColors.textSecondary).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.category,
                            color: isDarkMode ? AppColors.darkTextSecondary : AppColors.textSecondary,
                            size: 18,
                          ),
                        ),
                        title: Text('(หมวดหมู่หลัก)', style: TextStyle(color: textColor)),
                        trailing: _parentId == null
                            ? Icon(Icons.check, color: headerColor)
                            : null,
                        onTap: () {
                          setState(() => _parentId = null);
                          Navigator.pop(context);
                        },
                      ),
                      ...candidates.map(
                        (cat) => ListTile(
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
                          trailing: _parentId == cat.id
                              ? Icon(Icons.check, color: headerColor)
                              : null,
                          onTap: () {
                            setState(() => _parentId = cat.id);
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                SafeArea(top: false, child: const SizedBox()),
              ],
            ),
          );
        },
      ),
    );
  }

  void _pickIcon() {
    showModalBottomSheet(
      context: context,
      builder: (_) => Consumer<SettingsProvider>(
        builder: (context, settingsProvider, _) {
          final isDarkMode = settingsProvider.isDarkMode;
          final bgColor = isDarkMode ? AppColors.darkBackground : AppColors.background;
          final textPrimaryColor = isDarkMode ? AppColors.darkTextPrimary : AppColors.textPrimary;
          final textSecondaryColor = isDarkMode ? AppColors.darkTextSecondary : AppColors.textSecondary;

          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'เลือกไอคอน',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: textPrimaryColor),
                  ),
                ),
                SizedBox(
                  height: 260,
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
          );
        },
      ),
    );
  }

  void _pickColor() {
    showModalBottomSheet(
      context: context,
      builder: (_) => Consumer<SettingsProvider>(
        builder: (context, settingsProvider, _) {
          final isDarkMode = settingsProvider.isDarkMode;
          final textPrimaryColor = isDarkMode ? AppColors.darkTextPrimary : AppColors.textPrimary;

          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'เลือกสี',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: textPrimaryColor),
                  ),
                ),
                SizedBox(
                  height: 200,
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
      ),
    );
  }
}
