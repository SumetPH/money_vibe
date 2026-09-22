import 'package:flutter/cupertino.dart' show CupertinoSwitch;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/budget.dart';
import '../../models/transaction.dart';
import '../../models/account.dart';
import '../../providers/budget_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../main.dart';
import '../../providers/sync_provider.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_modal_bottom_sheet.dart';
import '../../widgets/monthly_cycle_selector.dart';
import '../../utils/monthly_cycle.dart';
import '../../screens/transaction/transaction_list_screen.dart';
import 'budget_form_screen.dart';

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
    if (!widget.showPrimaryNavigation) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<SyncProvider>().checkAndSync();
      }
    });
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

  Map<String, double> _buildSpentByCategoryId(
    List<AppTransaction> txs,
    DateTimeRange period,
    List<Account> accounts,
  ) {
    final spentByCategoryId = <String, double>{};

    for (final tx in txs) {
      if (tx.dateTime.isBefore(period.start) ||
          tx.dateTime.isAfter(period.end)) {
        continue;
      }
      if (!TransactionProvider.isActualExpense(tx, accounts)) continue;

      final categoryId = tx.categoryId;
      if (categoryId == null) continue;

      spentByCategoryId[categoryId] =
          (spentByCategoryId[categoryId] ?? 0.0) + tx.amount;
    }

    return spentByCategoryId;
  }

  double _getSpentFromCategoryTotals(
    Budget budget,
    Map<String, double> spentByCategoryId,
  ) {
    var spent = 0.0;
    for (final categoryId in budget.categoryIds) {
      spent += spentByCategoryId[categoryId] ?? 0.0;
    }
    return spent;
  }

  List<_BudgetGroupSummary> _buildGroupSummaries({
    required List<Budget> budgets,
    required Map<String, double> spentByCategoryId,
    required double totalBudget,
  }) {
    final Map<String, List<Budget>> groupedBudgets = {};

    for (final budget in budgets) {
      final rawGroupName = budget.groupName?.trim();
      final groupName = (rawGroupName == null || rawGroupName.isEmpty)
          ? 'ไม่มีกลุ่ม'
          : rawGroupName;
      (groupedBudgets[groupName] ??= []).add(budget);
    }

    final sortedGroups = groupedBudgets.entries.toList()
      ..sort(
        (a, b) => a.value
            .map((budget) => budget.sortOrder)
            .reduce((min, value) => min < value ? min : value)
            .compareTo(
              b.value
                  .map((budget) => budget.sortOrder)
                  .reduce((min, value) => min < value ? min : value),
            ),
      );

    return sortedGroups.map((entry) {
      var total = 0.0;
      var spent = 0.0;
      var available = 0.0;
      var overspent = 0.0;

      for (final budget in entry.value) {
        final budgetSpent = _getSpentFromCategoryTotals(
          budget,
          spentByCategoryId,
        );
        final remaining = budget.amount - budgetSpent;
        total += budget.amount;
        spent += budgetSpent;
        if (remaining >= 0) {
          available += remaining;
        } else {
          overspent += remaining.abs();
        }
      }

      return _BudgetGroupSummary(
        name: entry.key,
        percentage: totalBudget > 0 ? (total / totalBudget) * 100 : 0.0,
        total: total,
        spent: spent,
        available: available,
        overspent: overspent,
      );
    }).toList();
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
        final incomeColor = isDarkMode
            ? AppColors.darkIncome
            : AppColors.income;

        // Summary calculations
        final spentByCategoryId = _buildSpentByCategoryId(
          allTx,
          period,
          accounts,
        );
        var totalBudget = 0.0;
        var totalSpent = 0.0;
        var totalAvailable = 0.0;
        var totalOverspent = 0.0;
        for (final budget in budgets) {
          final spent = _getSpentFromCategoryTotals(budget, spentByCategoryId);
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
        final groupSummaries = _buildGroupSummaries(
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
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    child: Material(
                      color: incomeColor,
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
                Material(
                  color: surfaceColor,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: IconButton(
                    icon: const Icon(Icons.pie_chart_outline_rounded),
                    color: textPrimary,
                    tooltip: 'รายละเอียดกลุ่มงบประมาณ',
                    onPressed: () => _showGroupDetailsBottomSheet(
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
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: IconButton(
                      icon: const Icon(Icons.more_horiz_rounded),
                      color: textPrimary,
                      tooltip: 'ตัวเลือกเพิ่มเติม',
                      onPressed: () =>
                          _showMenuBottomSheet(context, isDarkMode),
                    ),
                  ),
                ),
              ],
            ],
          ),
          body: SafeArea(
            child: budgets.isEmpty
                ? _buildEmptyState(
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
                          _buildReorderBanner(isDarkMode, incomeColor),
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
                        _SummaryHeader(
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

  Widget _buildReorderBanner(bool isDarkMode, Color incomeColor) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: incomeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.large),
        border: Border.all(color: incomeColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: incomeColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'โหมดจัดเรียงลำดับ: ลากที่ไอคอนจัดเรียงเพื่อสลับตำแหน่งงบประมาณ',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: incomeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required Color surfaceColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color dividerColor,
    required bool isDarkMode,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(AppRadii.xLarge),
            border: Border.all(color: dividerColor.withValues(alpha: 0.35)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color:
                      (isDarkMode
                              ? AppColors.darkFabYellow
                              : AppColors.fabYellow)
                          .withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.savings_outlined,
                  size: 32,
                  color: isDarkMode
                      ? AppColors.darkFabYellow
                      : AppColors.fabYellow,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'ยังไม่มีงบประมาณ',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'เริ่มต้นวางแผนการเงินและควบคุมรายจ่าย\nโดยสร้างงบประมาณแรกของคุณ',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: isDarkMode
                      ? AppColors.darkFabYellow
                      : AppColors.fabYellow,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.full),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 11,
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  'เพิ่มงบประมาณ',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                onPressed: () => _openForm(context, null),
              ),
            ],
          ),
        ),
      ),
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
          final spent = _getSpentFromCategoryTotals(budget, spentByCategoryId);
          final isFirst = i == 0;
          final isLast = i == budgets.length - 1;

          return _BudgetItemCard(
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
            onTapEdit: () => _openForm(context, budget),
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
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
            final spent = _getSpentFromCategoryTotals(
              budget,
              spentByCategoryId,
            );
            final isLast = index == groupBudgets.length - 1;

            return _BudgetItemRow(
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
              onTapEdit: () => _openForm(context, budget),
            );
          },
        ),
      );
    }

    final listHeader = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        if (ungrouped.isNotEmpty) ...[
          _buildSectionHeader('งบประมาณทั่วไป', textSecondary),
          buildGroupList(ungrouped, null),
          const SizedBox(height: 12),
        ],
      ],
    );

    return ReorderableListView.builder(
      header: listHeader,
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

  Widget _buildSectionHeader(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, top: 10, bottom: 4),
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

  void _openForm(BuildContext context, Budget? budget) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BudgetFormScreen(budget: budget)),
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

  void _showMenuBottomSheet(BuildContext context, bool isDarkMode) {
    showAppModalBottomSheet(
      context: context,
      builder: (_) => Consumer2<SettingsProvider, BudgetProvider>(
        builder: (context, settingsProvider, budgetProvider, _) {
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
          final incomeColor = isDark ? AppColors.darkIncome : AppColors.income;
          final yellowColor = isDark
              ? AppColors.darkFabYellow
              : AppColors.fabYellow;

          return StatefulBuilder(
            builder: (context, setStateModal) {
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppModalBottomSheetHeader(
                        title: 'ตัวเลือกงบประมาณ',
                      ),
                      const SizedBox(height: 8),
                      Material(
                        color: isDark
                            ? AppColors.darkSurfaceVariant
                            : AppColors.surface,
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
                                  color: yellowColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.medium,
                                  ),
                                ),
                                child: Icon(
                                  Icons.add_rounded,
                                  color: yellowColor,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                'เพิ่มงบประมาณ',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                'ตั้งเป้างบประมาณรายจ่ายตามหมวดหมู่',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: Icon(
                                Icons.chevron_right_rounded,
                                color: textSecondary.withValues(alpha: 0.5),
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
                                  color: incomeColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.medium,
                                  ),
                                ),
                                child: Icon(
                                  Icons.reorder_rounded,
                                  color: incomeColor,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                'จัดเรียงลำดับ',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                'เปิดโหมดลากสลับตำแหน่งงบประมาณ',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: CupertinoSwitch(
                                value: _isReorderMode,
                                activeTrackColor: incomeColor,
                                inactiveTrackColor: isDark
                                    ? const Color(0xFF39393D)
                                    : const Color(0xFFE9E9EA),
                                onChanged: (v) {
                                  setStateModal(() => _isReorderMode = v);
                                  setState(() => _isReorderMode = v);
                                },
                              ),
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
                                  color: textColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.medium,
                                  ),
                                ),
                                child: Icon(
                                  Icons.visibility_outlined,
                                  color: textColor,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                'แสดงงบประมาณที่ซ่อน',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                'แสดงงบประมาณที่ถูกตั้งค่าซ่อนไว้',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: CupertinoSwitch(
                                value: budgetProvider.showHiddenBudgets,
                                activeTrackColor: incomeColor,
                                inactiveTrackColor: isDark
                                    ? const Color(0xFF39393D)
                                    : const Color(0xFFE9E9EA),
                                onChanged: (_) {
                                  budgetProvider.toggleShowHiddenBudgets();
                                  setStateModal(() {});
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

  void _showGroupDetailsBottomSheet(
    BuildContext context,
    List<_BudgetGroupSummary> groupSummaries,
    String periodLabel,
    double totalBudget,
    double totalSpent,
    double totalAvailable,
    double totalOverspent,
    double overallProgress,
    bool isDarkMode,
  ) {
    showAppModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BudgetGroupDetailsSheet(
        groupSummaries: groupSummaries,
        periodLabel: periodLabel,
        totalBudget: totalBudget,
        totalSpent: totalSpent,
        totalAvailable: totalAvailable,
        totalOverspent: totalOverspent,
        overallProgress: overallProgress,
        isDarkMode: isDarkMode,
      ),
    );
  }
}

// ── Summary Header (Inset Grouped Card & Metric Grid) ──────────────────────────

class _SummaryHeader extends StatelessWidget {
  final double totalBudget;
  final double totalSpent;
  final double totalAvailable;
  final double totalOverspent;
  final double progress;
  final bool isDarkMode;
  final Color surfaceColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color dividerColor;

  const _SummaryHeader({
    required this.totalBudget,
    required this.totalSpent,
    required this.totalAvailable,
    required this.totalOverspent,
    required this.progress,
    required this.isDarkMode,
    required this.surfaceColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.dividerColor,
  });

  Color get _progressColor {
    if (progress >= 1.0) {
      return isDarkMode ? AppColors.darkExpense : AppColors.expense;
    }
    if (progress >= 0.8) return Colors.orange;
    return isDarkMode ? AppColors.darkIncome : AppColors.income;
  }

  @override
  Widget build(BuildContext context) {
    final hasOverspent = totalOverspent > 0.001;
    final statusBgColor = hasOverspent
        ? (isDarkMode ? AppColors.darkExpense : AppColors.expense).withValues(
            alpha: 0.12,
          )
        : progress >= 0.8
        ? Colors.orange.withValues(alpha: 0.12)
        : (isDarkMode ? AppColors.darkIncome : AppColors.income).withValues(
            alpha: 0.12,
          );

    final statusTextColor = hasOverspent
        ? (isDarkMode ? AppColors.darkExpense : AppColors.expense)
        : progress >= 0.8
        ? Colors.orange
        : (isDarkMode ? AppColors.darkIncome : AppColors.income);

    final statusLabel = hasOverspent
        ? 'เกินงบรวม'
        : progress >= 0.8
        ? 'ใกล้เต็มงบ'
        : 'ปกติ';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppRadii.xLarge),
        border: Border.all(
          color: dividerColor.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Status Capsule
          Row(
            children: [
              Text(
                'สรุปงบประมาณ',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(AppRadii.full),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasOverspent
                          ? Icons.error_outline_rounded
                          : progress >= 0.8
                          ? Icons.timelapse_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 13,
                      color: statusTextColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: statusTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Structured Metric Grid
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.large),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: 'งบทั้งหมด',
                    value: formatAmount(totalBudget),
                    textColor: textPrimary,
                    secondaryColor: textSecondary,
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: dividerColor.withValues(alpha: 0.4),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: _MetricTile(
                      label: 'ใช้ไปแล้ว',
                      value: formatAmount(totalSpent),
                      textColor: isDarkMode
                          ? AppColors.darkExpense
                          : AppColors.expense,
                      secondaryColor: textSecondary,
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: dividerColor.withValues(alpha: 0.4),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: _MetricTile(
                      label: 'ยังใช้ได้',
                      value: formatAmount(totalAvailable),
                      textColor: isDarkMode
                          ? AppColors.darkIncome
                          : AppColors.income,
                      secondaryColor: textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Overspent alert row if applicable
          if (hasOverspent) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (isDarkMode ? AppColors.darkExpense : AppColors.expense)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadii.medium),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 15,
                    color: isDarkMode
                        ? AppColors.darkExpense
                        : AppColors.expense,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'เกินงบรวม ${formatAmount(totalOverspent)} บาท',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDarkMode
                          ? AppColors.darkExpense
                          : AppColors.expense,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          // iOS Progress Bar
          _BudgetProgressBar(
            progress: progress,
            color: _progressColor,
            backgroundColor: isDarkMode
                ? AppColors.darkDivider.withValues(alpha: 0.6)
                : AppColors.divider.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ใช้ไป ${(progress * 100).toStringAsFixed(1)}% ของงบประมาณ',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: textSecondary,
                ),
              ),
              Text(
                hasOverspent
                    ? 'เกินเป้า'
                    : 'เหลือ ${formatAmount(totalAvailable)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: hasOverspent
                      ? (isDarkMode ? AppColors.darkExpense : AppColors.expense)
                      : (isDarkMode ? AppColors.darkIncome : AppColors.income),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color textColor;
  final Color secondaryColor;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.textColor,
    required this.secondaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: secondaryColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ],
    );
  }
}

// ── Budget Item Card (For flat list without groups) ──────────────────────────

class _BudgetItemCard extends StatelessWidget {
  final Budget budget;
  final double spent;
  final bool isReorderMode;
  final int? reorderIndex;
  final bool isFirst;
  final bool isLast;
  final bool showDivider;
  final bool isDarkMode;
  final Color surfaceColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color dividerColor;
  final VoidCallback onTap;
  final VoidCallback onTapEdit;

  const _BudgetItemCard({
    super.key,
    required this.budget,
    required this.spent,
    required this.isReorderMode,
    this.reorderIndex,
    required this.isFirst,
    required this.isLast,
    required this.showDivider,
    required this.isDarkMode,
    required this.surfaceColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.dividerColor,
    required this.onTap,
    required this.onTapEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppRadii.xLarge),
        border: Border.all(
          color: dividerColor.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: _BudgetItemRow(
        budget: budget,
        spent: spent,
        isReorderMode: isReorderMode,
        reorderIndex: reorderIndex,
        showDivider: false,
        isDarkMode: isDarkMode,
        surfaceColor: surfaceColor,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        dividerColor: dividerColor,
        onTap: onTap,
        onTapEdit: onTapEdit,
      ),
    );
  }
}

// ── Budget Item Row (Shared between grouped and flat lists) ───────────────────

class _BudgetItemRow extends StatelessWidget {
  final Budget budget;
  final double spent;
  final bool isReorderMode;
  final int? reorderIndex;
  final bool showDivider;
  final bool isDarkMode;
  final Color surfaceColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color dividerColor;
  final VoidCallback onTap;
  final VoidCallback onTapEdit;

  const _BudgetItemRow({
    super.key,
    required this.budget,
    required this.spent,
    required this.isReorderMode,
    this.reorderIndex,
    required this.showDivider,
    required this.isDarkMode,
    required this.surfaceColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.dividerColor,
    required this.onTap,
    required this.onTapEdit,
  });

  double get _progress => budget.amount > 0 ? (spent / budget.amount) : 0.0;
  double get _remaining => budget.amount - spent;
  bool get _isRemainingNeutral => _remaining.abs() <= 0.001;

  Color get _progressColor {
    if (_progress >= 1.0) {
      return isDarkMode ? AppColors.darkExpense : AppColors.expense;
    }
    if (_progress >= 0.8) return Colors.orange;
    return isDarkMode ? AppColors.darkIncome : AppColors.income;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isReorderMode || budget.type == BudgetType.savings
                ? null
                : onTap,
            onLongPress: isReorderMode ? null : () => _showBudgetMenu(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Reorder Handle if active
                  if (reorderIndex != null) ...[
                    ReorderableDragStartListener(
                      index: reorderIndex!,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Icon(
                          Icons.drag_indicator_rounded,
                          color: dividerColor,
                          size: 20,
                        ),
                      ),
                    ),
                  ],

                  // Squircle Avatar
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: budget.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadii.large),
                    ),
                    child: Icon(budget.icon, color: budget.color, size: 22),
                  ),
                  const SizedBox(width: 12),

                  // Title & Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                budget.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                            ),
                            if (budget.isHidden) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.small,
                                  ),
                                ),
                                child: Text(
                                  'ซ่อน',
                                  style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          budget.type == BudgetType.savings
                              ? 'เป้าหมาย: ${formatAmount(budget.amount)}'
                              : 'งบ ${formatAmount(budget.amount)} · ใช้ ${formatAmount(spent)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Right side: Savings capsule OR Expense metrics
                  if (budget.type == BudgetType.savings) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (isDarkMode
                                    ? AppColors.darkIncome
                                    : AppColors.income)
                                .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadii.full),
                      ),
                      child: Text(
                        'แผนออม',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDarkMode
                              ? AppColors.darkIncome
                              : AppColors.income,
                        ),
                      ),
                    ),
                  ] else ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${(_progress * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _progressColor,
                              ),
                            ),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 80,
                              child: _BudgetProgressBar(
                                progress: _progress,
                                color: _progressColor,
                                backgroundColor: isDarkMode
                                    ? AppColors.darkDivider
                                    : AppColors.divider,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_remaining >= -0.001 ? 'เหลือ' : 'เกิน'} ${formatAmount(_remaining.abs())}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _isRemainingNeutral
                                ? textPrimary
                                : _remaining > 0
                                ? (isDarkMode
                                      ? AppColors.darkIncome
                                      : AppColors.income)
                                : (isDarkMode
                                      ? AppColors.darkExpense
                                      : AppColors.expense),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(height: 1, color: AppColors.listDividerFor(isDarkMode)),
      ],
    );
  }

  void _showBudgetMenu(BuildContext context) {
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
          final incomeColor = isDark ? AppColors.darkIncome : AppColors.income;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppModalBottomSheetHeader(title: budget.name),
                  const SizedBox(height: 8),
                  Material(
                    color: isDark
                        ? AppColors.darkSurfaceVariant
                        : AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.xLarge),
                      side: BorderSide(
                        color: dividerColor.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: incomeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadii.medium),
                        ),
                        child: Icon(
                          Icons.edit_rounded,
                          color: incomeColor,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        'แก้ไขงบประมาณ',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'เปลี่ยนยอด จำนวนเงิน หรือการตั้งค่าของงบประมาณ',
                        style: TextStyle(color: textSecondary, fontSize: 12),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: textSecondary.withValues(alpha: 0.5),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        onTapEdit();
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
}

class _BudgetGroupSummary {
  final String name;
  final double percentage;
  final double total;
  final double spent;
  final double available;
  final double overspent;

  const _BudgetGroupSummary({
    required this.name,
    required this.percentage,
    required this.total,
    required this.spent,
    required this.available,
    required this.overspent,
  });
}

class _BudgetGroupDetailsSheet extends StatelessWidget {
  final List<_BudgetGroupSummary> groupSummaries;
  final String periodLabel;
  final double totalBudget;
  final double totalSpent;
  final double totalAvailable;
  final double totalOverspent;
  final double overallProgress;
  final bool isDarkMode;

  const _BudgetGroupDetailsSheet({
    required this.groupSummaries,
    required this.periodLabel,
    required this.totalBudget,
    required this.totalSpent,
    required this.totalAvailable,
    required this.totalOverspent,
    required this.overallProgress,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final textPrimary = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final textSecondary = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.88,
      child: Column(
        children: [
          AppModalBottomSheetHeader(title: 'รายละเอียดกลุ่มงบประมาณ'),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? AppColors.darkSurfaceVariant
                    : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppRadii.full),
              ),
              child: Text(
                periodLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
            ),
          ),
          _SummaryHeader(
            totalBudget: totalBudget,
            totalSpent: totalSpent,
            totalAvailable: totalAvailable,
            totalOverspent: totalOverspent,
            progress: overallProgress,
            isDarkMode: isDarkMode,
            surfaceColor: bgColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            dividerColor: dividerColor,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: groupSummaries.isEmpty
                ? Center(
                    child: Text(
                      'ยังไม่มีกลุ่มงบประมาณ',
                      style: TextStyle(color: textSecondary),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    itemCount: groupSummaries.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final summary = groupSummaries[index];
                      final percentageBgColor = isDarkMode
                          ? AppColors.darkSurfaceVariant
                          : AppColors.header.withValues(alpha: 0.12);
                      final percentageTextColor = isDarkMode
                          ? AppColors.darkTextPrimary
                          : AppColors.header;

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(AppRadii.xLarge),
                          border: Border.all(
                            color: dividerColor.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    summary.name,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: percentageBgColor,
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.full,
                                    ),
                                  ),
                                  child: Text(
                                    '${summary.percentage.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: percentageTextColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _GroupDetailMetric(
                                    label: 'ยอดรวม',
                                    value: formatAmount(summary.total),
                                    valueColor: textPrimary,
                                    textSecondary: textSecondary,
                                    alignment: CrossAxisAlignment.start,
                                  ),
                                ),
                                Expanded(
                                  child: _GroupDetailMetric(
                                    label: 'ยอดที่ใช้ไป',
                                    value: formatAmount(summary.spent),
                                    valueColor: isDarkMode
                                        ? AppColors.darkExpense
                                        : AppColors.expense,
                                    textSecondary: textSecondary,
                                    alignment: CrossAxisAlignment.center,
                                  ),
                                ),
                                Expanded(
                                  child: _GroupDetailMetric(
                                    label: 'ยังใช้ได้',
                                    value: formatAmount(summary.available),
                                    valueColor: isDarkMode
                                        ? AppColors.darkIncome
                                        : AppColors.income,
                                    textSecondary: textSecondary,
                                    alignment: CrossAxisAlignment.end,
                                  ),
                                ),
                              ],
                            ),
                            if (summary.overspent > 0.001) ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Icon(
                                    Icons.error_outline_rounded,
                                    size: 14,
                                    color: isDarkMode
                                        ? AppColors.darkExpense
                                        : AppColors.expense,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'เกินงบ ${formatAmount(summary.overspent)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isDarkMode
                                          ? AppColors.darkExpense
                                          : AppColors.expense,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _GroupDetailMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final Color textSecondary;
  final CrossAxisAlignment alignment;

  const _GroupDetailMetric({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.textSecondary,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _BudgetProgressBar extends StatelessWidget {
  final double progress;
  final Color color;
  final Color backgroundColor;

  const _BudgetProgressBar({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedProgress = progress.isFinite ? progress : 0.0;
    final baseProgress = normalizedProgress.clamp(0.0, 1.0);
    final overflowProgress = (normalizedProgress - 1.0).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.full),
      child: SizedBox(
        height: 6,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: backgroundColor),
            if (baseProgress > 0)
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: baseProgress,
                child: ColoredBox(color: color),
              ),
            if (overflowProgress > 0)
              FractionallySizedBox(
                alignment: Alignment.centerRight,
                widthFactor: overflowProgress,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: 0.25),
                        color.withValues(alpha: 0.7),
                      ],
                      stops: const [0.0, 1.0],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
