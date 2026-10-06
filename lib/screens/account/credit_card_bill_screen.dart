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
import '../../widgets/account_icon_widget.dart';
import '../transaction/transaction_list_screen.dart';
import '../../widgets/app_bar_buttons.dart';
import 'credit_card_bill_hero_card.dart';
import 'credit_card_bill_item_card.dart';

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
            leading: const AppBackButton(),
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
            borderRadius: BorderRadius.circular(AppRadii.xLarge),
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
        CreditCardBillHeroCard(
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
            child: CreditCardBillItemCard(
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
