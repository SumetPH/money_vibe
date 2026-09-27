import '../models/account.dart';
import '../models/budget.dart';
import '../models/fixed_cash_flow_item.dart';
import '../models/planned_purchase.dart';
import '../models/transaction.dart';
import '../utils/monthly_cycle.dart';
import 'budget_spending_service.dart';
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

/// งบประมาณหนึ่งรายการในรอบเดือนปัจจุบัน ส่วนที่เหลือถือว่าจะถูกใช้จนหมด
class BudgetRemainingLine {
  final Budget budget;
  final double spent;

  const BudgetRemainingLine({required this.budget, required this.spent});

  double get remaining =>
      CashFlowForecastService._positive(budget.amount - spent);

  bool get isIncluded => !budget.isExcludedFromCashForecast;
}

/// ยอดบัตรเครดิตหนึ่งใบที่นับในงวดถัดไป: ทุกยอดที่งวดนี้ยังไม่ได้นับ
class NextCardLine {
  final Account account;
  final double statementAmount; // ยอดรอบที่สรุปแล้วแต่ครบกำหนดหลังงวดนี้
  final DateTime? statementDueDate;
  final double
  unbilledAmount; // ยอดที่ยังไม่สรุป ณ วันนี้ (อาจครบกำหนดหลังงวดถัดไป)
  final DateTime? unbilledDueDate;

  const NextCardLine({
    required this.account,
    required this.statementAmount,
    required this.statementDueDate,
    required this.unbilledAmount,
    required this.unbilledDueDate,
  });

  double get total => statementAmount + unbilledAmount;
}

/// คาดการณ์งวดถัดไป เริ่มจาก projected leftover ของงวดนี้
class NextPeriodForecast {
  final DateTime windowStart;
  final DateTime windowEnd;
  final double startingLeftover;
  final List<CashFlowItemLine> itemLines;
  final List<NextCardLine> cardLines;
  final List<BudgetRemainingLine> budgetLines; // รวมงบที่ถูกตัดออก

  /// แผนออม (งบประเภทออม/ลงทุน) นับเต็มเป้าหมาย เพราะไม่มีการติดตามยอดที่ออมแล้ว
  /// (รวมแผนที่ผู้ใช้ตัดออก เพื่อให้ UI เลือกได้)
  final List<Budget> savingsPlans;
  final List<PlannedPurchase> purchases;

  const NextPeriodForecast({
    required this.windowStart,
    required this.windowEnd,
    required this.startingLeftover,
    required this.itemLines,
    required this.cardLines,
    required this.budgetLines,
    required this.savingsPlans,
    required this.purchases,
  });

  double get incomingTotal => itemLines
      .where((l) => l.isCounted && l.item.isIncoming)
      .fold(0.0, (sum, l) => sum + l.item.amount);

  double get outgoingTotal => itemLines
      .where((l) => l.isCounted && !l.item.isIncoming)
      .fold(0.0, (sum, l) => sum + l.item.amount);

  double get cardTotal => cardLines.fold(0.0, (sum, l) => sum + l.total);

  double get budgetTotal => budgetLines
      .where((l) => l.isIncluded)
      .fold(0.0, (sum, l) => sum + l.remaining);

  double get savingsTotal => savingsPlans
      .where((b) => !b.isExcludedFromCashForecast)
      .fold(0.0, (sum, b) => sum + b.amount);

  double get purchaseTotal => purchases
      .where((p) => p.isIncluded)
      .fold(0.0, (sum, p) => sum + p.amount);

  double get projectedLeftover =>
      startingLeftover +
      incomingTotal -
      outgoingTotal -
      cardTotal -
      budgetTotal -
      savingsTotal -
      purchaseTotal;
}

class CashFlowForecast {
  final DateTime windowStart;
  final DateTime windowEnd;
  final List<LiquidBalanceLine> liquidLines;
  final List<CashFlowItemLine> itemLines;
  final List<CardObligationLine> cardLines;

  /// บิลของบัตรแต่ละใบ (key = account id) เก็บไว้ใช้ต่อในงวดถัดไป
  final Map<String, List<CreditCardBill>> cardBills;

  const CashFlowForecast({
    required this.windowStart,
    required this.windowEnd,
    required this.liquidLines,
    required this.itemLines,
    required this.cardLines,
    this.cardBills = const {},
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

  /// งวด = รอบเดือน (monthly financial cycle) ที่มี [today] อยู่
  static CashFlowForecast calculate({
    required DateTime today,
    required int monthlyCycleStartDay,
    required List<Account> accounts,
    required double Function(Account account) balanceInThb,
    required List<AppTransaction> transactions,
    required List<FixedCashFlowItem> items,
    required List<FixedCashFlowPaidMark> paidMarks,
  }) {
    final day = _dayOf(today);
    final window = _cycleWindow(day, monthlyCycleStartDay);
    final cardBills = _cardBills(accounts, transactions, day);

    return CashFlowForecast(
      windowStart: window.start,
      windowEnd: window.end,
      liquidLines: _liquidLines(accounts, balanceInThb),
      itemLines: _itemLines(items, paidMarks, window.start, window.end, day),
      cardLines: _cardLines(accounts, cardBills, window.end, day),
      cardBills: cardBills,
    );
  }

  /// คาดการณ์งวดถัดไปต่อจาก [current] โดยนับเพิ่ม: รายการประจำของงวดถัดไป,
  /// ยอดบัตรทั้งหมดที่งวดนี้ยังไม่ได้นับ (รวมยอดที่ยังไม่สรุป), งบที่เหลือของรอบเดือนนี้,
  /// แผนออมเต็มเป้าหมาย และรายการอยากซื้อที่เปิดไว้
  static NextPeriodForecast calculateNextPeriod({
    required CashFlowForecast current,
    required DateTime today,
    required int monthlyCycleStartDay,
    required List<Account> accounts,
    required List<AppTransaction> transactions,
    required List<FixedCashFlowItem> items,
    required List<FixedCashFlowPaidMark> paidMarks,
    required List<Budget> budgets,
    required List<PlannedPurchase> plannedPurchases,
  }) {
    final day = _dayOf(today);
    final end = current.windowEnd;
    final window = _cycleWindow(
      DateTime(end.year, end.month, end.day + 1),
      monthlyCycleStartDay,
    );
    final windowStart = window.start;
    final windowEnd = window.end;

    return NextPeriodForecast(
      windowStart: windowStart,
      windowEnd: windowEnd,
      startingLeftover: current.projectedLeftover,
      itemLines: _itemLines(items, paidMarks, windowStart, windowEnd, day),
      cardLines: [
        for (final card in accounts)
          if (current.cardBills[card.id] case final bills?)
            ?_nextCardLine(card, bills, current.windowEnd),
      ],
      budgetLines: _budgetLines(
        budgets,
        accounts,
        transactions,
        day,
        monthlyCycleStartDay,
      ),
      savingsPlans: [
        for (final budget in budgets)
          if (budget.type == BudgetType.savings && !budget.isHidden) budget,
      ],
      purchases: plannedPurchases,
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
      for (final date in item.occurrencesBetween(windowStart, windowEnd)) {
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
    }
    lines.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : a.item.name.compareTo(b.item.name);
    });
    return lines;
  }

  /// บิลของบัตรเครดิตทุกใบที่ตั้งวันสรุปยอดแล้ว (bills เรียงใหม่ → เก่า)
  static Map<String, List<CreditCardBill>> _cardBills(
    List<Account> accounts,
    List<AppTransaction> transactions,
    DateTime today,
  ) => {
    for (final card in accounts)
      if (card.type == AccountType.creditCard && card.statementDay != null)
        card.id: CreditCardBillService.calculateBills(
          account: card,
          transactions: CreditCardBillService.filterCardTransactions(
            card.id,
            transactions,
          ),
          now: today,
        ),
  };

  static List<CardObligationLine> _cardLines(
    List<Account> accounts,
    Map<String, List<CreditCardBill>> cardBills,
    DateTime windowEnd,
    DateTime today,
  ) => [
    for (final card in accounts)
      if (cardBills[card.id] case final bills?)
        ?_cardLine(card, bills, windowEnd, today),
  ];

  static CardObligationLine? _cardLine(
    Account card,
    List<CreditCardBill> bills,
    DateTime windowEnd,
    DateTime today,
  ) {
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

  /// ยอดบัตรที่ต้องชำระในงวดถัดไป ([windowEnd] คือวันสิ้นสุดงวดปัจจุบัน)
  static NextCardLine? _nextCardLine(
    Account card,
    List<CreditCardBill> bills,
    DateTime windowEnd,
  ) {
    final openBill = bills.where((b) => b.isOpen).firstOrNull;
    final closedBills = bills.where((b) => !b.isOpen).toList();
    final latest = closedBills.firstOrNull;
    // การชำระหลัง due date ของรอบล่าสุด ส่วนที่เกินยอดรอบล่าสุดถือเป็นการจ่ายล่วงหน้าให้รอบที่ยังเปิด
    var prepaid = openBill?.paidAmount ?? 0;
    var statementAmount = 0.0;
    DateTime? statementDue;

    if (latest != null) {
      if (!latest.dueDate.isAfter(windowEnd)) {
        prepaid = _positive(prepaid - latest.remainingAmount);
      } else {
        // ยอดค้างเลยกำหนดที่ยกมาถูกนับในงวดปัจจุบันแล้ว
        final overdueCounted = closedBills.length < 2
            ? 0.0
            : _positive(latest.carriedOverAmount - latest.paidAmount);
        statementAmount = _positive(
          latest.remainingAmount - prepaid - overdueCounted,
        );
        prepaid = 0;
        statementDue = latest.dueDate;
      }
    }

    // นับยอดที่ยังไม่สรุปแม้ครบกำหนดหลังงวดถัดไป เพื่อให้เห็นผลของบัตรที่รูดไปแล้ว
    final unbilledAmount = openBill == null
        ? 0.0
        : _positive(openBill.expensesAmount - prepaid);
    if (statementAmount == 0 && unbilledAmount == 0) return null;
    return NextCardLine(
      account: card,
      statementAmount: statementAmount,
      statementDueDate: statementAmount > 0 ? statementDue : null,
      unbilledAmount: unbilledAmount,
      unbilledDueDate: unbilledAmount > 0 ? openBill?.dueDate : null,
    );
  }

  /// งบรายจ่าย (ไม่ซ่อน) ของรอบเดือนที่มี [today] อยู่ รวมงบที่ถูกตัดออก เพื่อให้ UI เลือกได้
  static List<BudgetRemainingLine> _budgetLines(
    List<Budget> budgets,
    List<Account> accounts,
    List<AppTransaction> transactions,
    DateTime today,
    int monthlyCycleStartDay,
  ) {
    final cycle = monthlyCyclePeriod(
      monthlyCycleReportingMonth(today, monthlyCycleStartDay),
      monthlyCycleStartDay,
    );
    final spentByCategoryId = BudgetSpendingService.spentByCategoryId(
      transactions: transactions,
      start: cycle.start,
      end: cycle.endExclusive.subtract(const Duration(microseconds: 1)),
      accounts: accounts,
    );
    return [
      for (final budget in budgets)
        if (budget.type == BudgetType.expense && !budget.isHidden)
          BudgetRemainingLine(
            budget: budget,
            spent: BudgetSpendingService.spentFor(budget, spentByCategoryId),
          ),
    ];
  }

  /// รอบเดือนที่มี [day] อยู่ (วันสุดท้าย inclusive)
  static ({DateTime start, DateTime end}) _cycleWindow(
    DateTime day,
    int monthlyCycleStartDay,
  ) {
    final cycle = monthlyCyclePeriod(
      monthlyCycleReportingMonth(day, monthlyCycleStartDay),
      monthlyCycleStartDay,
    );
    final end = cycle.endExclusive;
    return (
      start: cycle.start,
      end: DateTime(end.year, end.month, end.day - 1),
    );
  }

  static double _positive(double value) {
    final rounded = (value * 100).roundToDouble() / 100;
    return rounded > 0 ? rounded : 0;
  }

  static DateTime _dayOf(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}
