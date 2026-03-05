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
import 'credit_card_bill_detail_screen.dart';

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
          body: SafeArea(
            top: false,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : bills.isEmpty
                ? _buildEmptyState(isDarkMode, textSecondaryColor)
                : _buildBillList(
                    bills,
                    isDarkMode,
                    surfaceColor,
                    textPrimaryColor,
                    textSecondaryColor,
                  ),
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
      key: const PageStorageKey('credit_card_bill_list'),
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
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreditCardBillDetailScreen(
                    bill: bill,
                    accountName: widget.account.name,
                    statementDay: widget.account.statementDay,
                  ),
                ),
              );
            },
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
                            fontSize: 12,
                            color: textSecondaryColor,
                          ),
                        ),
                        Text(
                          '${formatAmount(bill.remainingAmount.abs())} บาท',
                          style: TextStyle(
                            fontSize: 12,
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
}
