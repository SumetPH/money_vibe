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
  CategoryType _type = CategoryType.expense;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<CategoryProvider, TransactionProvider>(
      builder: (context, catProvider, txProvider, _) {
        final allTransactions = txProvider.transactions;
        final cats = catProvider.categoriesOfType(_type);
        final filtered = _searchQuery.isEmpty
            ? cats
            : cats
                .where((c) => c.name
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase()))
                .toList();

        return Scaffold(
          drawer: const AppDrawer(currentRoute: '/categories'),
          appBar: AppBar(
            leading: Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
            title: _TypeToggle(
              selected: _type,
              onChanged: (t) => setState(() {
                _type = t;
                _searchQuery = '';
                _searchController.clear();
              }),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.bar_chart),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.more_horiz),
                onPressed: () {},
              ),
            ],
          ),
          body: Column(
            children: [
              // Search bar
              Container(
                color: AppColors.surface,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'ค้นหา',
                    hintStyle:
                        const TextStyle(color: AppColors.textSecondary),
                    prefixIcon: const Icon(Icons.search,
                        color: AppColors.textSecondary, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close,
                                color: AppColors.textSecondary, size: 18),
                            onPressed: () => setState(() {
                              _searchQuery = '';
                              _searchController.clear();
                            }),
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 0, horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              // List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isEmpty
                              ? 'ยังไม่มีหมวดหมู่'
                              : 'ไม่พบ "$_searchQuery"',
                          style: const TextStyle(
                              color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final cat = filtered[i];
                          final total = catProvider.getTotalForCategory(
                              cat.id, allTransactions);
                          return _CategoryItem(
                            category: cat,
                            total: total,
                            onTap: () => _openForm(context, cat),
                          );
                        },
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _openForm(context, null),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        );
      },
    );
  }

  void _openForm(BuildContext context, Category? cat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryFormScreen(
          category: cat,
          initialType: _type,
        ),
      ),
    );
  }
}

class _TypeToggle extends StatelessWidget {
  final CategoryType selected;
  final ValueChanged<CategoryType> onChanged;

  const _TypeToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _tab('รายจ่าย', CategoryType.expense),
          _tab('รายรับ', CategoryType.income),
        ],
      ),
    );
  }

  Widget _tab(String label, CategoryType type) {
    final isSelected = selected == type;
    return GestureDetector(
      onTap: () => onChanged(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.header : Colors.white70,
            fontWeight:
                isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _CategoryItem extends StatelessWidget {
  final Category category;
  final double total;
  final VoidCallback onTap;

  const _CategoryItem({
    required this.category,
    required this.total,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayAmount =
        category.type == CategoryType.expense ? -total : total;

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Container(
            color: AppColors.surface,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: category.color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(category.icon,
                      color: category.color, size: 22),
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
                          fontWeight: FontWeight.w500,
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
                const Icon(Icons.chevron_right,
                    color: AppColors.textSecondary, size: 20),
              ],
            ),
          ),
        ),
        const Divider(indent: 72, height: 1),
      ],
    );
  }
}
