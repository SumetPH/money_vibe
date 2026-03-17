import '../models/account.dart';
import '../models/transaction.dart';

/// ข้อมูลบิลบัตรเครดิตแต่ละรอบ (คำนวณสด)
class CreditCardBill {
  final DateTime statementDate; // วันสรุปยอด
  final DateTime startDate; // วันเริ่มต้นรอบ
  final DateTime dueDate; // วันครบกำหนดชำระ (สรุปยอด + 15 วัน)

  // ยอดต่างๆ
  final double expensesAmount; // ยอดใช้จ่ายในรอบนี้
  final double carriedOverAmount; // ยอดยกมาจากรอบก่อน (บวก=ค้างชำระ, ลบ=ชำระเกิน)
  final double totalAmount; // ยอดที่ต้องชำระรวม = expenses + carriedOver
  final double paidAmount; // ยอดที่ชำระแล้ว
  final double remainingAmount; // ยอดคงเหลือ (บวก=ค้างชำระ, ลบ=ชำระเกินในช่วง grace period)
  final double overpaidAmount; // ยอดชำระเกินที่จะยกไปรอบหน้า (เฉพาะใน 15 วัน)

  // รายการ
  final List<AppTransaction> expenses; // รายการใช้จ่าย
  final List<AppTransaction> payments; // รายการชำระ (โอนเข้าบัตร)

  // สถานะ
  final bool isFullyPaid;
  final bool isOverpaid;
  final bool hasPartialPaid;
  final bool isOpen; // รอบที่ยังไม่ถึงวันสรุปยอด (รอบปัจจุบัน)

  CreditCardBill({
    required this.statementDate,
    required this.startDate,
    required this.dueDate,
    required this.expensesAmount,
    required this.carriedOverAmount,
    required this.totalAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.overpaidAmount,
    required this.expenses,
    required this.payments,
    required this.isFullyPaid,
    required this.isOverpaid,
    required this.hasPartialPaid,
    this.isOpen = false,
  });

  /// ชื่อรอบบิล เช่น "ก.พ. 2568"
  String get billName {
    const thaiMonths = [
      'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
    ];
    return '${thaiMonths[statementDate.month - 1]} ${statementDate.year}';
  }

  /// ช่วงวันของบิล เช่น "16 ม.ค. - 15 ก.พ."
  String get dateRange {
    const thaiMonths = [
      'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
    ];
    final startStr = '${startDate.day} ${thaiMonths[startDate.month - 1]}';
    final endStr = '${statementDate.day} ${thaiMonths[statementDate.month - 1]}';
    return '$startStr - $endStr';
  }

  /// สถานะการชำระเป็นข้อความ
  String get statusText {
    if (isOverpaid) return 'ชำระเกิน';
    if (isFullyPaid) return 'ชำระครบ';
    if (hasPartialPaid) return 'ชำระบางส่วน';
    return 'ยังไม่ชำระ';
  }
}

/// Service คำนวณบิลบัตรเครดิตแบบสด (on-the-fly)
class CreditCardBillService {
  /// คำนวณรอบบิลบัตรเครดิตทั้งหมดตั้งแต่วันสร้างบัญชี
  ///
  /// [account] - บัญชีบัตรเครดิต (ต้องมี statementDay)
  /// [transactions] - รายการธุรกรรมทั้งหมด
  /// [monthsBack] - ไม่ได้ใช้แล้ว (deprecated, kept for API compatibility)
  static List<CreditCardBill> calculateBills({
    required Account account,
    required List<AppTransaction> transactions,
    int monthsBack = 12,
  }) {
    if (account.type != AccountType.creditCard) {
      throw ArgumentError('Account must be a credit card');
    }
    if (account.statementDay == null) return [];

    final statementDay = account.statementDay!;
    final now = DateTime.now();

    // สร้างวันสรุปยอดเริ่มจากวันสร้างบัญชีไปข้างหน้าจนถึงปัจจุบัน
    final statementDates = _generateStatementDates(
      statementDay: statementDay,
      from: account.startDate,
      until: now,
    );

    if (statementDates.isEmpty) return [];

    // กรองธุรกรรมของบัตรนี้เท่านั้น
    final cardTransactions = transactions
        .where((t) => t.accountId == account.id || t.toAccountId == account.id)
        .toList();

    final bills = <CreditCardBill>[];
    // initialBalance ของ credit card เป็นค่าลบ (เช่น -5000 = ค้างอยู่ 5000 บาท)
    // แปลงเป็น carry-over ที่เป็นบวก (บวก = ค้างชำระ, ลบ = ชำระเกิน)
    double carryOverAmount = -account.initialBalance;

    for (int i = 0; i < statementDates.length; i++) {
      final statementDate = statementDates[i];
      final dueDate = statementDate.add(const Duration(days: 15));

      // รอบแรก: เริ่มจากวันสร้างบัญชี
      // รอบถัดไป: เริ่มจากวันถัดจากวันสรุปยอดก่อนหน้า
      final startDate = i == 0
          ? account.startDate
          : statementDates[i - 1].add(const Duration(days: 1));

      // เปรียบเทียบระดับวัน (ตัดเวลาออก) เพื่อให้ครอบคลุม transaction ทั้งวัน
      final startDay = _dayOf(startDate);
      final endDay = _dayOf(statementDate);
      final dueDateDay = _dayOf(dueDate);

      // ช่วงการชำระของรอบนี้:
      //   เริ่ม: วันถัดจาก due date รอบก่อน (prevStatement + 16) หรือ startDate สำหรับรอบแรก
      //   สิ้นสุด: due date รอบนี้ (statementDate + 15) inclusive
      // → การชำระหลัง due date รอบก่อน ถือว่าเป็นการชำระสำหรับรอบปัจจุบัน
      final paymentStartDay = i == 0
          ? _dayOf(account.startDate)
          : _dayOf(statementDates[i - 1]).add(const Duration(days: 16));
      final paymentEndDay = dueDateDay; // statementDate + 15 (inclusive)

      // รายการใช้จ่ายในรอบ [startDate, statementDate] (inclusive ทั้งสองฝั่ง, เทียบระดับวัน)
      // รวม debtRepay/debtTransfer จากบัตร ให้นับเป็นยอดใช้ของบัตรด้วย
      final expenses = cardTransactions.where((t) {
        final d = _dayOf(t.dateTime);
        return (t.type == TransactionType.expense ||
                t.type == TransactionType.debtRepay ||
                t.type == TransactionType.debtTransfer) &&
            t.accountId == account.id &&
            !d.isBefore(startDay) &&
            !d.isAfter(endDay);
      }).toList();

      final expensesAmount = expenses.fold<double>(0, (s, t) => s + t.amount);

      // รายการชำระ: transfer/debtRepay/income เข้าบัตร ในช่วง [paymentStartDay, paymentEndDay]
      // ใช้ paymentStartDay เหมือนกันทุกประเภท เพื่อป้องกันนับซ้ำกับรอบก่อน
      final payments = cardTransactions.where((t) {
        final d = _dayOf(t.dateTime);
        final isTransferPayment = (t.type == TransactionType.transfer ||
                t.type == TransactionType.debtRepay) &&
            t.toAccountId == account.id;
        final isIncomePayment = t.type == TransactionType.income &&
            t.accountId == account.id;
        return (isTransferPayment || isIncomePayment) &&
            !d.isBefore(paymentStartDay) &&
            !d.isAfter(paymentEndDay);
      }).toList();

      final totalPaid = _round(payments.fold<double>(0, (s, t) => s + t.amount));

      final totalAmount = _round(expensesAmount + carryOverAmount);
      final remainingAmount = _round(totalAmount - totalPaid);

      // ยอดชำระเกิน: ถ้าชำระรวมมากกว่ายอดที่ต้องชำระ → ยกยอดส่วนเกินทั้งหมดไปรอบหน้า
      double overpaidAmount = 0;
      if (totalAmount > 0 && totalPaid > totalAmount) {
        overpaidAmount = _round(totalPaid - totalAmount);
      }

      // ยอดคงเหลือสำหรับแสดงผล:
      //   บวก = ยังค้างชำระ
      //   ลบ  = ชำระเกินใน grace period (จะยกไปรอบหน้า)
      //   ศูนย์ = ชำระครบ หรือชำระเกินหลัง grace period (ไม่ยกยอด)
      final displayRemaining = remainingAmount < 0 ? -overpaidAmount : remainingAmount;

      bills.add(CreditCardBill(
        statementDate: statementDate,
        startDate: startDate,
        dueDate: dueDate,
        expensesAmount: expensesAmount,
        carriedOverAmount: carryOverAmount,
        totalAmount: totalAmount,
        paidAmount: totalPaid,
        remainingAmount: displayRemaining,
        overpaidAmount: overpaidAmount,
        expenses: expenses,
        payments: payments,
        isFullyPaid: displayRemaining <= 0,
        isOverpaid: displayRemaining < 0,
        hasPartialPaid: totalPaid > 0 && displayRemaining > 0,
      ));

      // ยกยอดไปรอบถัดไป
      if (displayRemaining > 0) {
        carryOverAmount = displayRemaining; // ยอดค้างชำระ
      } else if (overpaidAmount > 0) {
        carryOverAmount = -overpaidAmount; // เครดิตชำระเกิน
      } else {
        carryOverAmount = 0;
      }
    }

    // คำนวณรอบปัจจุบัน (open cycle ที่ยังไม่ถึงวันสรุปยอด)
    final DateTime nextStatementDate;
    if (statementDates.isNotEmpty) {
      nextStatementDate = _getNextStatementDate(statementDates.last, statementDay);
    } else {
      // ยังไม่มีรอบปิดเลย — หาวันสรุปยอดแรกที่ >= account.startDate
      var candidate = _getStatementDateForMonth(statementDay, account.startDate.year, account.startDate.month);
      if (candidate.isBefore(_dayOf(account.startDate))) {
        candidate = _getNextStatementDate(candidate, statementDay);
      }
      nextStatementDate = candidate;
    }

    // nextStatementDate ต้องอยู่ในอนาคต (ถ้าไม่ใช่แสดงว่า generate loop ครอบคลุมแล้ว)
    if (nextStatementDate.isAfter(_dayOf(now))) {
      final openStartDate = statementDates.isNotEmpty
          ? statementDates.last.add(const Duration(days: 1))
          : account.startDate;
      final openStartDay = _dayOf(openStartDate);
      final openPaymentStartDay = statementDates.isNotEmpty
          ? _dayOf(statementDates.last).add(const Duration(days: 16))
          : _dayOf(account.startDate);
      final openEndDay = _dayOf(nextStatementDate);

      final openExpenses = cardTransactions.where((t) {
        final d = _dayOf(t.dateTime);
        return (t.type == TransactionType.expense ||
                t.type == TransactionType.debtRepay ||
                t.type == TransactionType.debtTransfer) &&
            t.accountId == account.id &&
            !d.isBefore(openStartDay) &&
            !d.isAfter(openEndDay);
      }).toList();

      final openExpensesAmount = openExpenses.fold<double>(0, (s, t) => s + t.amount);

      final openPayments = cardTransactions.where((t) {
        final d = _dayOf(t.dateTime);
        final isTransferPayment = (t.type == TransactionType.transfer ||
                t.type == TransactionType.debtRepay) &&
            t.toAccountId == account.id;
        final isIncomePayment = t.type == TransactionType.income &&
            t.accountId == account.id;
        return (isTransferPayment || isIncomePayment) &&
            !d.isBefore(openPaymentStartDay) &&
            !d.isAfter(openEndDay);
      }).toList();

      final openTotalPaid = _round(openPayments.fold<double>(0, (s, t) => s + t.amount));
      final openTotalAmount = _round(openExpensesAmount + carryOverAmount);
      final openRemaining = _round((openTotalAmount - openTotalPaid).clamp(0.0, double.infinity));

      bills.add(CreditCardBill(
        statementDate: nextStatementDate,
        startDate: openStartDate,
        dueDate: nextStatementDate.add(const Duration(days: 15)),
        expensesAmount: openExpensesAmount,
        carriedOverAmount: carryOverAmount,
        totalAmount: openTotalAmount,
        paidAmount: openTotalPaid,
        remainingAmount: openRemaining,
        overpaidAmount: 0,
        expenses: openExpenses,
        payments: openPayments,
        isFullyPaid: openTotalPaid >= openTotalAmount && openTotalAmount > 0,
        isOverpaid: false,
        hasPartialPaid: openTotalPaid > 0 && openRemaining > 0,
        isOpen: true,
      ));
    }

    // เรียงจากใหม่ไปเก่าสำหรับแสดงผล
    return bills.reversed.toList();
  }

  /// สร้างรายการวันสรุปยอดตั้งแต่ [from] จนถึง [until]
  static List<DateTime> _generateStatementDates({
    required int statementDay,
    required DateTime from,
    required DateTime until,
  }) {
    final dates = <DateTime>[];

    // หาวันสรุปยอดแรกที่อยู่ในหรือหลังวันสร้างบัญชี (เทียบระดับวัน)
    final fromDay = _dayOf(from);
    var current = _getStatementDateForMonth(statementDay, from.year, from.month);
    if (current.isBefore(fromDay)) {
      current = _getNextStatementDate(current, statementDay);
    }

    while (!current.isAfter(until)) {
      dates.add(current);
      current = _getNextStatementDate(current, statementDay);
    }

    return dates; // เรียงจากเก่าไปใหม่แล้ว
  }

  static DateTime _getStatementDateForMonth(int statementDay, int year, int month) {
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    final day = statementDay > lastDayOfMonth ? lastDayOfMonth : statementDay;
    return DateTime(year, month, day);
  }

  static DateTime _getNextStatementDate(DateTime current, int statementDay) {
    int nextMonth = current.month + 1;
    int nextYear = current.year;
    if (nextMonth > 12) {
      nextMonth = 1;
      nextYear++;
    }
    return _getStatementDateForMonth(statementDay, nextYear, nextMonth);
  }

  static DateTime _dayOf(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  /// ปัดเศษทศนิยมเหลือ 2 ตำแหน่ง เพื่อป้องกัน floating-point precision error
  static double _round(double v) => (v * 100).roundToDouble() / 100;

  /// คำนวณบิลปัจจุบัน (รอบล่าสุด)
  static CreditCardBill? getCurrentBill({
    required Account account,
    required List<AppTransaction> transactions,
  }) {
    final bills = calculateBills(account: account, transactions: transactions);
    return bills.isNotEmpty ? bills.first : null;
  }
}
