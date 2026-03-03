import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/category.dart';
import '../../providers/category_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../main.dart';
import '../../widgets/app_drawer.dart';
import 'category_form_screen.dart';

class CategoryListScreen extends StatefulWidget {
  const CategoryListScreen({super.key});

  @override
  State<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends State<CategoryListScreen> {
  int _currentIndex = 0;
  bool _isReorderMode = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  CategoryType get _currentType =>
      _currentIndex == 0 ? CategoryType.expense : CategoryType.income;

  void _onTabChanged(int index) {
    setState(() {
      _currentIndex = index;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(currentRoute: '/categories'),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text('หมวดหมู่'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () => _showMenuBottomSheet(context),
          ),
        ],
      ),
      body: Consumer3<CategoryProvider, TransactionProvider, SettingsProvider>(
        builder: (context, catProvider, txProvider, settingsProvider, _) {
          final isDarkMode = settingsProvider.isDarkMode;
          return IndexedStack(
            index: _currentIndex,
            children: [
              _buildCategoryList(
                catProvider,
                txProvider,
                CategoryType.expense,
                isDarkMode,
              ),
              _buildCategoryList(
                catProvider,
                txProvider,
                CategoryType.income,
                isDarkMode,
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _isReorderMode ? null : _onTabChanged,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.arrow_downward),
            label: 'รายจ่าย',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.arrow_upward),
            label: 'รายรับ',
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList(
    CategoryProvider catProvider,
    TransactionProvider txProvider,
    CategoryType type,
    bool isDarkMode,
  ) {
    final allTransactions = txProvider.transactions;
    final cats = catProvider.categoriesOfType(type);
    final filtered = _searchQuery.isEmpty
        ? cats
        : cats
              .where(
                (c) =>
                    c.name.toLowerCase().contains(_searchQuery.toLowerCase()),
              )
              .toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.isEmpty ? 'ยังไม่มีหมวดหมู่' : 'ไม่พบ "$_searchQuery"',
          style: TextStyle(
            color: isDarkMode
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
          ),
        ),
      );
    }

    return ReorderableListView.builder(
      buildDefaultDragHandles: _isReorderMode,
      onReorder: _isReorderMode
          ? (oldIndex, newIndex) {
              catProvider.reorderCategories(type, oldIndex, newIndex);
            }
          : (_, _) {},
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final animValue = Curves.easeInOut.transform(animation.value);
            final elevation = 1 + animValue * 8;
            final scale = 1 + animValue * 0.02;
            return Transform.scale(
              scale: scale,
              child: Material(
                elevation: elevation,
                color: isDarkMode ? AppColors.darkSurface : AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                child: child,
              ),
            );
          },
          child: child,
        );
      },
      itemCount: filtered.length,
      itemBuilder: (context, i) {
        final cat = filtered[i];
        final total = catProvider.getTotalForCategory(cat.id, allTransactions);
        return _CategoryItem(
          key: ValueKey(cat.id),
          category: cat,
          total: total,
          isReorderMode: _isReorderMode,
          onTap: () => _openForm(context, cat),
          isDarkMode: isDarkMode,
        );
      },
    );
  }

  void _openForm(BuildContext context, Category? cat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CategoryFormScreen(category: cat, initialType: _currentType),
      ),
    );
  }

  void _showMenuBottomSheet(BuildContext context) {
    final isDarkMode = context.read<SettingsProvider>().isDarkMode;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? AppColors.darkSurface : Colors.white,
      builder: (_) => Consumer<SettingsProvider>(
        builder: (context, settingsProvider, _) {
          final isDarkMode = settingsProvider.isDarkMode;
          final bgColor = isDarkMode ? AppColors.darkSurface : Colors.white;
          final handleColor = isDarkMode
              ? AppColors.darkDivider
              : Colors.grey.shade300;
          final textColor = isDarkMode
              ? AppColors.darkTextPrimary
              : AppColors.textPrimary;
          final dividerColor = isDarkMode
              ? AppColors.darkDivider
              : AppColors.divider;

          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: handleColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  tileColor: bgColor,
                  leading: Icon(Icons.add, color: textColor),
                  title: Text(
                    'เพิ่มหมวดหมู่',
                    style: TextStyle(color: textColor),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _openForm(context, null);
                  },
                ),
                Divider(height: 1, color: dividerColor),
                ListTile(
                  tileColor: bgColor,
                  leading: Icon(Icons.reorder, color: textColor),
                  title: Text(
                    'จัดเรียงลำดับ',
                    style: TextStyle(color: textColor),
                  ),
                  trailing: Switch(
                    value: _isReorderMode,
                    onChanged: (value) {
                      setState(() => _isReorderMode = value);
                      Navigator.pop(context);
                    },
                  ),
                  onTap: () {
                    setState(() => _isReorderMode = !_isReorderMode);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CategoryItem extends StatelessWidget {
  final Category category;
  final double total;
  final bool isReorderMode;
  final VoidCallback onTap;
  final bool isDarkMode;

  const _CategoryItem({
    super.key,
    required this.category,
    required this.total,
    this.isReorderMode = false,
    required this.onTap,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final displayAmount = category.type == CategoryType.expense
        ? -total
        : total;

    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final textPrimaryColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final textSecondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;

    return Column(
      children: [
        InkWell(
          onTap: isReorderMode ? null : onTap,
          child: Container(
            color: surfaceColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // Drag handle (only visible in reorder mode)
                if (isReorderMode) ...[
                  Icon(Icons.drag_indicator, color: dividerColor, size: 20),
                  const SizedBox(width: 8),
                ],
                // Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: category.color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(category.icon, color: category.color, size: 22),
                ),
                const SizedBox(width: 12),
                // Name + amount
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: textPrimaryColor,
                        ),
                      ),
                      if (total > 0)
                        Text(
                          '${formatAmount(displayAmount)} บาท',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.getAmountColor(
                              displayAmount,
                              isDarkMode,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (!isReorderMode)
                  Icon(
                    Icons.chevron_right,
                    color: textSecondaryColor,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
        Divider(
          indent: isReorderMode ? 100 : 72,
          height: 1,
          color: dividerColor,
        ),
      ],
    );
  }
}
