import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/category.dart';
import '../../providers/category_provider.dart';
import '../../providers/transaction_provider.dart';
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
      body: Consumer2<CategoryProvider, TransactionProvider>(
        builder: (context, catProvider, txProvider, _) {
          return IndexedStack(
            index: _currentIndex,
            children: [
              _buildCategoryList(catProvider, txProvider, CategoryType.expense),
              _buildCategoryList(catProvider, txProvider, CategoryType.income),
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
          style: const TextStyle(color: AppColors.textSecondary),
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
                color: AppColors.surface,
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
    showModalBottomSheet(
      context: context,
      clipBehavior: Clip.antiAlias,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('เพิ่มหมวดหมู่'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openForm(context, null);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.reorder),
                title: const Text('จัดเรียงลำดับ'),
                trailing: Switch(
                  value: _isReorderMode,
                  onChanged: (value) {
                    setState(() => _isReorderMode = value);
                    Navigator.pop(ctx);
                  },
                ),
                onTap: () {
                  setState(() => _isReorderMode = !_isReorderMode);
                  Navigator.pop(ctx);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.bar_chart),
                title: const Text('สถิติ'),
                onTap: () {
                  Navigator.pop(ctx);
                  // TODO: Navigate to statistics
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

class _CategoryItem extends StatelessWidget {
  final Category category;
  final double total;
  final bool isReorderMode;
  final VoidCallback onTap;

  const _CategoryItem({
    super.key,
    required this.category,
    required this.total,
    this.isReorderMode = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayAmount = category.type == CategoryType.expense
        ? -total
        : total;

    return Column(
      children: [
        InkWell(
          onTap: isReorderMode ? null : onTap,
          child: Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // Drag handle (only visible in reorder mode)
                if (isReorderMode) ...[
                  const Icon(
                    Icons.drag_indicator,
                    color: AppColors.divider,
                    size: 20,
                  ),
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
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (total > 0)
                        Text(
                          '${formatAmount(displayAmount)} บาท',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.amountColor(displayAmount),
                          ),
                        ),
                    ],
                  ),
                ),
                if (!isReorderMode)
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
        Divider(indent: isReorderMode ? 100 : 72, height: 1),
      ],
    );
  }
}
