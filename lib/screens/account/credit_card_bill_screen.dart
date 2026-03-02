import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/account.dart';
import '../../models/transaction.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../services/credit_card_bill_service.dart';
import '../../theme/app_colors.dart';
import '../../main.dart';

// ฟังก์ชันระดับ top-level สำหรับ compute() isolate
class _BillParams {
  final Account account;
  final List<AppTransaction> transactions;
  const _BillParams(this.account, this.transactions);
}

List<CreditCardBill> _computeBillsIsolate(_BillParams params) {
  return CreditCardBillService.calculateBills(
    account: params.account,
    transactions: params.transactions,
  );
}

class CreditCardBillScreen extends StatefulWidget {
  final Account account;

  const CreditCardBillScreen({super.key, required this.account});

  @override
  State<CreditCardBillScreen> createState() => _CreditCardBillScreenState();
}

class _CreditCardBillScreenState extends State<CreditCardBillScreen> {
  CreditCardBill? _selectedBill;
  List<CreditCardBill> _bills = [];
  bool _loading = true;
  String _lastTxKey = '';

  void _scheduleRecomputeIfNeeded(List<AppTransaction> transactions) {
    // ใช้ length + first/last id เป็น key ตรวจจับการเปลี่ยนแปลง
    final key =
        '${transactions.length}_${transactions.firstOrNull?.id}_${transactions.lastOrNull?.id}';
    if (key == _lastTxKey) return;
    _lastTxKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _recompute(transactions);
    });
  }

  Future<void> _recompute(List<AppTransaction> transactions) async {
    if (widget.account.statementDay == null) {
      setState(() {
        _bills = [];
        _loading = false;
      });
      return;
    }
    // แสดง loading เฉพาะครั้งแรก (ยังไม่มี cache)
    if (_bills.isEmpty) {
      setState(() => _loading = true);
    }

    final bills = await compute(
      _computeBillsIsolate,
      _BillParams(widget.account, List.of(transactions)),
    );
    if (mounted) {
      setState(() {
        _bills = bills;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<TransactionProvider, SettingsProvider>(
      builder: (context, txProvider, settingsProvider, _) {
        final isDarkMode = settingsProvider.isDarkMode;

        // ตรวจว่า transactions เปลี่ยนหรือไม่ แล้วคำนวณใน background
        _scheduleRecomputeIfNeeded(txProvider.transactions);

        final bills = _bills;

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

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(widget.account.name),
                if (widget.account.statementDay != null)
                  Text(
                    'สรุปยอดวันที่ ${widget.account.statementDay}',
                    style: TextStyle(fontSize: 12, color: textSecondaryColor),
                  ),
              ],
            ),
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : bills.isEmpty
              ? _buildEmptyState(isDarkMode, textSecondaryColor)
              : _selectedBill == null
              ? _buildBillList(
                  bills,
                  isDarkMode,
                  surfaceColor,
                  textPrimaryColor,
                  textSecondaryColor,
                )
              : _buildBillDetail(
                  _selectedBill!,
                  isDarkMode,
                  surfaceColor,
                  textPrimaryColor,
                  textSecondaryColor,
                ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDarkMode, Color textSecondaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.credit_card_off_outlined,
            size: 64,
            color: textSecondaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            'ยังไม่ได้ตั้งค่าวันสรุปยอด',
            style: TextStyle(fontSize: 18, color: textSecondaryColor),
          ),
          const SizedBox(height: 8),
          Text(
            'กรุณาแก้ไขบัญชีเพื่อเพิ่มวันสรุปยอด',
            style: TextStyle(fontSize: 14, color: textSecondaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildBillList(
    List<CreditCardBill> bills,
    bool isDarkMode,
    Color surfaceColor,
    Color textPrimaryColor,
    Color textSecondaryColor,
  ) {
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bills.length,
      itemBuilder: (context, index) {
        final bill = bills[index];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () => setState(() => _selectedBill = bill),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: bill.isOpen
                              ? AppColors.getAmountColor(
                                  1,
                                  isDarkMode,
                                ).withValues(alpha: 0.15)
                              : textSecondaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          bill.isOpen ? 'รอบปัจจุบัน' : bill.billName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: bill.isOpen
                                ? AppColors.getAmountColor(1, isDarkMode)
                                : textSecondaryColor,
                          ),
                        ),
                      ),
                      const Spacer(),
                      _buildStatusBadge(bill, isDarkMode),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    bill.dateRange,
                    style: TextStyle(fontSize: 14, color: textSecondaryColor),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ยอดที่ต้องชำระ',
                              style: TextStyle(
                                fontSize: 12,
                                color: textSecondaryColor,
                              ),
                            ),
                            Text(
                              '${formatAmount(bill.totalAmount)} บาท',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: textPrimaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'ชำระแล้ว',
                              style: TextStyle(
                                fontSize: 12,
                                color: textSecondaryColor,
                              ),
                            ),
                            Text(
                              '${formatAmount(bill.paidAmount)} บาท',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: bill.paidAmount == 0
                                    ? textSecondaryColor
                                    : AppColors.getAmountColor(1, isDarkMode),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (bill.remainingAmount != 0) ...[
                    const SizedBox(height: 12),
                    Divider(height: 1, color: dividerColor),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          bill.remainingAmount > 0
                              ? 'คงเหลือที่ต้องชำระ'
                              : 'ชำระเกิน',
                          style: TextStyle(
                            fontSize: 14,
                            color: textSecondaryColor,
                          ),
                        ),
                        Text(
                          '${formatAmount(bill.remainingAmount.abs())} บาท',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: bill.remainingAmount > 0
                                ? AppColors.getAmountColor(
                                    -1,
                                    isDarkMode,
                                  ) // ค้างชำระ = แดง
                                : AppColors.getAmountColor(
                                    1,
                                    isDarkMode,
                                  ), // ชำระเกิน = เขียว
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (bill.carriedOverAmount != 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          bill.carriedOverAmount > 0
                              ? 'ยอดค้างยกมาจากรอบก่อน'
                              : 'ยอดชำระเกินยกมา',
                          style: TextStyle(
                            fontSize: 12,
                            color: textSecondaryColor,
                          ),
                        ),
                        Text(
                          '${formatAmount(bill.carriedOverAmount.abs())} บาท',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: bill.carriedOverAmount > 0
                                ? AppColors.getAmountColor(
                                    -1,
                                    isDarkMode,
                                  ) // ค้างชำระ = แดง
                                : AppColors.getAmountColor(
                                    1,
                                    isDarkMode,
                                  ), // ชำระเกินยกมา = เขียว
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
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
      // รอบปัจจุบันที่ยังไม่มีการชำระ — ยังเปิดอยู่
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

  Widget _buildBillDetail(
    CreditCardBill bill,
    bool isDarkMode,
    Color surfaceColor,
    Color textPrimaryColor,
    Color textSecondaryColor,
  ) {
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;

    return Column(
      children: [
        // Header with back button
        Container(
          color: surfaceColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _selectedBill = null),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
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
                      bill.isOpen ? bill.dateRange : bill.dateRange,
                      style: TextStyle(fontSize: 14, color: textSecondaryColor),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(bill, isDarkMode),
            ],
          ),
        ),
        Divider(height: 1, color: dividerColor),
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
                bill.remainingAmount > 0 ? 'คงเหลือที่ต้องชำระ' : 'ชำระเกิน',
                bill.remainingAmount.abs(),
                isDarkMode,
                textPrimaryColor,
                textSecondaryColor,
                isBold: true,
                valueColor: bill.remainingAmount == 0
                    ? AppColors.getAmountColor(0, isDarkMode) // ชำระครบ = ดํา
                    : bill.remainingAmount > 0
                    ? AppColors.getAmountColor(-1, isDarkMode) // ค้างชำระ = แดง
                    : AppColors.getAmountColor(
                        1,
                        isDarkMode,
                      ), // ชำระเกิน = เขียว
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
                      Tab(text: 'รายการใช้จ่าย (${bill.expenses.length})'),
                      Tab(text: 'รายการชำระ (${bill.payments.length})'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildTransactionList(
                        bill.expenses,
                        isDarkMode,
                        surfaceColor,
                        textPrimaryColor,
                        textSecondaryColor,
                        true,
                      ),
                      _buildTransactionList(
                        bill.payments,
                        isDarkMode,
                        surfaceColor,
                        textPrimaryColor,
                        textSecondaryColor,
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
    final isPositive = value > 0; // บวก = ค้างชำระ
    final displayValue = value.abs();
    // บวก (ค้างชำระ) = แดง, ลบ (ชำระเกิน) = เขียว
    final color = isPositive
        ? AppColors.getAmountColor(-1, isDarkMode) // ค้างชำระ = แดง
        : AppColors.getAmountColor(1, isDarkMode); // ชำระเกิน = เขียว

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

  Widget _buildTransactionList(
    List<AppTransaction> transactions,
    bool isDarkMode,
    Color surfaceColor,
    Color textPrimaryColor,
    Color textSecondaryColor,
    bool isExpense,
  ) {
    if (transactions.isEmpty) {
      return Center(
        child: Text('ไม่มีรายการ', style: TextStyle(color: textSecondaryColor)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final tx = transactions[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color:
                      (isExpense
                              ? AppColors.getAmountColor(-1, isDarkMode)
                              : AppColors.getAmountColor(1, isDarkMode))
                          .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isExpense
                      ? Icons.shopping_bag_outlined
                      : tx.type == TransactionType.income
                          ? Icons.card_giftcard_outlined
                          : Icons.payment_outlined,
                  color: isExpense
                      ? AppColors.getAmountColor(-1, isDarkMode)
                      : AppColors.getAmountColor(1, isDarkMode),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.note ??
                          (isExpense
                              ? 'รายการใช้จ่าย'
                              : tx.type == TransactionType.income
                                  ? 'รายรับ/เงินคืน'
                                  : 'ชำระบัตรเครดิต'),
                      style: TextStyle(fontSize: 14, color: textPrimaryColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _formatDate(tx.dateTime),
                      style: TextStyle(fontSize: 12, color: textSecondaryColor),
                    ),
                  ],
                ),
              ),
              Text(
                tx.amount == 0
                    ? formatAmount(tx.amount)
                    : '${isExpense ? '-' : ''}${formatAmount(tx.amount)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: tx.amount == 0
                      ? textPrimaryColor // 0 = สีข้อความปกติ
                      : isExpense
                      ? AppColors.getAmountColor(-1, isDarkMode)
                      : AppColors.getAmountColor(1, isDarkMode),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
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
    return '${date.day} ${thaiMonths[date.month - 1]} ${date.year}';
  }
}
