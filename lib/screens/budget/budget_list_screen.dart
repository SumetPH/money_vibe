import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/budget.dart';
import '../../models/transaction.dart';
import '../../providers/budget_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../main.dart';
import '../../widgets/app_drawer.dart';
import '../../screens/transaction/transaction_list_screen.dart';
import 'budget_form_screen.dart';

class BudgetListScreen extends StatefulWidget {
  const BudgetListScreen({super.key});

  @override
  State<BudgetListScreen> createState() => _BudgetListScreenState();
}

class _BudgetListScreenState extends State<BudgetListScreen> {
  bool _isReorderMode = false;
  late DateTime _selectedMonth;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final startDay = context.read<SettingsProvider>().budgetStartDay;
      _selectedMonth = _currentCycleMonth(startDay);
    }
  }

  /// คำนวณว่าวันนี้อยู่ใน cycle ของเดือนไหน
  /// ถ้า startDay=15 และวันนี้=1 มี.ค. → อยู่ใน cycle ก.พ. (15 ก.พ.–14 มี.ค.)
  DateTime _currentCycleMonth(int startDay) {
    final now = DateTime.now();
    if (now.day >= startDay) {
      return DateTime(now.year, now.month);
    } else {
      return DateTime(now.year, now.month - 1);
    }
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
    final y = _selectedMonth.year;
    final m = _selectedMonth.month;
    final clampedStart = startDay.clamp(1, DateUtils.getDaysInMonth(y, m));
    final start = DateTime(y, m, clampedStart);
    final nextMonth = DateTime(y, m + 1, 1);
    final clampedEnd = clampedStart.clamp(
      1,
      DateUtils.getDaysInMonth(nextMonth.year, nextMonth.month),
    );
    final end = DateTime(
      nextMonth.year,
      nextMonth.month,
      clampedEnd,
    ).subtract(const Duration(seconds: 1));
    return DateTimeRange(start: start, end: end);
  }

  double _getSpent(
    Budget budget,
    List<AppTransaction> txs,
    DateTimeRange period,
  ) {
    return txs
        .where(
          (tx) =>
              tx.type.isExpenseLike &&
              budget.categoryIds.contains(tx.categoryId) &&
              !tx.dateTime.isBefore(period.start) &&
              !tx.dateTime.isAfter(period.end),
        )
        .fold(0.0, (sum, tx) => sum + tx.amount);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<BudgetProvider, TransactionProvider, SettingsProvider>(
      builder: (context, budgetProvider, txProvider, settingsProvider, _) {
        final isDarkMode = settingsProvider.isDarkMode;
        final startDay = settingsProvider.budgetStartDay;
        final period = _getBudgetPeriod(startDay);
        final allTx = txProvider.transactions;
        final budgets = budgetProvider.budgets;

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

        // Summary
        final totalBudget = budgets.fold(0.0, (s, b) => s + b.amount);
        final totalSpent = budgets.fold(
          0.0,
          (s, b) => s + _getSpent(b, allTx, period),
        );
        final totalRemaining = totalBudget - totalSpent;
        final overallProgress = totalBudget > 0
            ? (totalSpent / totalBudget).clamp(0.0, 1.0)
            : 0.0;

        return Scaffold(
          backgroundColor: bgColor,
          drawer: const AppDrawer(currentRoute: '/budgets'),
          appBar: AppBar(
            leading: Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
            title: const Text('งบประมาณ'),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.more_horiz),
                onPressed: () => _showMenuBottomSheet(context, isDarkMode),
              ),
            ],
          ),
          body: SafeArea(
            child: budgets.isEmpty
                ? Center(
                    child: Text(
                      'ยังไม่มีงบประมาณ',
                      style: TextStyle(color: textSecondary),
                    ),
                  )
                : Column(
                    children: [
                      // ── Month selector ──────────────────────────────────────
                      _MonthSelector(
                        selectedMonth: _selectedMonth,
                        onPrevMonth: _prevMonth,
                        onNextMonth: _nextMonth,
                        isDarkMode: isDarkMode,
                        surfaceColor: surfaceColor,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                      // ── Header summary ──────────────────────────────────────
                      _SummaryHeader(
                        totalBudget: totalBudget,
                        totalSpent: totalSpent,
                        totalRemaining: totalRemaining,
                        progress: overallProgress,
                        isDarkMode: isDarkMode,
                        surfaceColor: surfaceColor,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        dividerColor: dividerColor,
                      ),
                      // ── Budget list ─────────────────────────────────────────
                      Expanded(
                        child: ReorderableListView.builder(
                          buildDefaultDragHandles: _isReorderMode,
                          onReorder: _isReorderMode
                              ? (oldIndex, newIndex) {
                                  budgetProvider.reorderBudgets(
                                    oldIndex,
                                    newIndex,
                                  );
                                }
                              : (oldIdx, newIdx) {},
                          proxyDecorator: (child, index, animation) {
                            return AnimatedBuilder(
                              animation: animation,
                              builder: (context, child) {
                                final animValue = Curves.easeInOut.transform(
                                  animation.value,
                                );
                                final elevation = 1 + animValue * 8;
                                final scale = 1 + animValue * 0.02;
                                return Transform.scale(
                                  scale: scale,
                                  child: Material(
                                    elevation: elevation,
                                    color: surfaceColor,
                                    borderRadius: BorderRadius.circular(8),
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
                            final spent = _getSpent(budget, allTx, period);
                            return _BudgetItem(
                              key: ValueKey(budget.id),
                              budget: budget,
                              spent: spent,
                              isReorderMode: _isReorderMode,
                              isDarkMode: isDarkMode,
                              surfaceColor: surfaceColor,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                              dividerColor: dividerColor,
                              onTap: () =>
                                  _openTransactions(context, budget, period),
                              onLongPress: () => _openForm(context, budget),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
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
          title: budget.name,
        ),
      ),
    );
  }

  void _showMenuBottomSheet(BuildContext context, bool isDarkMode) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? AppColors.darkSurface : Colors.white,
      builder: (_) => Consumer<SettingsProvider>(
        builder: (context, settingsProvider, _) {
          final isDark = settingsProvider.isDarkMode;
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
                    'เพิ่มงบประมาณ',
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
                    onChanged: (v) {
                      setState(() => _isReorderMode = v);
                      Navigator.pop(context);
                    },
                  ),
                  onTap: () {
                    setState(() => _isReorderMode = !_isReorderMode);
                    Navigator.pop(context);
                  },
                ),
                Divider(height: 1, color: dividerColor),
                ListTile(
                  tileColor: bgColor,
                  leading: Icon(
                    Icons.calendar_today_outlined,
                    color: textColor,
                  ),
                  title: Text(
                    'ตั้งค่ารอบงบประมาณ',
                    style: TextStyle(color: textColor),
                  ),
                  subtitle: Text(
                    'เริ่มนับวันที่ ${settingsProvider.budgetStartDay} ของเดือน',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showStartDayPicker(context, settingsProvider);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showStartDayPicker(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Consumer<SettingsProvider>(
        builder: (context, sp, _) {
          final isDark = sp.isDarkMode;
          final bgColor = isDark ? AppColors.darkSurface : Colors.white;
          final handleColor = isDark
              ? AppColors.darkDivider
              : Colors.grey.shade300;
          final textPrimary = isDark
              ? AppColors.darkTextPrimary
              : AppColors.textPrimary;
          final selectedColor = isDark
              ? AppColors.darkIncome
              : AppColors.header;

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
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'วันเริ่มต้นรอบงบประมาณ',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 1,
                        ),
                    itemCount: 31,
                    itemBuilder: (_, i) {
                      final day = i + 1;
                      final selected = sp.budgetStartDay == day;
                      return GestureDetector(
                        onTap: () {
                          sp.setBudgetStartDay(day);
                          Navigator.pop(context);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: selected ? selectedColor : bgColor,
                            borderRadius: BorderRadius.circular(8),
                            border: selected
                                ? null
                                : Border.all(
                                    color: isDark
                                        ? AppColors.darkDivider
                                        : AppColors.divider,
                                  ),
                          ),
                          child: Center(
                            child: Text(
                              '$day',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                                color: selected ? Colors.white : textPrimary,
                              ),
                            ),
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
}

// ── Month Selector ─────────────────────────────────────────────────────────────

class _MonthSelector extends StatelessWidget {
  final DateTime selectedMonth;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final bool isDarkMode;
  final Color surfaceColor;
  final Color textPrimary;
  final Color textSecondary;

  const _MonthSelector({
    required this.selectedMonth,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.isDarkMode,
    required this.surfaceColor,
    required this.textPrimary,
    required this.textSecondary,
  });

  String _getPeriodLabel(BuildContext context) {
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
    final startDay = context.read<SettingsProvider>().budgetStartDay;
    final y = selectedMonth.year;
    final m = selectedMonth.month;
    final clampedStart = startDay.clamp(1, DateUtils.getDaysInMonth(y, m));
    final nextMonth = DateTime(y, m + 1, clampedStart - 1);

    final clampedEnd = nextMonth.day;
    final startMonth = thaiMonths[m - 1];
    final endMonth = thaiMonths[nextMonth.month - 1];
    return '$clampedStart $startMonth - $clampedEnd $endMonth $y';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: surfaceColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 22),
            onPressed: onPrevMonth,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          const SizedBox(width: 8),
          Text(
            _getPeriodLabel(context),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 22),
            onPressed: onNextMonth,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

// ── Summary Header ──────────────────────────────────────────────────────────

class _SummaryHeader extends StatelessWidget {
  final double totalBudget;
  final double totalSpent;
  final double totalRemaining;
  final double progress;
  final bool isDarkMode;
  final Color surfaceColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color dividerColor;

  const _SummaryHeader({
    required this.totalBudget,
    required this.totalSpent,
    required this.totalRemaining,
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
    return Container(
      color: surfaceColor,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _SummaryCell(
                  label: 'งบทั้งหมด',
                  amount: totalBudget,
                  color: textPrimary,
                  textSecondary: textSecondary,
                ),
              ),
              Container(width: 1, height: 40, color: dividerColor),
              Expanded(
                child: _SummaryCell(
                  label: 'ใช้ไปแล้ว',
                  amount: totalSpent,
                  color: isDarkMode ? AppColors.darkExpense : AppColors.expense,
                  textSecondary: textSecondary,
                ),
              ),
              Container(width: 1, height: 40, color: dividerColor),
              Expanded(
                child: _SummaryCell(
                  label: 'คงเหลือ',
                  amount: totalRemaining,
                  color: totalRemaining >= 0
                      ? (isDarkMode ? AppColors.darkIncome : AppColors.income)
                      : (isDarkMode
                            ? AppColors.darkExpense
                            : AppColors.expense),
                  textSecondary: textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: isDarkMode
                  ? AppColors.darkDivider
                  : AppColors.divider,
              valueColor: AlwaysStoppedAnimation<Color>(_progressColor),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(progress * 100).toStringAsFixed(1)}% ของงบประมาณ',
            style: TextStyle(fontSize: 12, color: textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final Color textSecondary;

  const _SummaryCell({
    required this.label,
    required this.amount,
    required this.color,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: textSecondary)),
        const SizedBox(height: 4),
        Text(
          formatAmount(amount),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ── Budget Item ─────────────────────────────────────────────────────────────

class _BudgetItem extends StatelessWidget {
  final Budget budget;
  final double spent;
  final bool isReorderMode;
  final bool isDarkMode;
  final Color surfaceColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color dividerColor;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _BudgetItem({
    super.key,
    required this.budget,
    required this.spent,
    required this.isReorderMode,
    required this.isDarkMode,
    required this.surfaceColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.dividerColor,
    required this.onTap,
    required this.onLongPress,
  });

  double get _progress =>
      budget.amount > 0 ? (spent / budget.amount).clamp(0.0, 1.0) : 0.0;

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
      children: [
        InkWell(
          onTap: isReorderMode ? null : onTap,
          onLongPress: isReorderMode ? null : onLongPress,
          child: Container(
            color: surfaceColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (isReorderMode) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: 8),
                    child: Icon(
                      Icons.drag_indicator,
                      color: dividerColor,
                      size: 20,
                    ),
                  ),
                ],
                // Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: budget.color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(budget.icon, color: budget.color, size: 22),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
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
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              formatAmount(budget.amount),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'ใช้ ${formatAmount(spent)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 104,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${(_progress * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _progressColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _progress,
                                minHeight: 6,
                                backgroundColor: isDarkMode
                                    ? AppColors.darkDivider
                                    : AppColors.divider,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _progressColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${_remaining >= -0.001 ? 'เหลือ' : 'เกิน'} ${formatAmount(_remaining)}',
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
                      ),
                    ],
                  ),
                ),
                if (!isReorderMode) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right, color: textSecondary, size: 20),
                ],
              ],
            ),
          ),
        ),
        Divider(height: 1, color: dividerColor),
      ],
    );
  }
}
