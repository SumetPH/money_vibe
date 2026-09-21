import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/category.dart';
import '../../providers/category_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../widgets/app_modal_bottom_sheet.dart';

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
  bool _isLoading = false;

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

    _nameController.addListener(_onFieldChanged);
    _noteController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFieldChanged);
    _noteController.removeListener(_onFieldChanged);
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('กรุณากรอกชื่อหมวดหมู่'),
          backgroundColor: AppColors.expense,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
        ),
      );
      return;
    }

    final provider = context.read<CategoryProvider>();

    setState(() => _isLoading = true);

    try {
      if (_isEditing) {
        await provider.updateCategory(
          widget.category!.copyWith(
            name: name,
            icon: _selectedIcon,
            color: _selectedColor,
            type: _type,
            parentId: _parentId,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
            clearParent: _parentId == null,
            clearNote: _noteController.text.trim().isEmpty,
          ),
        );
      } else {
        await provider.addCategory(
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

      if (mounted) {
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
    final dialogBgColor = isDarkMode
        ? AppColors.darkSurface
        : AppColors.surface;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final textSecondary = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: dialogBgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sheet),
        ),
        title: Text(
          'ลบหมวดหมู่',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'คุณต้องการลบหมวดหมู่ "${widget.category?.name}" ใช่หรือไม่? รายการธุรกรรมเดิมที่ผูกกับหมวดหมู่นี้จะยังคงอยู่ในระบบ',
          style: TextStyle(color: textSecondary, fontSize: 14),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'ยกเลิก',
              style: TextStyle(
                color: textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<CategoryProvider>().deleteCategory(
                widget.category!.id,
              );
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close form
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDarkMode
                  ? AppColors.darkExpense
                  : AppColors.expense,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.full),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              elevation: 0,
            ),
            child: const Text(
              'ลบหมวดหมู่',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _onTypeChanged(CategoryType newType) {
    setState(() {
      _type = newType;
      // Reset parent if switching type to avoid cross-type parentage
      _parentId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<CategoryProvider, SettingsProvider>(
      builder: (context, catProvider, settingsProvider, _) {
        final isDarkMode = settingsProvider.isDarkMode;
        final bgColor = isDarkMode
            ? AppColors.darkBackground
            : AppColors.background;
        final surfaceColor = isDarkMode
            ? AppColors.darkSurface
            : AppColors.surface;
        final textPrimaryColor = isDarkMode
            ? AppColors.darkTextPrimary
            : AppColors.textPrimary;
        final textSecondaryColor = isDarkMode
            ? AppColors.darkTextSecondary
            : AppColors.textSecondary;
        final dividerColor = isDarkMode
            ? AppColors.darkDivider
            : AppColors.divider;

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
            backgroundColor: bgColor,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: true,
            leadingWidth: 64,
            leading: Center(
              child: Material(
                color: surfaceColor,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: textPrimaryColor,
                  tooltip: 'ปิด',
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                ),
              ),
            ),
            title: Text(
              _isEditing ? 'แก้ไขหมวดหมู่' : 'เพิ่มหมวดหมู่ใหม่',
              style: TextStyle(
                color: textPrimaryColor,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            actions: [
              if (_isEditing)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Material(
                    color: surfaceColor,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: IconButton(
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        size: 20,
                        color: isDarkMode
                            ? AppColors.darkExpense
                            : AppColors.expense,
                      ),
                      tooltip: 'ลบหมวดหมู่',
                      onPressed: _isLoading ? null : _delete,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Material(
                    color: isDarkMode
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
                // 1. Type Selector (Segmented Control)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildTypeSelector(
                    surfaceColor: surfaceColor,
                    dividerColor: dividerColor,
                    isDarkMode: isDarkMode,
                  ),
                ),
                const SizedBox(height: 12),

                // 2. Live Category Preview Hero Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildLivePreviewCard(
                    parentCategory: parentCategory,
                    surfaceColor: surfaceColor,
                    dividerColor: dividerColor,
                    textPrimaryColor: textPrimaryColor,
                    textSecondaryColor: textSecondaryColor,
                    isDarkMode: isDarkMode,
                  ),
                ),
                const SizedBox(height: 8),

                // 3. Section: ข้อมูลหมวดหมู่ (Category Info)
                _buildSectionHeader('ข้อมูลหมวดหมู่', textSecondaryColor),
                _buildInsetCard(
                  [
                    _buildNameFieldRow(
                      controller: _nameController,
                      surfaceColor: surfaceColor,
                      textPrimaryColor: textPrimaryColor,
                      textSecondaryColor: textSecondaryColor,
                    ),
                    _buildIndentedDivider(dividerColor),
                    _buildPickerRow(
                      icon: Icons.account_tree_outlined,
                      label: 'หมวดหมู่หลัก',
                      value: parentCategory?.name ?? '(เป็นหมวดหมู่หลัก)',
                      onTap: () => _pickParent(context, parentCandidates),
                      surfaceColor: surfaceColor,
                      textPrimaryColor: textPrimaryColor,
                      textSecondaryColor: textSecondaryColor,
                    ),
                  ],
                  surfaceColor: surfaceColor,
                  dividerColor: dividerColor,
                ),

                // 4. Section: รูปลักษณ์ (Appearance)
                _buildSectionHeader('รูปลักษณ์', textSecondaryColor),
                _buildInsetCard(
                  [
                    _buildIconRow(
                      surfaceColor: surfaceColor,
                      textPrimaryColor: textPrimaryColor,
                      textSecondaryColor: textSecondaryColor,
                    ),
                    _buildIndentedDivider(dividerColor),
                    _buildColorRow(
                      surfaceColor: surfaceColor,
                      textPrimaryColor: textPrimaryColor,
                      textSecondaryColor: textSecondaryColor,
                    ),
                  ],
                  surfaceColor: surfaceColor,
                  dividerColor: dividerColor,
                ),

                // 5. Section: บันทึกช่วยจำ (Note)
                _buildSectionHeader('บันทึกช่วยจำ', textSecondaryColor),
                _buildInsetCard(
                  [
                    _buildNoteField(
                      controller: _noteController,
                      surfaceColor: surfaceColor,
                      textPrimaryColor: textPrimaryColor,
                      textSecondaryColor: textSecondaryColor,
                    ),
                  ],
                  surfaceColor: surfaceColor,
                  dividerColor: dividerColor,
                ),

                // 6. Section: การจัดการ (Delete row if editing)
                if (_isEditing) ...[
                  _buildSectionHeader('การจัดการ', textSecondaryColor),
                  _buildInsetCard(
                    [
                      _buildDeleteRow(
                        isDarkMode: isDarkMode,
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

  Widget _buildTypeSelector({
    required Color surfaceColor,
    required Color dividerColor,
    required bool isDarkMode,
  }) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppRadii.large),
        border: Border.all(
          color: dividerColor.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTypeButton(
              type: CategoryType.expense,
              title: 'หมวดหมู่รายจ่าย',
              isSelected: _type == CategoryType.expense,
              accentColor: isDarkMode
                  ? AppColors.darkExpense
                  : AppColors.expense,
              isDarkMode: isDarkMode,
            ),
          ),
          Expanded(
            child: _buildTypeButton(
              type: CategoryType.income,
              title: 'หมวดหมู่รายรับ',
              isSelected: _type == CategoryType.income,
              accentColor: isDarkMode ? AppColors.darkIncome : AppColors.income,
              isDarkMode: isDarkMode,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeButton({
    required CategoryType type,
    required String title,
    required bool isSelected,
    required Color accentColor,
    required bool isDarkMode,
  }) {
    final selectedBg = isDarkMode ? AppColors.darkSurfaceVariant : Colors.white;
    final textPrimary = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final textSecondary = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onTypeChanged(type),
        borderRadius: BorderRadius.circular(AppRadii.medium),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? selectedBg : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.medium),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1.5),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? accentColor
                      : accentColor.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? textPrimary : textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLivePreviewCard({
    required Category? parentCategory,
    required Color surfaceColor,
    required Color dividerColor,
    required Color textPrimaryColor,
    required Color textSecondaryColor,
    required bool isDarkMode,
  }) {
    final name = _nameController.text.trim();
    final displayName = name.isEmpty ? 'ตัวอย่างชื่อหมวดหมู่' : name;
    final isExpense = _type == CategoryType.expense;
    final typeBadgeColor = isExpense
        ? (isDarkMode ? AppColors.darkExpense : AppColors.expense)
        : (isDarkMode ? AppColors.darkIncome : AppColors.income);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppRadii.xLarge),
        border: Border.all(
          color: dividerColor.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Selected Icon preview
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

          // Name and info
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
                  parentCategory != null
                      ? 'หมวดหมู่ย่อยของ: ${parentCategory.name}'
                      : 'หมวดหมู่หลัก',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),

          // Status Type Capsule
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: typeBadgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.full),
            ),
            child: Text(
              isExpense ? 'รายจ่าย' : 'รายรับ',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: typeBadgeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppRadii.xLarge),
        border: Border.all(
          color: dividerColor.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
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

  Widget _buildNameFieldRow({
    required TextEditingController controller,
    required Color surfaceColor,
    required Color textPrimaryColor,
    required Color textSecondaryColor,
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
            child: Icon(
              Icons.edit_note_rounded,
              color: textSecondaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 70,
            child: Text(
              'ชื่อ',
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
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              decoration: InputDecoration(
                hintText: 'กรอกชื่อหมวดหมู่',
                hintStyle: TextStyle(
                  color: textSecondaryColor.withValues(alpha: 0.6),
                  fontSize: 15,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
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
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: () => controller.clear(),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.cancel_rounded,
                  color: textSecondaryColor.withValues(alpha: 0.6),
                  size: 18,
                ),
              ),
            ),
        ],
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
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
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: textPrimaryColor,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: textSecondaryColor,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconRow({
    required Color surfaceColor,
    required Color textPrimaryColor,
    required Color textSecondaryColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _pickIcon,
        child: Padding(
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
                  Icons.category_outlined,
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
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _selectedColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                ),
                child: Icon(_selectedIcon, color: _selectedColor, size: 20),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                color: textSecondaryColor,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorRow({
    required Color surfaceColor,
    required Color textPrimaryColor,
    required Color textSecondaryColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _pickColor,
        child: Padding(
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
                  Icons.color_lens_outlined,
                  color: textSecondaryColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'สีประจำหมวด',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: textPrimaryColor,
                ),
              ),
              const Spacer(),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _selectedColor,
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                  boxShadow: [
                    BoxShadow(
                      color: _selectedColor.withValues(alpha: 0.4),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                color: textSecondaryColor,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoteField({
    required TextEditingController controller,
    required Color surfaceColor,
    required Color textPrimaryColor,
    required Color textSecondaryColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: textSecondaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadii.medium),
              ),
              child: Icon(
                Icons.notes_rounded,
                color: textSecondaryColor,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: 4,
              minLines: 2,
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              decoration: InputDecoration(
                hintText: 'บันทึกช่วยจำ (ไม่บังคับ)',
                hintStyle: TextStyle(
                  color: textSecondaryColor.withValues(alpha: 0.6),
                  fontSize: 15,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
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

  Widget _buildDeleteRow({
    required bool isDarkMode,
    required Color surfaceColor,
  }) {
    final expenseColor = isDarkMode ? AppColors.darkExpense : AppColors.expense;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _delete,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: expenseColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                ),
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: expenseColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'ลบหมวดหมู่นี้',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: expenseColor,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.chevron_right_rounded,
                color: expenseColor.withValues(alpha: 0.7),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _pickParent(BuildContext context, List<Category> candidates) {
    showAppModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Consumer<SettingsProvider>(
        builder: (context, settingsProvider, _) {
          final isDarkMode = settingsProvider.isDarkMode;
          final textColor = isDarkMode
              ? AppColors.darkTextPrimary
              : AppColors.textPrimary;
          final textSecondary = isDarkMode
              ? AppColors.darkTextSecondary
              : AppColors.textSecondary;
          final checkColor = isDarkMode
              ? AppColors.darkIncome
              : AppColors.income;

          return DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.3,
            maxChildSize: 0.85,
            expand: false,
            builder: (_, scrollController) => Column(
              children: [
                const AppModalBottomSheetHeader(title: 'เลือกหมวดหมู่หลัก'),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: candidates.length + 1,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: AppColors.listDividerFor(isDarkMode),
                    ),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        final isSelected = _parentId == null;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: textSecondary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(
                                AppRadii.medium,
                              ),
                            ),
                            child: Icon(
                              Icons.category_outlined,
                              color: textSecondary,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            '(เป็นหมวดหมู่หลัก)',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 15,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            'ไม่สังกัดหมวดหมู่อื่น',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(
                                  Icons.check_circle_rounded,
                                  color: checkColor,
                                  size: 22,
                                )
                              : null,
                          onTap: () {
                            setState(() => _parentId = null);
                            Navigator.pop(context);
                          },
                        );
                      }

                      final cat = candidates[index - 1];
                      final isSelected = _parentId == cat.id;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        leading: Container(
                          width: 36,
                          height: 36,
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
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle_rounded,
                                color: checkColor,
                                size: 22,
                              )
                            : null,
                        onTap: () {
                          setState(() => _parentId = cat.id);
                          Navigator.pop(context);
                        },
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

  void _pickIcon() {
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
                  const AppModalBottomSheetHeader(title: 'เลือกไอคอนหมวดหมู่'),
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
                              ? _selectedColor.withValues(alpha: 0.15)
                              : bgColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadii.large),
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
              const AppModalBottomSheetHeader(title: 'เลือกสีประจำหมวด'),
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
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 24,
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
}
