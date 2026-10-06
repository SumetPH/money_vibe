import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/budget.dart';
import '../../providers/budget_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../main.dart';
import '../../widgets/app_reorder_mode.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/monthly_cycle_selector.dart';
import '../../utils/monthly_cycle.dart';
import '../../services/budget_spending_service.dart';
import '../../screens/transaction/transaction_list_screen.dart';
import '../../widgets/app_inset_card.dart';
import 'budget_list_models.dart';
import 'budget_empty_state.dart';
import 'budget_menu_sheet.dart';
import 'budget_summary_header.dart';
import 'budget_item_card.dart';
import 'budget_group_details_sheet.dart';

class BudgetListScreen extends StatefulWidget {
  final bool showPrimaryNavigation;

  const BudgetListScreen({super.key, this.showPrimaryNavigation = true});

  @override
  State<BudgetListScreen> createState() => _BudgetListScreenState();
}

class _BudgetListScreenState extends State<BudgetListScreen> {
  bool _isReorderMode = false;
  late DateTime _selectedMonth;
  int? _cycleStartDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final startDay = Provider.of<SettingsProvider>(
      context,
    ).monthlyCycleStartDay;
    if (_cycleStartDay != startDay) {
      _cycleStartDay = startDay;
      _selectedMonth = _currentCycleMonth(startDay);
    }
  }

  /// คำนวณว่าวันนี้อยู่ใน cycle ของเดือนไหน
  DateTime _currentCycleMonth(int startDay) {
    return monthlyCycleReportingMonth(DateTime.now(), startDay);
  }

  void _prevMonth() => setState(
    () => _selectedMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month - 1,
    ),
  );

  void _nextMonth() => setState(
    () => _selectedMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
    ),
  );

  DateTimeRange _getBudgetPeriod(int startDay) {
    final period = monthlyCyclePeriod(_selectedMonth, startDay);
    return DateTimeRange(
      start: period.start,
      end: period.endExclusive.subtract(const Duration(microseconds: 1)),
    );
  }

  String _formatBudgetPeriodLabel(DateTimeRange period) {
    const thaiMonths = [
      'ม.ค.',
      'ก.พ.',
      'มี.ค.',
      'เม.ย.',
      'พ.ค.',
      'มิ.ย.',
      'ก.ค.',
      'ส.ค.',
      'ก.ย.',
      'ต.ค.',
      'พ.ย.',
      'ธ.ค.',
    ];

    final start = period.start;
    final end = period.end;
    final startLabel =
        '${start.day} ${thaiMonths[start.month - 1]} ${start.year}';
    final endLabel = '${end.day} ${thaiMonths[end.month - 1]} ${end.year}';
    return '$startLabel - $endLabel';
  }

  String _formatBudgetTitle() {
    const thaiMonths = [
      'มกราคม',
      'กุมภาพันธ์',
      'มีนาคม',
      'เมษายน',
      'พฤษภาคม',
      'มิถุนายน',
      'กรกฎาคม',
      'สิงหาคม',
      'กันยายน',
      'ตุลาคม',
      'พฤศจิกายน',
      'ธันวาคม',
    ];
    return '${thaiMonths[_selectedMonth.month - 1]} '
        '${_selectedMonth.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<BudgetProvider, TransactionProvider, SettingsProvider>(
      builder: (context, budgetProvider, txProvider, settingsProvider, _) {
        final accounts = context.read<AccountProvider>().accounts;
        final isDarkMode = settingsProvider.isDarkMode;
        final startDay = settingsProvider.monthlyCycleStartDay;
        final period = _getBudgetPeriod(startDay);
        final allTx = txProvider.transactions;
        final budgets = budgetProvider.visibleBudgets;

        final bgColor = isDarkMode
            ? AppColors.darkBackground
            : AppColors.background;
        final surfaceColor = isDarkMode
            ? AppColors.darkSurface
            : AppColors.surface;
        final textPrimary = isDarkMode
            ? AppColors.darkTextPrimary
            : AppColors.textPrimary;
        final textSecondary = isDarkMode
            ? AppColors.darkTextSecondary
            : AppColors.textSecondary;
        final dividerColor = isDarkMode
            ? AppColors.darkDivider
            : AppColors.divider;

        // Summary calculations
        final spentByCategoryId = BudgetSpendingService.spentByCategoryId(
          transactions: allTx,
          start: period.start,
          end: period.end,
          accounts: accounts,
        );
        var totalBudget = 0.0;
        var totalSpent = 0.0;
        var totalAvailable = 0.0;
        var totalOverspent = 0.0;
        for (final budget in budgets) {
          final spent = BudgetSpendingService.spentFor(
            budget,
            spentByCategoryId,
          );
          final remaining = budget.amount - spent;
          totalBudget += budget.amount;
          totalSpent += spent;
          if (remaining >= 0) {
            totalAvailable += remaining;
          } else {
            totalOverspent += remaining.abs();
          }
        }
        final overallProgress = totalBudget > 0
            ? (totalSpent / totalBudget)
            : 0.0;
        final groupSummaries = buildBudgetGroupSummaries(
          budgets: budgets,
          spentByCategoryId: spentByCategoryId,
          totalBudget: totalBudget,
        );
        final periodLabel = _formatBudgetPeriodLabel(period);

        final isLargeScreen = MediaQuery.of(context).size.width >= 800;

        return Scaffold(
          backgroundColor: bgColor,
          drawer: isLargeScreen
              ? null
              : widget.showPrimaryNavigation
              ? const AppDrawer(currentRoute: '/budgets')
              : null,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            toolbarHeight: 100,
            backgroundColor: bgColor,
            foregroundColor: textPrimary,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,
            titleSpacing: isLargeScreen ? 24 : 16,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isReorderMode ? 'งบประมาณ' : _formatBudgetTitle(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _isReorderMode ? 'จัดเรียง' : 'งบประมาณ',
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
                AppReorderDoneButton(
                  onPressed: () => setState(() => _isReorderMode = false),
                )
              else ...[
                Material(
                  color: surfaceColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.full),
                    side: BorderSide(
                      color: AppColors.borderFor(isDarkMode),
                      width: 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: IconButton(
                    icon: const Icon(Icons.pie_chart_outline_rounded),
                    color: textPrimary,
                    tooltip: 'รายละเอียดกลุ่มงบประมาณ',
                    onPressed: () => showBudgetGroupDetailsSheet(
                      context,
                      groupSummaries,
                      periodLabel,
                      totalBudget,
                      totalSpent,
                      totalAvailable,
                      totalOverspent,
                      overallProgress,
                      isDarkMode,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Material(
                    color: surfaceColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.full),
                      side: BorderSide(
                        color: AppColors.borderFor(isDarkMode),
                        width: 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: IconButton(
                      icon: const Icon(Icons.more_horiz_rounded),
                      color: textPrimary,
                      tooltip: 'ตัวเลือกเพิ่มเติม',
                      onPressed: () => showBudgetMenuSheet(
                        context,
                        isDarkMode,
                        isReorderMode: _isReorderMode,
                        onReorderModeChanged: (v) =>
                            setState(() => _isReorderMode = v),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          body: SafeArea(
            bottom: false,
            child: budgets.isEmpty
                ? BudgetEmptyState(
                    surfaceColor: surfaceColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    dividerColor: dividerColor,
                    isDarkMode: isDarkMode,
                  )
                : _buildBudgetList(
                    context,
                    header: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isReorderMode)
                          const AppReorderBanner(
                            message:
                                'แตะค้างที่ไอคอนลากเพื่อจัดเรียงลำดับงบประมาณ',
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: MonthlyCycleSelector(
                            selectedMonth: _selectedMonth,
                            onPrevMonth: _prevMonth,
                            onNextMonth: _nextMonth,
                            surfaceColor: surfaceColor,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            dividerColor: dividerColor,
                          ),
                        ),
                        BudgetSummaryHeader(
                          totalBudget: totalBudget,
                          totalSpent: totalSpent,
                          totalAvailable: totalAvailable,
                          totalOverspent: totalOverspent,
                          progress: overallProgress,
                          isDarkMode: isDarkMode,
                          surfaceColor: surfaceColor,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          dividerColor: dividerColor,
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                    budgets: budgets,
                    spentByCategoryId: spentByCategoryId,
                    period: period,
                    totalBudget: totalBudget,
                    budgetProvider: budgetProvider,
                    isDarkMode: isDarkMode,
                    surfaceColor: surfaceColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    dividerColor: dividerColor,
                  ),
          ),
          bottomNavigationBar: null,
        );
      },
    );
  }

  Widget _buildBudgetList(
    BuildContext context, {
    required Widget header,
    required List<Budget> budgets,
    required Map<String, double> spentByCategoryId,
    required DateTimeRange period,
    required double totalBudget,
    required BudgetProvider budgetProvider,
    required bool isDarkMode,
    required Color surfaceColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color dividerColor,
  }) {
    final hasGroups = budgets.any(
      (b) => b.groupName != null && b.groupName!.isNotEmpty,
    );

    // ── No groups → flat ReorderableListView in Inset Grouped Card ─────────
    if (!hasGroups) {
      return ReorderableListView.builder(
        header: header,
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        buildDefaultDragHandles: false,
        onReorderItem: _isReorderMode
            ? (oldIndex, newIndex) =>
                  budgetProvider.reorderBudgets(oldIndex, newIndex)
            : (a, b) {},
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
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(AppRadii.xLarge),
                  child: child,
                ),
              );
            },
            child: child,
          );
        },
        itemCount: budgets.length,
        itemBuilder: (context, i) {
          final budget = budgets[i];
          final spent = BudgetSpendingService.spentFor(
            budget,
            spentByCategoryId,
          );
          final isFirst = i == 0;
          final isLast = i == budgets.length - 1;

          return BudgetItemCard(
            key: ValueKey(budget.id),
            budget: budget,
            spent: spent,
            isReorderMode: _isReorderMode,
            reorderIndex: _isReorderMode ? i : null,
            isFirst: isFirst,
            isLast: isLast,
            showDivider: !isLast,
            isDarkMode: isDarkMode,
            surfaceColor: surfaceColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            dividerColor: dividerColor,
            onTap: () => _openTransactions(context, budget, period),
            onTapEdit: () => openBudgetForm(context, budget),
          );
        },
      );
    }

    // ── Grouped ListView ────────────────────────────────────────────────────
    final Map<String, List<Budget>> namedGroupMap = {};
    final List<Budget> ungrouped = [];

    for (final b in budgets) {
      final g = (b.groupName == null || b.groupName!.isEmpty)
          ? null
          : b.groupName!;
      if (g == null) {
        ungrouped.add(b);
      } else {
        (namedGroupMap[g] ??= []).add(b);
      }
    }

    // Sort named groups by the minimum sortOrder of their members
    final sortedGroups = namedGroupMap.entries.toList()
      ..sort(
        (a, b) => a.value
            .map((x) => x.sortOrder)
            .reduce((x, y) => x < y ? x : y)
            .compareTo(
              b.value.map((x) => x.sortOrder).reduce((x, y) => x < y ? x : y),
            ),
      );

    Widget buildGroupList(List<Budget> groupBudgets, String? groupName) {
      return Theme(
        data: Theme.of(context).copyWith(
          splashFactory: NoSplash.splashFactory,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(AppRadii.xLarge),
            border: Border.all(
              color: dividerColor.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorderItem: _isReorderMode
                ? (oldIndex, newIndex) => budgetProvider.reorderBudgetsInGroup(
                    groupName,
                    oldIndex,
                    newIndex,
                  )
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
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(AppRadii.medium),
                      child: child,
                    ),
                  );
                },
                child: child,
              );
            },
            itemCount: groupBudgets.length,
            itemBuilder: (context, index) {
              final budget = groupBudgets[index];
              final spent = BudgetSpendingService.spentFor(
                budget,
                spentByCategoryId,
              );
              final isLast = index == groupBudgets.length - 1;

              return BudgetItemRow(
                key: ValueKey(budget.id),
                budget: budget,
                spent: spent,
                isReorderMode: _isReorderMode,
                reorderIndex: _isReorderMode ? index : null,
                showDivider: !isLast,
                isDarkMode: isDarkMode,
                surfaceColor: surfaceColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                dividerColor: dividerColor,
                onTap: () => _openTransactions(context, budget, period),
                onTapEdit: () => openBudgetForm(context, budget),
              );
            },
          ),
        ),
      );
    }

    final listHeader = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        if (ungrouped.isNotEmpty) ...[
          AppSectionHeader(
            'งบประมาณทั่วไป',
            padding: EdgeInsets.fromLTRB(20, 10, 20, 4),
          ),
          buildGroupList(ungrouped, null),
          const SizedBox(height: 12),
        ],
      ],
    );

    return ReorderableListView.builder(
      header: listHeader,
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      buildDefaultDragHandles: false,
      onReorderItem: _isReorderMode
          ? budgetProvider.reorderBudgetGroups
          : (_, _) {},
      itemCount: sortedGroups.length,
      itemBuilder: (context, index) {
        final entry = sortedGroups[index];
        final groupBudgets = entry.value;
        final groupTotal = groupBudgets.fold(0.0, (s, b) => s + b.amount);
        final groupPct = totalBudget > 0 ? groupTotal / totalBudget * 100 : 0.0;

        return Column(
          key: ValueKey('group_${entry.key}'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.key.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Text(
                    formatAmount(groupTotal),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: (isDarkMode
                          ? AppColors.darkSurfaceVariant
                          : Colors.black.withValues(alpha: 0.06)),
                      borderRadius: BorderRadius.circular(AppRadii.full),
                    ),
                    child: Text(
                      '${groupPct.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                      ),
                    ),
                  ),
                  if (_isReorderMode)
                    ReorderableDragStartListener(
                      index: index,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Icon(
                          Icons.drag_indicator_rounded,
                          color: dividerColor,
                          size: 20,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            buildGroupList(groupBudgets, entry.key),
            const SizedBox(height: 6),
          ],
        );
      },
    );
  }

  void _openTransactions(
    BuildContext context,
    Budget budget,
    DateTimeRange period,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionListScreen(
          categoryIds: budget.categoryIds,
          fixedDateRange: period,
          monthlyCycleMonth: _selectedMonth,
          title: budget.name,
        ),
      ),
    );
  }
}
