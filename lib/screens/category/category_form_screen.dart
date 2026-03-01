import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/category.dart';
import '../../providers/category_provider.dart';
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
  late bool _isDefault;
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
    _isDefault = cat?.isDefault ?? false;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกชื่อหมวดหมู่')),
      );
      return;
    }

    final provider = context.read<CategoryProvider>();

    if (_isEditing) {
      provider.updateCategory(widget.category!.copyWith(
        name: name,
        icon: _selectedIcon,
        color: _selectedColor,
        isDefault: _isDefault,
        parentId: _parentId,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        clearParent: _parentId == null,
        clearNote: _noteController.text.trim().isEmpty,
      ));
    } else {
      provider.addCategory(Category(
        id: provider.generateId(),
        name: name,
        icon: _selectedIcon,
        color: _selectedColor,
        type: _type,
        parentId: _parentId,
        isDefault: _isDefault,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      ));
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_isEditing ? 'แก้ไขหมวดหมู่' : 'เพิ่มหมวดหมู่ใหม่'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _save,
          ),
        ],
      ),
      body: Consumer<CategoryProvider>(
        builder: (context, catProvider, _) {
          final parentCandidates = catProvider
              .mainCategoriesOfType(_type)
              .where((c) => c.id != widget.category?.id)
              .toList();
          final parentCategory =
              _parentId != null ? catProvider.findById(_parentId!) : null;

          return ListView(
            children: [
              const SizedBox(height: 8),
              // Name
              _buildTextField(
                controller: _nameController,
                hintText: 'ชื่อ',
              ),
              _buildDivider(),
              // Parent category
              _buildPickerRow(
                label: 'เป็นหมวดหมู่ย่อยของ',
                value: parentCategory?.name ?? '(หมวดหมู่หลัก)',
                onTap: () => _pickParent(context, parentCandidates),
              ),
              _buildDivider(),
              // Icon
              _buildIconRow(),
              _buildDivider(),
              // Color
              _buildColorRow(),
              const SizedBox(height: 8),
              // isDefault toggle
              _buildSwitchRow(
                label: 'หมวดหมู่เริ่มต้น',
                value: _isDefault,
                onChanged: (v) => setState(() => _isDefault = v),
              ),
              const SizedBox(height: 8),
              // Note
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(
                      width: 60,
                      child: Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'โน้ต',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.textSecondary,
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
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 12),
                        ),
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                    const Icon(Icons.drag_handle,
                        color: AppColors.textSecondary, size: 20),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Edit history note (only when editing)
              if (_isEditing)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text(
                      '*ยังไม่มีข้อมูลการแก้ไข',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
  }) {
    return Container(
      color: AppColors.surface,
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle:
              const TextStyle(color: AppColors.textSecondary),
          border: InputBorder.none,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 12),
        ),
        style: const TextStyle(fontSize: 15),
      ),
    );
  }

  Widget _buildPickerRow({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: AppColors.surface,
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                color: AppColors.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildIconRow() {
    return InkWell(
      onTap: _pickIcon,
      child: Container(
        color: AppColors.surface,
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Text(
              'ไอคอน',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _selectedColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_selectedIcon,
                  color: _selectedColor, size: 26),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                color: AppColors.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildColorRow() {
    return InkWell(
      onTap: _pickColor,
      child: Container(
        color: AppColors.surface,
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Text(
              'สี',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
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
            const Icon(Icons.chevron_right,
                color: AppColors.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildDivider() => const Divider(height: 1, indent: 16);

  void _pickParent(
      BuildContext context, List<Category> candidates) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
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
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'เลือกหมวดหมู่หลัก',
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Divider(),
            Expanded(
              child: ListView(
                controller: sc,
                children: [
                  // Option: no parent (main category)
                  ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary
                            .withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.category,
                          color: AppColors.textSecondary,
                          size: 18),
                    ),
                    title: const Text('(หมวดหมู่หลัก)'),
                    trailing: _parentId == null
                        ? const Icon(Icons.check,
                            color: AppColors.header)
                        : null,
                    onTap: () {
                      setState(() => _parentId = null);
                      Navigator.pop(context);
                    },
                  ),
                  ...candidates.map((cat) => ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: cat.color
                                .withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(cat.icon,
                              color: cat.color, size: 18),
                        ),
                        title: Text(cat.name),
                        trailing: _parentId == cat.id
                            ? const Icon(Icons.check,
                                color: AppColors.header)
                            : null,
                        onTap: () {
                          setState(() => _parentId = cat.id);
                          Navigator.pop(context);
                        },
                      )),
                ],
              ),
            ),
            const SafeArea(top: false, child: SizedBox()),
          ],
        ),
      ),
    );
  }

  void _pickIcon() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'เลือกไอคอน',
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
            SizedBox(
              height: 260,
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
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedIcon = icon);
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: selected
                            ? _selectedColor
                                .withValues(alpha: 0.15)
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: selected
                            ? Border.all(
                                color: _selectedColor,
                                width: 2)
                            : null,
                      ),
                      child: Icon(icon,
                          color: selected
                              ? _selectedColor
                              : AppColors.textSecondary,
                          size: 24),
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

  void _pickColor() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'เลือกสี',
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
            SizedBox(
              height: 200,
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
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
                            ? Border.all(
                                color: Colors.black45, width: 2)
                            : null,
                      ),
                      child: selected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 20)
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
