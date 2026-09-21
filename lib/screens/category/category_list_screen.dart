import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../../models/category.dart';
import '../../models/transaction.dart';
import '../../providers/category_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/sync_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_modal_bottom_sheet.dart';
import '../transaction/transaction_list_screen.dart';
import 'category_form_screen.dart';

class CategoryListScreen extends StatefulWidget {
  const CategoryListScreen({super.key});

  @override
  State<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends State<CategoryListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _currentIndex = 0;
  bool _isReorderMode = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<SyncProvider>().checkAndSync();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  CategoryType get _currentType =>
      _currentIndex == 0 ? CategoryType.expense : CategoryType.income;

  void _selectTab(int index) {
    if (_isReorderMode) {
      _tabController.animateTo(_currentIndex);
      return;
    }

    setState(() {
      _currentIndex = index;
      _searchQuery = '';
      _searchController.clear();
    });
    _tabController.animateTo(index);
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final isDarkMode = settingsProvider.isDarkMode;
    final bgColor = isDarkMode
        ? AppColors.darkBackground
        : AppColors.background;
    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final textPrimary = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final textSecondary = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final isLargeScreen = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: bgColor,
      drawer: isLargeScreen
          ? null
          : const AppDrawer(currentRoute: '/categories'),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: isLargeScreen ? 24 : 16,
        toolbarHeight: 100,
        leading: null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'จัดการข้อมูล',
              style: TextStyle(
                color: textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              'หมวดหมู่',
              style: TextStyle(
                color: textPrimary,
                fontSize: 30,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          if (_isReorderMode)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Material(
                  color: isDarkMode ? AppColors.darkIncome : AppColors.income,
                  borderRadius: BorderRadius.circular(AppRadii.full),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => setState(() => _isReorderMode = false),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'เสร็จสิ้น',
                            style: TextStyle(
                              color: Colors.white,
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
            )
          else ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Material(
                color: surfaceColor,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: IconButton(
                  icon: const Icon(Icons.add_rounded, size: 22),
                  color: textPrimary,
                  tooltip: 'เพิ่มหมวดหมู่ใหม่',
                  onPressed: () => _openForm(context, null),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Material(
                color: surfaceColor,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: IconButton(
                  icon: const Icon(Icons.more_horiz_rounded, size: 20),
                  color: textPrimary,
                  tooltip: 'ตัวเลือกเพิ่มเติม',
                  onPressed: () => _showMenuBottomSheet(context),
                ),
              ),
            ),
          ],
        ],
      ),
      body: Consumer3<CategoryProvider, TransactionProvider, SettingsProvider>(
        builder: (context, catProvider, txProvider, settingsProvider, _) {
          return SafeArea(
            child: Column(
              children: [
                // Reorder Mode Active Banner
                if (_isReorderMode) _buildReorderBanner(isDarkMode),

                // iOS Segmented Tab Control
                _buildSegmentedControl(
                  catProvider: catProvider,
                  surfaceColor: surfaceColor,
                  isDarkMode: isDarkMode,
                ),

                // Category List View
                Expanded(
                  child: TabBarView(
                    physics: const NeverScrollableScrollPhysics(),
                    controller: _tabController,
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
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildReorderBanner(bool isDarkMode) {
    final activeColor = isDarkMode ? AppColors.darkIncome : AppColors.income;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: activeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.large),
        border: Border.all(color: activeColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.swap_vert_rounded, color: activeColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'แตะค้างที่ไอคอนลากเพื่อจัดเรียงลำดับหมวดหมู่',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: activeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedControl({
    required CategoryProvider catProvider,
    required Color surfaceColor,
    required bool isDarkMode,
  }) {
    final expenseCount = catProvider.expenseCategories.length;
    final incomeCount = catProvider.incomeCategories.length;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
            child: _buildSegmentButton(
              index: 0,
              title: 'รายจ่าย',
              count: expenseCount,
              isSelected: _currentIndex == 0,
              accentColor: isDarkMode
                  ? AppColors.darkExpense
                  : AppColors.expense,
              isDarkMode: isDarkMode,
            ),
          ),
          Expanded(
            child: _buildSegmentButton(
              index: 1,
              title: 'รายรับ',
              count: incomeCount,
              isSelected: _currentIndex == 1,
              accentColor: isDarkMode ? AppColors.darkIncome : AppColors.income,
              isDarkMode: isDarkMode,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required int index,
    required String title,
    required int count,
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
        onTap: () => _selectTab(index),
        borderRadius: BorderRadius.circular(AppRadii.medium),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 8),
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
                width: 7,
                height: 7,
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
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? textPrimary : textSecondary,
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 1.5,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? accentColor.withValues(alpha: 0.15)
                      : textSecondary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadii.full),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? accentColor : textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
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
    final totalsByCategoryId = _buildCategoryTotals(allTransactions);
    final cats = catProvider.categoriesOfType(type);
    final filtered = _searchQuery.isEmpty
        ? cats
        : cats
              .where(
                (c) =>
                    c.name.toLowerCase().contains(_searchQuery.toLowerCase()),
              )
              .toList();

    final textSecondary = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;

    // Calculate total summary for this type
    double typeTotal = 0.0;
    for (final c in filtered) {
      typeTotal += (totalsByCategoryId[c.id] ?? 0.0);
    }

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: textSecondary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.category_outlined,
                  size: 32,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _searchQuery.isEmpty
                    ? 'ยังไม่มีหมวดหมู่'
                    : 'ไม่พบ "$_searchQuery"',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
              if (_searchQuery.isEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'กดปุ่ม + ด้านบนเพื่อเริ่มเพิ่มหมวดหมู่',
                  style: TextStyle(
                    fontSize: 13,
                    color: textSecondary.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _openForm(context, null),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDarkMode
                        ? AppColors.darkFabYellow
                        : AppColors.fabYellow,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.full),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text(
                    'เพิ่มหมวดหมู่',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      children: [
        // Metric Summary Capsule / Tile (when not reordering)
        if (!_isReorderMode)
          _buildMetricSummaryCard(
            type: type,
            totalAmount: typeTotal,
            itemCount: filtered.length,
            isDarkMode: isDarkMode,
            surfaceColor: surfaceColor,
            dividerColor: dividerColor,
            textSecondary: textSecondary,
          ),

        // Section Title
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 16, 8),
          child: Text(
            'รายการหมวดหมู่ (${filtered.length})',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ),

        // Inset Grouped Card containing category items
        Container(
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
          child: ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorderItem: _isReorderMode
                ? (oldIndex, newIndex) async {
                    await catProvider.reorderCategories(
                      type,
                      oldIndex,
                      newIndex,
                    );
                  }
                : (_, _) {},
            proxyDecorator: (child, index, animation) {
              return AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  final animValue = Curves.easeInOut.transform(animation.value);
                  final elevation = 2 + animValue * 6;
                  final scale = 1 + animValue * 0.02;
                  return Transform.scale(
                    scale: scale,
                    child: Material(
                      elevation: elevation,
                      color: isDarkMode
                          ? AppColors.darkSurfaceVariant
                          : Colors.white,
                      borderRadius: BorderRadius.circular(AppRadii.medium),
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
              final total = totalsByCategoryId[cat.id] ?? 0.0;
              final parentCat = cat.parentId != null
                  ? catProvider.findById(cat.parentId!)
                  : null;

              return _CategoryItem(
                key: ValueKey(cat.id),
                category: cat,
                parentCategoryName: parentCat?.name,
                total: total,
                isReorderMode: _isReorderMode,
                reorderIndex: _isReorderMode ? i : null,
                isFirst: i == 0,
                isLast: i == filtered.length - 1,
                onTap: () => _openTransactions(context, cat),
                onTapEdit: () => _openForm(context, cat),
                isDarkMode: isDarkMode,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMetricSummaryCard({
    required CategoryType type,
    required double totalAmount,
    required int itemCount,
    required bool isDarkMode,
    required Color surfaceColor,
    required Color dividerColor,
    required Color textSecondary,
  }) {
    final isExpense = type == CategoryType.expense;
    final amountColor = isExpense
        ? (isDarkMode ? AppColors.darkExpense : AppColors.expense)
        : (isDarkMode ? AppColors.darkIncome : AppColors.income);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppRadii.xLarge),
        border: Border.all(
          color: dividerColor.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isExpense
                    ? 'ยอดรวมรายจ่ายในหมวดหมู่นี้'
                    : 'ยอดรวมรายรับในหมวดหมู่นี้',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${formatAmount(totalAmount)} บาท',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: amountColor,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: amountColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.full),
            ),
            child: Text(
              '$itemCount หมวดหมู่',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: amountColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, double> _buildCategoryTotals(List<AppTransaction> transactions) {
    final totals = <String, double>{};
    for (final tx in transactions) {
      final categoryId = tx.categoryId;
      if (categoryId == null || tx.type.isTransferLike) continue;
      totals[categoryId] = (totals[categoryId] ?? 0.0) + tx.amount;
    }
    return totals;
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

  void _openTransactions(BuildContext context, Category category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionListScreen(
          categoryIds: [category.id],
          title: category.name,
        ),
      ),
    );
  }

  void _showMenuBottomSheet(BuildContext context) {
    showAppModalBottomSheet(
      context: context,
      builder: (_) => Consumer<SettingsProvider>(
        builder: (context, settingsProvider, _) {
          final isDarkMode = settingsProvider.isDarkMode;
          final textColor = isDarkMode
              ? AppColors.darkTextPrimary
              : AppColors.textPrimary;
          final textSecondary = isDarkMode
              ? AppColors.darkTextSecondary
              : AppColors.textSecondary;
          final dividerColor = isDarkMode
              ? AppColors.darkDivider
              : AppColors.divider;

          return StatefulBuilder(
            builder: (context, setStateModal) {
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppModalBottomSheetHeader(
                        title: 'ตัวเลือกหมวดหมู่',
                      ),
                      const SizedBox(height: 8),
                      // Grouped menu container
                      Material(
                        color: isDarkMode
                            ? AppColors.darkSurfaceVariant
                            : AppColors.background,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.xLarge),
                          side: BorderSide(
                            color: dividerColor.withValues(alpha: 0.35),
                            width: 1,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            ListTile(
                              leading: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color:
                                      (isDarkMode
                                              ? AppColors.darkFabYellow
                                              : AppColors.fabYellow)
                                          .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.medium,
                                  ),
                                ),
                                child: Icon(
                                  Icons.add_rounded,
                                  color: isDarkMode
                                      ? AppColors.darkFabYellow
                                      : AppColors.fabYellow,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                'เพิ่มหมวดหมู่ใหม่',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                'สร้างหมวดหมู่รายรับหรือรายจ่ายใหม่',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                _openForm(context, null);
                              },
                            ),
                            Divider(
                              height: 1,
                              indent: 58,
                              endIndent: 16,
                              color: dividerColor.withValues(alpha: 0.3),
                            ),
                            ListTile(
                              leading: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color:
                                      (isDarkMode
                                              ? AppColors.darkIncome
                                              : AppColors.income)
                                          .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.medium,
                                  ),
                                ),
                                child: Icon(
                                  Icons.reorder_rounded,
                                  color: isDarkMode
                                      ? AppColors.darkIncome
                                      : AppColors.income,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                'จัดเรียงลำดับหมวดหมู่',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                'เปิดโหมดลากสลับตำแหน่งหมวดหมู่',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: CupertinoSwitch(
                                value: _isReorderMode,
                                activeTrackColor: isDarkMode
                                    ? AppColors.darkIncome
                                    : AppColors.income,
                                inactiveTrackColor: isDarkMode
                                    ? const Color(0xFF39393D)
                                    : const Color(0xFFE9E9EA),
                                onChanged: (value) {
                                  setStateModal(() => _isReorderMode = value);
                                  setState(() => _isReorderMode = value);
                                  if (value) {
                                    Navigator.pop(context);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _CategoryItem extends StatelessWidget {
  final Category category;
  final String? parentCategoryName;
  final double total;
  final bool isReorderMode;
  final int? reorderIndex;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;
  final VoidCallback onTapEdit;
  final bool isDarkMode;

  const _CategoryItem({
    super.key,
    required this.category,
    this.parentCategoryName,
    required this.total,
    this.isReorderMode = false,
    this.reorderIndex,
    this.isFirst = false,
    this.isLast = false,
    required this.onTap,
    required this.onTapEdit,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final displayAmount = category.type == CategoryType.expense
        ? -total
        : total;

    final textPrimaryColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final textSecondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isReorderMode ? null : onTap,
            onLongPress: isReorderMode
                ? null
                : () => _showCategoryMenu(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Row(
                children: [
                  // Drag handle (visible only in reorder mode)
                  if (reorderIndex != null) ...[
                    ReorderableDragStartListener(
                      index: reorderIndex!,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Icon(
                          Icons.drag_indicator_rounded,
                          color: textSecondaryColor,
                          size: 22,
                        ),
                      ),
                    ),
                  ],

                  // Squircle Icon Container
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: category.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadii.medium),
                    ),
                    child: Icon(category.icon, color: category.color, size: 22),
                  ),
                  const SizedBox(width: 14),

                  // Name and Subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: textPrimaryColor,
                          ),
                        ),
                        if (parentCategoryName != null) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.subdirectory_arrow_right_rounded,
                                size: 12,
                                color: textSecondaryColor,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                parentCategoryName!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: textSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ] else if (category.note != null &&
                            category.note!.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            category.note!.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondaryColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Total Amount display
                  if (total > 0) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${formatAmount(displayAmount)} ฿',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.getAmountColor(
                          displayAmount,
                          isDarkMode,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (!isLast)
          Divider(height: 1, color: AppColors.listDividerFor(isDarkMode)),
      ],
    );
  }

  void _showCategoryMenu(BuildContext context) {
    showAppModalBottomSheet(
      context: context,
      builder: (_) => Consumer<SettingsProvider>(
        builder: (context, settingsProvider, _) {
          final isDark = settingsProvider.isDarkMode;
          final textColor = isDark
              ? AppColors.darkTextPrimary
              : AppColors.textPrimary;
          final textSecondary = isDark
              ? AppColors.darkTextSecondary
              : AppColors.textSecondary;
          final dividerColor = isDark
              ? AppColors.darkDivider
              : AppColors.divider;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppModalBottomSheetHeader(title: category.name),
                  const SizedBox(height: 8),
                  Material(
                    color: isDark
                        ? AppColors.darkSurfaceVariant
                        : AppColors.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.xLarge),
                      side: BorderSide(
                        color: dividerColor.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        ListTile(
                          leading: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: category.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(
                                AppRadii.medium,
                              ),
                            ),
                            child: Icon(
                              Icons.receipt_long_rounded,
                              color: category.color,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            'ดูรายการธุรกรรม',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            'แสดงรายการทั้งหมดที่บันทึกในหมวดหมู่นี้',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right_rounded,
                            color: textSecondary,
                            size: 20,
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            onTap();
                          },
                        ),
                        Divider(
                          height: 1,
                          indent: 58,
                          endIndent: 16,
                          color: dividerColor.withValues(alpha: 0.3),
                        ),
                        ListTile(
                          leading: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color:
                                  (isDark
                                          ? AppColors.darkFabYellow
                                          : AppColors.fabYellow)
                                      .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(
                                AppRadii.medium,
                              ),
                            ),
                            child: Icon(
                              Icons.edit_outlined,
                              color: isDark
                                  ? AppColors.darkFabYellow
                                  : AppColors.fabYellow,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            'แก้ไขหมวดหมู่',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            'แก้ไขชื่อ ไอคอน สี หรือหมวดหมู่หลัก',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right_rounded,
                            color: textSecondary,
                            size: 20,
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            onTapEdit();
                          },
                        ),
                      ],
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
}
