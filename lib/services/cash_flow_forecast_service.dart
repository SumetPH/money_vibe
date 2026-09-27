import '../models/account.dart';
import '../models/fixed_cash_flow_item.dart';
import '../models/transaction.dart';
import '../utils/monthly_cycle.dart';
import 'credit_card_bill_service.dart';

/// ยอดของ Liquid account หนึ่งบัญชี (รวมบัญชีที่ถูกตัดออก เพื่อให้ UI เลือกได้)
class LiquidBalanceLine {
  final Account account;
  final double balance; // THB
  final bool isIncluded;

  const LiquidBalanceLine({
    required this.account,
    required this.balance,
    required this.isIncluded,
  });
}

/// รายการประจำหนึ่งครั้งที่ตกอยู่ใน forecast window
class CashFlowItemLine {
  final FixedCashFlowItem item;
  final DateTime date;
  final bool isMarked;
  final bool isOverdueUnmarked;

  const CashFlowItemLine({
    required this.item,
    required this.date,
    required this.isMarked,
    required this.isOverdueUnmarked,
  });

  bool get isCounted => !isMarked;
  String get monthKey => cashFlowMonthKey(date);
  double get signedAmount => item.signedAmount;
}

/// ภาระของบัตรเครดิตหนึ่งใบใน forecast window
class CardObligationLine {
  final Account account;
  final double outstanding;
  final DateTime? dueDate;
  final bool isOverdue;
  final bool hasUnclosedStatement;

  const CardObligationLine({
    required this.account,
    required this.outstanding,
    required this.dueDate,
    required this.isOverdue,
    required this.hasUnclosedStatement,
  });
}

class CashFlowForecast {
  final DateTime windowStart;
  final DateTime windowEnd;
  final DateTime cyclePayday;
  final List<LiquidBalanceLine> liquidLines;
  final List<CashFlowItemLine> itemLines;
  final List<CardObligationLine> cardLines;

  const CashFlowForecast({
    required this.windowStart,
    required this.windowEnd,
    required this.cyclePayday,
    required this.liquidLines,
    required this.itemLines,
    required this.cardLines,
  });

  double get liquidTotal => liquidLines
      .where((l) => l.isIncluded)
      .fold(0.0, (sum, l) => sum + l.balance);

  double get incomingTotal => itemLines
      .where((l) => l.isCounted && l.item.isIncoming)
      .fold(0.0, (sum, l) => sum + l.item.amount);

  double get outgoingTotal => itemLines
      .where((l) => l.isCounted && !l.item.isIncoming)
      .fold(0.0, (sum, l) => sum + l.item.amount);

  double get cardTotal => cardLines.fold(0.0, (sum, l) => sum + l.outstanding);

  double get projectedLeftover =>
      liquidTotal + incomingTotal - outgoingTotal - cardTotal;

  /// จำนวนรายการที่ผู้ใช้ควรตรวจ: ยังไม่ติ๊กทั้งที่เลยวัน, บัตรเลยกำหนด, บัตรยังไม่สรุปยอด
  int get warningCount =>
      itemLines.where((l) => l.isOverdueUnmarked).length +
      cardLines.where((l) => l.isOverdue || l.hasUnclosedStatement).length;
}

/// คำนวณ Projected leftover ตามนิยามใน CONTEXT.md (Cash-flow forecast)
class CashFlowForecastService {
  static const _liquidTypes = {AccountType.cash, AccountType.bankAccount};

  /// คืน null เมื่อยังไม่มี payday item
  static CashFlowForecast? calculate({
    required DateTime today,
    required int monthlyCycleStartDay,
    required List<Account> accounts,
    required double Function(Account account) balanceInThb,
    required List<AppTransaction> transactions,
    required List<FixedCashFlowItem> items,
    required List<FixedCashFlowPaidMark> paidMarks,
  }) {
    final payday = items.where((i) => i.isPayday).firstOrNull;
    if (payday == null) return null;

    final day = _dayOf(today);
    final cycle = monthlyCyclePeriod(
      monthlyCycleReportingMonth(day, monthlyCycleStartDay),
      monthlyCycleStartDay,
    );
    final windowStart = cycle.start;
    final cyclePayday = _firstOccurrenceOnOrAfter(payday, windowStart);
    final nextPayday = payday.occurrenceIn(
      cyclePayday.year,
      cyclePayday.month + 1,
    );
    final windowEnd = nextPayday.subtract(const Duration(days: 1));

    return CashFlowForecast(
      windowStart: windowStart,
      windowEnd: windowEnd,
      cyclePayday: cyclePayday,
      liquidLines: _liquidLines(accounts, balanceInThb),
      itemLines: _itemLines(items, paidMarks, windowStart, windowEnd, day),
      cardLines: _cardLines(accounts, transactions, windowEnd, day),
    );
  }

  static List<LiquidBalanceLine> _liquidLines(
    List<Account> accounts,
    double Function(Account account) balanceInThb,
  ) => [
    for (final account in accounts)
      if (_liquidTypes.contains(account.type))
        LiquidBalanceLine(
          account: account,
          balance: balanceInThb(account),
          isIncluded: !account.isExcludedFromCashForecast,
        ),
  ];

  static List<CashFlowItemLine> _itemLines(
    List<FixedCashFlowItem> items,
    List<FixedCashFlowPaidMark> paidMarks,
    DateTime windowStart,
    DateTime windowEnd,
    DateTime today,
  ) {
    final marked = {for (final m in paidMarks) '${m.itemId}|${m.month}'};
    final lines = <CashFlowItemLine>[];
    for (final item in items) {
      var month = DateTime(windowStart.year, windowStart.month);
      while (!month.isAfter(windowEnd)) {
        final date = item.occurrenceIn(month.year, month.month);
        if (!date.isBefore(windowStart) && !date.isAfter(windowEnd)) {
          final isMarked = marked.contains(
            '${item.id}|${cashFlowMonthKey(date)}',
          );
          lines.add(
            CashFlowItemLine(
              item: item,
              date: date,
              isMarked: isMarked,
              isOverdueUnmarked: !isMarked && date.isBefore(today),
            ),
          );
        }
        month = DateTime(month.year, month.month + 1);
      }
    }
    lines.sort((a, b) => a.date.compareTo(b.date));
    return lines;
  }

  static List<CardObligationLine> _cardLines(
    List<Account> accounts,
    List<AppTransaction> transactions,
    DateTime windowEnd,
    DateTime today,
  ) {
    final lines = <CardObligationLine>[];
    for (final card in accounts) {
      if (card.type != AccountType.creditCard || card.statementDay == null) {
        continue;
      }
      final line = _cardLine(card, transactions, windowEnd, today);
      if (line != null) lines.add(line);
    }
    return lines;
  }

  static CardObligationLine? _cardLine(
    Account card,
    List<AppTransaction> transactions,
    DateTime windowEnd,
    DateTime today,
  ) {
    final bills = CreditCardBillService.calculateBills(
      account: card,
      transactions: CreditCardBillService.filterCardTransactions(
        card.id,
        transactions,
      ),
      now: today,
    );
    final openBill = bills.where((b) => b.isOpen).firstOrNull;
    // bills เรียงใหม่ → เก่า; รอบที่ปิดล่าสุดมียอดค้างของรอบก่อน ๆ ยกมาแล้ว
    final closedBills = bills.where((b) => !b.isOpen).toList();
    final hasUnclosedStatement =
        openBill != null && !openBill.dueDate.isAfter(windowEnd);
    final obligation = closedBills.isEmpty
        ? null
        : _closedObligation(closedBills, openBill, windowEnd);

    if (obligation == null && !hasUnclosedStatement) return null;
    return CardObligationLine(
      account: card,
      outstanding: obligation?.amount ?? 0,
      dueDate: obligation?.dueDate ?? openBill?.dueDate,
      isOverdue: obligation != null && obligation.dueDate.isBefore(today),
      hasUnclosedStatement: hasUnclosedStatement,
    );
  }

  /// ยอดค้างของรอบที่ปิดแล้วที่ต้องจ่ายภายใน window (null = ไม่มี)
  static ({double amount, DateTime dueDate})? _closedObligation(
    List<CreditCardBill> closedBills,
    CreditCardBill? openBill,
    DateTime windowEnd,
  ) {
    final latest = closedBills.first;
    if (!latest.dueDate.isAfter(windowEnd)) {
      // การชำระหลัง due date ของรอบล่าสุดถูกนับเข้ารอบเปิด จึงหักออกที่นี่
      final amount = _positive(
        latest.remainingAmount - (openBill?.paidAmount ?? 0),
      );
      return amount > 0 ? (amount: amount, dueDate: latest.dueDate) : null;
    }
    // รอบล่าสุดครบกำหนดหลัง window: นับเฉพาะยอดค้างเลยกำหนดที่ยกมา
    // (การชำระในช่วงชำระของรอบล่าสุดหักยอดยกมาก่อน)
    if (closedBills.length < 2) return null;
    final overdue = _positive(latest.carriedOverAmount - latest.paidAmount);
    return overdue > 0
        ? (amount: overdue, dueDate: closedBills[1].dueDate)
        : null;
  }

  static DateTime _firstOccurrenceOnOrAfter(
    FixedCashFlowItem item,
    DateTime from,
  ) {
    final sameMonth = item.occurrenceIn(from.year, from.month);
    if (!sameMonth.isBefore(from)) return sameMonth;
    return item.occurrenceIn(from.year, from.month + 1);
  }

  static double _positive(double value) {
    final rounded = (value * 100).roundToDouble() / 100;
    return rounded > 0 ? rounded : 0;
  }

  static DateTime _dayOf(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}
