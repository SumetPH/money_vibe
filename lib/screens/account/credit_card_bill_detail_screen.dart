import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/transaction.dart';
import '../../models/account.dart';
import '../../providers/settings_provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/category_provider.dart';
import '../../services/credit_card_bill_service.dart';
import '../../theme/app_colors.dart';
import '../../main.dart';
import '../transaction/transaction_form_screen.dart';

class CreditCardBillDetailScreen extends StatefulWidget {
  final CreditCardBill bill;
  final String accountName;
  final int? statementDay;

  const CreditCardBillDetailScreen({
    super.key,
    required this.bill,
    required this.accountName,
    this.statementDay,
  });

  @override
  State<CreditCardBillDetailScreen> createState() =>
      _CreditCardBillDetailScreenState();
}

class _CreditCardBillDetailScreenState
    extends State<CreditCardBillDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer3<SettingsProvider, AccountProvider, CategoryProvider>(
      builder: (context, settingsProvider, accountProvider, catProvider, _) {
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

        final bill = widget.bill;

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: surfaceColor,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bill.isOpen ? 'รอบปัจจุบัน' : 'รอบบิล ${bill.billName}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: textPrimaryColor,
                  ),
                ),
                Text(
                  bill.dateRange,
                  style: TextStyle(fontSize: 14, color: textSecondaryColor),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(child: _buildStatusBadge(bill, isDarkMode)),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                // Summary Card
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildSummaryRow(
                        bill.isOpen ? 'ยอดใช้จ่ายถึงวันนี้' : 'ยอดใช้จ่ายในรอบ',
                        bill.expensesAmount,
                        isDarkMode,
                        textPrimaryColor,
                        textSecondaryColor,
                      ),
                      if (bill.carriedOverAmount != 0)
                        _buildSummaryRowWithSign(
                          bill.carriedOverAmount > 0
                              ? 'ยอดค้างยกมาจากรอบก่อน'
                              : 'ยอดชำระเกินยกมา',
                          bill.carriedOverAmount,
                          isDarkMode,
                          textPrimaryColor,
                          textSecondaryColor,
                        ),
                      Divider(height: 24, color: dividerColor),
                      _buildSummaryRow(
                        bill.isOpen ? 'ยอดสะสมถึงวันนี้' : 'ยอดที่ต้องชำระรวม',
                        bill.totalAmount,
                        isDarkMode,
                        textPrimaryColor,
                        textSecondaryColor,
                        isBold: true,
                        valueColor: bill.totalAmount == 0
                            ? AppColors.getAmountColor(0, isDarkMode)
                            : AppColors.getAmountColor(-1, isDarkMode),
                      ),
                      const SizedBox(height: 12),
                      _buildSummaryRow(
                        'ชำระแล้ว',
                        bill.paidAmount,
                        isDarkMode,
                        textPrimaryColor,
                        textSecondaryColor,
                        valueColor: bill.paidAmount == 0
                            ? AppColors.getAmountColor(0, isDarkMode)
                            : AppColors.getAmountColor(1, isDarkMode),
                        isBold: true,
                      ),
                      Divider(height: 24, color: dividerColor),
                      _buildSummaryRow(
                        bill.remainingAmount > 0
                            ? 'คงเหลือที่ต้องชำระ'
                            : 'ชำระเกิน',
                        bill.remainingAmount.abs(),
                        isDarkMode,
                        textPrimaryColor,
                        textSecondaryColor,
                        isBold: true,
                        valueColor: bill.remainingAmount == 0
                            ? AppColors.getAmountColor(0, isDarkMode)
                            : bill.remainingAmount > 0
                            ? AppColors.getAmountColor(-1, isDarkMode)
                            : AppColors.getAmountColor(1, isDarkMode),
                      ),
                    ],
                  ),
                ),
                // Transactions
                Expanded(
                  child: DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        Container(
                          color: surfaceColor,
                          child: TabBar(
                            indicatorColor: isDarkMode
                                ? AppColors.darkIncome
                                : AppColors.income,
                            labelColor: textPrimaryColor,
                            unselectedLabelColor: textSecondaryColor,
                            tabs: [
                              Tab(
                                text: 'รายการใช้จ่าย (${bill.expenses.length})',
                              ),
                              Tab(text: 'รายการชำระ (${bill.payments.length})'),
                            ],
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildGroupedTransactionList(
                                bill.expenses,
                                isDarkMode,
                                surfaceColor,
                                textPrimaryColor,
                                textSecondaryColor,
                                accountProvider,
                                catProvider,
                                true,
                              ),
                              _buildGroupedTransactionList(
                                bill.payments,
                                isDarkMode,
                                surfaceColor,
                                textPrimaryColor,
                                textSecondaryColor,
                                accountProvider,
                                catProvider,
                                false,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(CreditCardBill bill, bool isDarkMode) {
    Color bgColor;
    Color textColor;
    String text;

    if (bill.isOverpaid) {
      bgColor = AppColors.getAmountColor(1, isDarkMode).withValues(alpha: 0.15);
      textColor = AppColors.getAmountColor(1, isDarkMode);
      text = 'ชำระเกิน';
    } else if (bill.isFullyPaid) {
      bgColor = AppColors.getAmountColor(1, isDarkMode).withValues(alpha: 0.15);
      textColor = AppColors.getAmountColor(1, isDarkMode);
      text = 'ชำระครบ';
    } else if (bill.hasPartialPaid) {
      bgColor = AppColors.darkFabYellow.withValues(alpha: 0.15);
      textColor = isDarkMode ? AppColors.darkFabYellow : AppColors.fabYellow;
      text = 'ชำระบางส่วน';
    } else if (bill.isOpen) {
      bgColor = Colors.blue.withValues(alpha: 0.15);
      textColor = Colors.blue;
      text = 'กำลังใช้งาน';
    } else {
      bgColor = AppColors.getAmountColor(
        -1,
        isDarkMode,
      ).withValues(alpha: 0.15);
      textColor = AppColors.getAmountColor(-1, isDarkMode);
      text = 'ยังไม่ชำระ';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    double value,
    bool isDarkMode,
    Color textPrimaryColor,
    Color textSecondaryColor, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 16 : 14,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
              color: textSecondaryColor,
            ),
          ),
          Text(
            '${formatAmount(value)} บาท',
            style: TextStyle(
              fontSize: isBold ? 18 : 14,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
              color: valueColor ?? textPrimaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRowWithSign(
    String label,
    double value,
    bool isDarkMode,
    Color textPrimaryColor,
    Color textSecondaryColor,
  ) {
    final isPositive = value > 0;
    final displayValue = value.abs();
    final color = isPositive
        ? AppColors.getAmountColor(-1, isDarkMode)
        : AppColors.getAmountColor(1, isDarkMode);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, color: textSecondaryColor),
          ),
          Text(
            '${formatAmount(displayValue)} บาท',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedTransactionList(
    List<AppTransaction> transactions,
    bool isDarkMode,
    Color surfaceColor,
    Color textPrimaryColor,
    Color textSecondaryColor,
    AccountProvider accountProvider,
    CategoryProvider catProvider,
    bool isExpense,
  ) {
    if (transactions.isEmpty) {
      return Center(
        child: Text('ไม่มีรายการ', style: TextStyle(color: textSecondaryColor)),
      );
    }

    // Group transactions by date
    final grouped = <DateTime, List<AppTransaction>>{};
    for (final tx in transactions) {
      final date = DateTime(
        tx.dateTime.year,
        tx.dateTime.month,
        tx.dateTime.day,
      );
      grouped.putIfAbsent(date, () => []).add(tx);
    }

    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final date = sortedDates[index];
        final txs = grouped[date]!
          ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

        // Calculate day totals
        double dayIncome = 0;
        double dayExpense = 0;
        for (final tx in txs) {
          if (tx.type == TransactionType.income) {
            dayIncome += tx.amount;
          } else {
            dayExpense += tx.amount;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DateHeader(
              date: date,
              income: dayIncome,
              expense: dayExpense,
              isDarkMode: isDarkMode,
            ),
            ...txs.asMap().entries.map((entry) {
              final txIndex = entry.key;
              final tx = entry.value;
              return Column(
                children: [
                  _TransactionItem(
                    tx: tx,
                    accountProvider: accountProvider,
                    catProvider: catProvider,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              TransactionFormScreen(transaction: tx),
                        ),
                      );
                      if (mounted) {
                        setState(() {});
                      }
                    },
                    isDarkMode: isDarkMode,
                  ),
                  if (txIndex < txs.length - 1)
                    Divider(
                      height: 1,
                      color: isDarkMode
                          ? AppColors.darkDivider
                          : AppColors.divider,
                    ),
                ],
              );
            }),
          ],
        );
      },
    );
  }
}

class _DateHeader extends StatelessWidget {
  final DateTime date;
  final double income;
  final double expense;
  final bool isDarkMode;

  const _DateHeader({
    required this.date,
    required this.income,
    required this.expense,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDarkMode
        ? AppColors.darkSurfaceVariant
        : AppColors.background;
    final textColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final incomeColor = isDarkMode ? AppColors.darkIncome : AppColors.income;
    final expenseColor = isDarkMode ? AppColors.darkExpense : AppColors.expense;

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _formatFullDate(date),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 8),
          if (income > 0) ...[
            Text(
              '+${formatAmount(income)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: incomeColor,
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (expense > 0)
            Text(
              '-${formatAmount(expense)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: expenseColor,
              ),
            ),
        ],
      ),
    );
  }

  String _formatFullDate(DateTime date) {
    const thaiDays = [
      'จันทร์',
      'อังคาร',
      'พุธ',
      'พฤหัสบดี',
      'ศุกร์',
      'เสาร์',
      'อาทิตย์',
    ];
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
    final dayOfWeek = thaiDays[date.weekday - 1];
    return '${date.day} ${thaiMonths[date.month - 1]} ${date.year} - $dayOfWeek';
  }
}

class _TransactionItem extends StatelessWidget {
  final AppTransaction tx;
  final AccountProvider accountProvider;
  final CategoryProvider catProvider;
  final VoidCallback onTap;
  final bool isDarkMode;

  const _TransactionItem({
    required this.tx,
    required this.accountProvider,
    required this.catProvider,
    required this.onTap,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final account = accountProvider.findById(tx.accountId);
    final toAccount = tx.toAccountId != null
        ? accountProvider.findById(tx.toAccountId!)
        : null;
    final category = tx.categoryId != null
        ? catProvider.findById(tx.categoryId!)
        : null;

    final typeColor = _typeColor(tx.type, isDarkMode);
    final displayAmount = tx.type.isExpenseLike ? -tx.amount : tx.amount;

    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final textPrimaryColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final textSecondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: surfaceColor,
        child: Row(
          children: [
            // Type indicator bar
            Container(width: 0, height: 60, color: typeColor),
            const SizedBox(width: 12),
            // Category/Type icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (tx.type == TransactionType.debtTransfer
                        ? typeColor
                        : (category?.color ?? typeColor))
                    .withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                tx.type == TransactionType.debtTransfer
                    ? Icons.account_tree
                    : tx.type == TransactionType.transfer
                    ? Icons.swap_horiz
                    : tx.type == TransactionType.debtRepay
                    ? Icons.payment
                    : (category?.icon ?? Icons.receipt),
                color: tx.type == TransactionType.debtTransfer
                    ? typeColor
                    : (category?.color ?? typeColor),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Account info
                  Text(
                    _buildAccountLabel(account, toAccount, tx),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textPrimaryColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Category
                  Text(
                    _buildSubLabel(category?.name),
                    style: TextStyle(fontSize: 14, color: textSecondaryColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Time + Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatTime(tx.dateTime),
                  style: TextStyle(fontSize: 13, color: textSecondaryColor),
                ),
                Text(
                  tx.type == TransactionType.transfer
                      ? formatAmount(tx.amount)
                      : '${displayAmount > 0 ? '+' : ''}${formatAmount(displayAmount)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: tx.type == TransactionType.transfer
                        ? (isDarkMode
                              ? AppColors.darkTransfer
                              : AppColors.transfer)
                        : tx.type == TransactionType.debtRepay
                        ? (isDarkMode
                              ? AppColors.darkExpense
                              : AppColors.expense)
                        : tx.type == TransactionType.debtTransfer
                        ? (isDarkMode
                              ? AppColors.darkDebtTransfer
                              : AppColors.debtTransfer)
                        : AppColors.getAmountColor(displayAmount, isDarkMode),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  Color _typeColor(TransactionType type, bool isDarkMode) {
    if (isDarkMode) {
      switch (type) {
        case TransactionType.income:
          return AppColors.darkIncome;
        case TransactionType.expense:
          return AppColors.darkExpense;
        case TransactionType.transfer:
          return AppColors.darkTransfer;
        case TransactionType.debtRepay:
          return AppColors.darkExpense;
        case TransactionType.debtTransfer:
          return AppColors.darkDebtTransfer;
      }
    }
    switch (type) {
      case TransactionType.income:
        return AppColors.income;
      case TransactionType.expense:
        return AppColors.expense;
      case TransactionType.transfer:
        return AppColors.transfer;
      case TransactionType.debtRepay:
        return AppColors.expense;
      case TransactionType.debtTransfer:
        return AppColors.debtTransfer;
    }
  }

  String _buildAccountLabel(
    Account? account,
    Account? toAccount,
    AppTransaction tx,
  ) {
    if (tx.type.usesDestinationAccount) {
      final from = account?.name ?? '-';
      final to = toAccount?.name ?? '-';
      return '$from → $to';
    }
    return account?.name ?? '-';
  }

  String _buildSubLabel(String? categoryName) {
    if (categoryName != null) {
      return categoryName;
    }
    return categoryName ?? '';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
