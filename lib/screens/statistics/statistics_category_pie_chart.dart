import '../../widgets/app_inset_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/transaction.dart';
import '../../models/category.dart';
import '../../models/account.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../main.dart';
import '../transaction/transaction_list_screen.dart';
import 'statistics_models.dart';

class StatisticsCategoryPieChart extends StatelessWidget {
  final CategoryType type;

  const StatisticsCategoryPieChart({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    return Consumer4<
      TransactionProvider,
      CategoryProvider,
      AccountProvider,
      SettingsProvider
    >(
      builder: (context, txProvider, catProvider, accountProvider, settingsProvider, _) {
        final isDarkMode = settingsProvider.isDarkMode;
        final textColor = isDarkMode
            ? AppColors.darkTextPrimary
            : AppColors.textPrimary;
        final secondaryColor = isDarkMode
            ? AppColors.darkTextSecondary
            : AppColors.textSecondary;
        final categoryData = _calculateCategoryData(
          txProvider.transactions,
          catProvider.categories,
          type,
          accountProvider.accounts,
        );

        final total = categoryData.fold<double>(
          0,
          (sum, item) => sum + item.amount,
        );

        final color = type == CategoryType.income
            ? (isDarkMode ? AppColors.darkIncome : AppColors.income)
            : (isDarkMode ? AppColors.darkExpense : AppColors.expense);

        if (categoryData.isEmpty) {
          return Center(
            child: Text(
              'ไม่มีข้อมูล${type == CategoryType.income ? 'รายรับ' : 'รายจ่าย'}',
              style: TextStyle(
                color: isDarkMode
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppInsetCard(
                margin: AppInsetCard.stackedMargin,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${type == CategoryType.income ? 'รายรับ' : 'รายจ่าย'}รวมทั้งหมด',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: secondaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          formatAmount(total),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              AppInsetCard(
                margin: AppInsetCard.stackedMargin,
                children: [
                  SizedBox(
                    height: 220,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 16,
                          sections: categoryData.map((data) {
                            final percentage = total > 0
                                ? (data.amount / total) * 100
                                : 0.0;
                            final showLabel = percentage >= 4;
                            return PieChartSectionData(
                              color: data.color,
                              value: data.amount,
                              title: '',
                              radius: 52,
                              badgeWidget: showLabel
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDarkMode
                                            ? AppColors.darkSurface
                                            : AppColors.surface,
                                        borderRadius: BorderRadius.circular(
                                          AppRadii.small,
                                        ),
                                        border: Border.all(
                                          color: data.color,
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            data.icon,
                                            color: data.color,
                                            size: 11,
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            '${percentage.toStringAsFixed(0)}%',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: data.color,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : null,
                              badgePositionPercentageOffset: 1.50,
                            );
                          }).toList(),
                          pieTouchData: PieTouchData(
                            enabled: true,
                            touchCallback:
                                (FlTouchEvent event, pieTouchResponse) {},
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'แยกตามหมวดหมู่',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: textColor,
                    ),
                  ),
                ),
              ),
              AppInsetCard(
                margin: AppInsetCard.stackedMargin,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: categoryData.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        color: AppColors.listDividerFor(isDarkMode),
                      ),
                      itemBuilder: (context, index) {
                        final data = categoryData[index];
                        final percentage = total > 0
                            ? (data.amount / total) * 100
                            : 0.0;
                        return StatisticsCategoryListItem(
                          data: data,
                          percentage: percentage.toDouble(),
                          isDarkMode: isDarkMode,
                          onTap: () => _openCategoryTransactions(context, data),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  List<StatisticsCategoryData> _calculateCategoryData(
    List<AppTransaction> transactions,
    List<Category> categories,
    CategoryType type,
    List<Account> accounts,
  ) {
    final Map<String, double> categoryAmounts = {};
    final Map<String, List<String>> categoryTransactionIds = {};

    for (final tx in transactions) {
      final isIncome = tx.type == TransactionType.income;
      final shouldInclude = type == CategoryType.income
          ? isIncome
          : TransactionProvider.isActualExpense(tx, accounts);

      if (!shouldInclude) continue;

      final categoryId = tx.categoryId;
      if (categoryId != null) {
        categoryAmounts[categoryId] =
            (categoryAmounts[categoryId] ?? 0) + tx.amount;
        categoryTransactionIds.putIfAbsent(categoryId, () => []).add(tx.id);
      }
    }

    final result = <StatisticsCategoryData>[];
    final categoriesById = {
      for (final category in categories) category.id: category,
    };
    for (final entry in categoryAmounts.entries) {
      final category =
          categoriesById[entry.key] ??
          Category(
            id: entry.key,
            name: 'ไม่ระบุหมวดหมู่',
            icon: Icons.help_outline,
            color: AppColors.textSecondary,
            type: type,
          );

      result.add(
        StatisticsCategoryData(
          category: category,
          amount: entry.value.toDouble(),
          color: category.color,
          icon: category.icon,
          transactionIds: categoryTransactionIds[entry.key] ?? const [],
        ),
      );
    }

    result.sort((a, b) => b.amount.compareTo(a.amount));
    return result;
  }

  void _openCategoryTransactions(
    BuildContext context,
    StatisticsCategoryData data,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionListScreen(
          categoryIds: [data.category.id],
          transactionIds: data.transactionIds,
          title: data.category.name,
        ),
      ),
    );
  }
}

class StatisticsCategoryListItem extends StatelessWidget {
  final StatisticsCategoryData data;
  final double percentage;
  final bool isDarkMode;
  final VoidCallback onTap;

  const StatisticsCategoryListItem({
    super.key,
    required this.data,
    required this.percentage,
    required this.isDarkMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final secondaryTextColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadii.large),
              ),
              child: Icon(data.icon, color: data.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.small),
                    child: LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: isDarkMode
                          ? AppColors.darkDivider
                          : AppColors.divider,
                      valueColor: AlwaysStoppedAnimation<Color>(data.color),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 96,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      formatAmount(data.amount),
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                  Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 13, color: secondaryTextColor),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 20, color: secondaryTextColor),
          ],
        ),
      ),
    );
  }
}
