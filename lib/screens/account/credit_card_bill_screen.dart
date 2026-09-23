import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/account.dart';
import '../../models/transaction.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../services/credit_card_bill_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../main.dart';
import '../../widgets/account_icon_widget.dart';
import '../transaction/transaction_list_screen.dart';

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
  List<CreditCardBill> _bills = [];
  bool _loading = true;
  int? _lastTxKey;
  int _recomputeVersion = 0;

  String _formatBillDateRange(CreditCardBill bill) {
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
    final startStr =
        '${bill.startDate.day} ${thaiMonths[bill.startDate.month - 1]}';
    if (bill.isOpen) {
      return '$startStr - วันนี้';
    }
    final endDate = bill.statementDate;
    final endStr = '${endDate.day} ${thaiMonths[endDate.month - 1]}';
    return '$startStr - $endStr';
  }

  String _formatStatementHint(CreditCardBill bill) {
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
    return 'ตัดยอด ${bill.statementDate.day} ${thaiMonths[bill.statementDate.month - 1]} ${bill.statementDate.year}';
  }

  DateTimeRange _buildCurrentCycleDateRange(CreditCardBill bill) {
    final now = DateTime.now();
    final start = DateTime(
      bill.startDate.year,
      bill.startDate.month,
      bill.startDate.day,
    );
    final today = DateTime(now.year, now.month, now.day);
    final end = today.isBefore(start) ? start : today;

    return DateTimeRange(start: start, end: end);
  }

  void _scheduleRecomputeIfNeeded(List<AppTransaction> transactions) {
    final relevantTransactions = CreditCardBillService.filterCardTransactions(
      widget.account.id,
      transactions,
    );
    final key = Object.hashAll(
      relevantTransactions.map(
        (tx) => Object.hash(
          tx.id,
          tx.type,
          tx.amount,
          tx.accountId,
          tx.toAccountId,
          tx.dateTime,
        ),
      ),
    );
    if (key == _lastTxKey) return;
    _lastTxKey = key;
    final recomputeVersion = ++_recomputeVersion;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _recompute(relevantTransactions, recomputeVersion);
    });
  }

  Future<void> _recompute(
    List<AppTransaction> relevantTransactions,
    int recomputeVersion,
  ) async {
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
      _BillParams(widget.account, relevantTransactions),
    );
    if (mounted && recomputeVersion == _recomputeVersion) {
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
        final textPrimaryColor = isDarkMode
            ? AppColors.darkTextPrimary
            : AppColors.textPrimary;
        final textSecondaryColor = isDarkMode
            ? AppColors.darkTextSecondary
            : AppColors.textSecondary;

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: bgColor,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: true,
            leadingWidth: 64,
            leading: Center(
              child: Material(
                color: isDarkMode ? AppColors.darkSurface : AppColors.surface,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: IconButton(
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    size: 20,
                    color: isDarkMode
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                  tooltip: 'ย้อนกลับ',
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'รอบบิลบัตรเครดิต',
                  style: TextStyle(
                    color: textSecondaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  widget.account.name,
                  style: TextStyle(
                    color: textPrimaryColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: AccountIconWidget(
                    account: widget.account,
                    size: 38,
                    isDarkMode: isDarkMode,
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : bills.isEmpty
                ? _buildEmptyState(
                    isDarkMode,
                    textSecondaryColor,
                    hasStatementDay: widget.account.statementDay != null,
                  )
                : _buildBillList(
                    bills,
                    isDarkMode,
                    textPrimaryColor,
                    textSecondaryColor,
                  ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(
    bool isDarkMode,
    Color textSecondaryColor, {
    required bool hasStatementDay,
  }) {
    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(AppRadii.sheet),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: textSecondaryColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.credit_card_off_rounded,
                  size: 32,
                  color: textSecondaryColor,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                hasStatementDay
                    ? 'ยังไม่มีรายการรอบบิล'
                    : 'ยังไม่ได้ตั้งค่าวันสรุปยอด',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDarkMode
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                hasStatementDay
                    ? 'เมื่อเริ่มมีข้อมูลธุรกรรมหรือรอบบิล รายการจะแสดงที่นี่'
                    : 'กรุณาแก้ไขข้อมูลบัญชีเพื่อเพิ่มวันสรุปยอดรอบบิล',
                style: TextStyle(fontSize: 14, color: textSecondaryColor),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBillList(
    List<CreditCardBill> bills,
    bool isDarkMode,
    Color textPrimaryColor,
    Color textSecondaryColor,
  ) {
    // คำนวณยอดสรุปภาพรวมสำหรับ Hero Card
    final openBill = bills.where((b) => b.isOpen).firstOrNull;
    final totalUnpaid = openBill?.remainingAmount ?? 0.0;
    // ยอดชำระรอบปัจจุบันหักยอดค้างยกมาก่อน แล้วส่วนที่เหลือจึงหักยอดใช้ใหม่
    final pastPending =
        ((openBill?.carriedOverAmount ?? 0.0) - (openBill?.paidAmount ?? 0.0))
            .clamp(0.0, totalUnpaid)
            .toDouble();
    final openCycleAmount = totalUnpaid - pastPending;

    return ListView(
      key: const PageStorageKey('credit_card_bill_list'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // 1. Hero Summary Card ด้านบน
        _HeroSummaryCard(
          account: widget.account,
          totalUnpaid: totalUnpaid,
          openCycleAmount: openCycleAmount,
          pastPending: pastPending,
          isDarkMode: isDarkMode,
        ),
        const SizedBox(height: 20),

        // 2. Section Header
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(
            children: [
              Text(
                'รายการรอบบิล (${bills.length})',
                style: TextStyle(
                  color: textPrimaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),

        // 3. Bill Inset Cards
        ...bills.map((bill) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _BillItemCard(
              bill: bill,
              account: widget.account,
              isDarkMode: isDarkMode,
              dateRangeText: _formatBillDateRange(bill),
              statementHint: bill.isOpen ? _formatStatementHint(bill) : null,
              onTap: () {
                final billTransactionIds = [
                  ...bill.expenses.map((tx) => tx.id),
                  ...bill.payments.map((tx) => tx.id),
                ];

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TransactionListScreen(
                      accountId: widget.account.id,
                      transactionIds: bill.isOpen ? null : billTransactionIds,
                      fixedDateRange: bill.isOpen
                          ? _buildCurrentCycleDateRange(bill)
                          : null,
                      creditCardPaymentStartDate: bill.isOpen
                          ? bill.paymentStartDate
                          : null,
                      title: bill.isOpen
                          ? 'รอบปัจจุบัน'
                          : 'รอบบิล ${bill.billName}',
                    ),
                  ),
                );
              },
            ),
          );
        }),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Hero Summary Card
// ─────────────────────────────────────────────────────────────────────────────
class _HeroSummaryCard extends StatelessWidget {
  final Account account;
  final double totalUnpaid;
  final double openCycleAmount;
  final double pastPending;
  final bool isDarkMode;

  const _HeroSummaryCard({
    required this.account,
    required this.totalUnpaid,
    required this.openCycleAmount,
    required this.pastPending,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final surfaceVariant = isDarkMode
        ? AppColors.darkSurfaceVariant
        : AppColors.sectionHeader;
    final textPrimary = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final textSecondary = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;

    final hasPending = totalUnpaid > 0;
    final statusColor = hasPending
        ? (isDarkMode ? AppColors.darkExpense : AppColors.expense)
        : (isDarkMode ? AppColors.darkIncome : AppColors.income);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppRadii.sheet),
        border: Border.all(
          color: isDarkMode
              ? AppColors.darkDivider.withValues(alpha: 0.4)
              : AppColors.divider.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Label + Statement Day Tag
          Row(
            children: [
              Text(
                'ยอดรอชำระรวม',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
              const Spacer(),
              if (account.statementDay != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: surfaceVariant,
                    borderRadius: BorderRadius.circular(AppRadii.large),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 13,
                        color: textSecondary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'สรุปยอดทุกวันที่ ${account.statementDay}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Big Bold Total Amount
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '฿ ${formatAmount(totalUnpaid)}',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: hasPending ? statusColor : textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadii.full),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasPending
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_rounded,
                      size: 14,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hasPending ? 'มียอดค้างชำระ' : 'ชำระครบแล้ว',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: dividerColor),
          const SizedBox(height: 14),

          // Breakdown: Open Cycle vs Past Bills
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'รอบปัจจุบัน (ยังไม่ตัดรอบ)',
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '฿ ${formatAmount(openCycleAmount)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 32, color: dividerColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'รอบบิลที่ตัดยอดแล้ว',
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '฿ ${formatAmount(pastPending)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: pastPending > 0
                            ? (isDarkMode
                                  ? AppColors.darkExpense
                                  : AppColors.expense)
                            : textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Bill Inset Card
// ─────────────────────────────────────────────────────────────────────────────
class _BillItemCard extends StatelessWidget {
  final CreditCardBill bill;
  final Account account;
  final bool isDarkMode;
  final String dateRangeText;
  final String? statementHint;
  final VoidCallback onTap;

  const _BillItemCard({
    required this.bill,
    required this.account,
    required this.isDarkMode,
    required this.dateRangeText,
    required this.statementHint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final surfaceVariant = isDarkMode
        ? AppColors.darkSurfaceVariant
        : AppColors.sectionHeader;
    final textPrimary = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final textSecondary = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;

    final openBillColor = isDarkMode
        ? AppColors.darkTransfer
        : AppColors.transfer;

    return Material(
      color: surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.xLarge),
        side: BorderSide(
          color: isDarkMode
              ? AppColors.darkDivider.withValues(alpha: 0.4)
              : AppColors.divider.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.xLarge),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Bill Tag + Status Badge + Chevron
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: bill.isOpen
                          ? openBillColor.withValues(alpha: 0.16)
                          : surfaceVariant,
                      borderRadius: BorderRadius.circular(AppRadii.small),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          bill.isOpen
                              ? Icons.timelapse_rounded
                              : Icons.receipt_long_rounded,
                          size: 14,
                          color: bill.isOpen ? openBillColor : textSecondary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          bill.isOpen ? 'รอบปัจจุบัน' : bill.billName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: bill.isOpen ? openBillColor : textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  _buildStatusBadge(bill, isDarkMode),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Date Range and Statement hint
              Row(
                children: [
                  Icon(
                    Icons.date_range_rounded,
                    size: 16,
                    color: textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    dateRangeText,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  if (statementHint != null) ...[
                    const Spacer(),
                    Text(
                      statementHint!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: dividerColor),
              ),

              // Financial Amounts Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ยอดที่ต้องชำระ',
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '฿ ${formatAmount(bill.totalAmount)}',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
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
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '฿ ${formatAmount(bill.paidAmount)}',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: bill.paidAmount == 0
                                ? textSecondary
                                : (isDarkMode
                                      ? AppColors.darkIncome
                                      : AppColors.income),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Remaining amount or Carried over pill
              if (bill.remainingAmount != 0 || bill.carriedOverAmount != 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: surfaceVariant,
                    borderRadius: BorderRadius.circular(AppRadii.large),
                  ),
                  child: Column(
                    children: [
                      if (bill.remainingAmount != 0)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              bill.remainingAmount > 0
                                  ? 'คงเหลือที่ต้องชำระ'
                                  : 'ชำระเกิน',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: textSecondary,
                              ),
                            ),
                            Text(
                              '${bill.remainingAmount > 0 ? '-' : '+'}฿ ${formatAmount(bill.remainingAmount.abs())}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: bill.remainingAmount > 0
                                    ? (isDarkMode
                                          ? AppColors.darkExpense
                                          : AppColors.expense)
                                    : (isDarkMode
                                          ? AppColors.darkIncome
                                          : AppColors.income),
                              ),
                            ),
                          ],
                        ),
                      if (bill.remainingAmount != 0 &&
                          bill.carriedOverAmount != 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Divider(
                            height: 1,
                            color: dividerColor.withValues(alpha: 0.5),
                          ),
                        ),
                      if (bill.carriedOverAmount != 0)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              bill.carriedOverAmount > 0
                                  ? 'ยอดค้างยกมาจากรอบก่อน'
                                  : 'ยอดชำระเกินยกมา',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: textSecondary,
                              ),
                            ),
                            Text(
                              '${bill.carriedOverAmount > 0 ? '-' : '+'}฿ ${formatAmount(bill.carriedOverAmount.abs())}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: bill.carriedOverAmount > 0
                                    ? (isDarkMode
                                          ? AppColors.darkExpense
                                          : AppColors.expense)
                                    : (isDarkMode
                                          ? AppColors.darkIncome
                                          : AppColors.income),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(CreditCardBill bill, bool isDarkMode) {
    Color color;
    String text;

    if (bill.isOverpaid) {
      color = isDarkMode ? AppColors.darkIncome : AppColors.income;
      text = 'ชำระเกิน';
    } else if (bill.isFullyPaid) {
      color = isDarkMode ? AppColors.darkIncome : AppColors.income;
      text = 'ชำระครบ';
    } else if (bill.hasPartialPaid) {
      color = isDarkMode ? AppColors.darkFabYellow : AppColors.fabYellow;
      text = 'ชำระบางส่วน';
    } else if (bill.isOpen) {
      color = isDarkMode ? AppColors.darkTransfer : AppColors.transfer;
      text = 'กำลังใช้งาน';
    } else {
      color = isDarkMode ? AppColors.darkExpense : AppColors.expense;
      text = 'ยังไม่ชำระ';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
