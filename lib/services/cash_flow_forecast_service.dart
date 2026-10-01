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

  /// ยังไม่ติ๊กทั้งที่วันที่ของรายการเลยวันนี้ไปแล้ว
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

/// งบประมาณหนึ่งรายการในรอบที่ระบุ ส่วนที่เหลือถือว่าจะถูกใช้จนหมด
class BudgetRemainingLine {
  final Budget budget;
  final double spent;
  final DateTime cycleStart;
  final DateTime cycleEnd;

  /// อยู่ใน forecast งวดถัดไป (ใช้การเลือกงบของงวดถัดไป)
  final bool isNextPeriod;

  const BudgetRemainingLine({
    required this.budget,
    required this.spent,
    required this.cycleStart,
    required this.cycleEnd,
    this.isNextPeriod = false,
  });

  double get remaining =>
      CashFlowForecastService._positive(budget.amount - spent);

  bool get isIncluded => isNextPeriod
      ? !budget.isExcludedFromNextCashForecast
      : !budget.isExcludedFromCashForecast;
}

/// ยอดที่ยังไม่สรุปของบัตรหนึ่งใบ ซึ่งสรุปหลังวันเคลียร์ยอดของงวดนี้ จึงไปอยู่งวดถัดไป
class NextCardLine {
  final Account account;
  final double unbilledAmount; // ยอดที่รูดไปแล้ว ณ วันนี้
  final DateTime statementDate;

  const NextCardLine({
    required this.account,
    required this.unbilledAmount,
    required this.statementDate,
  });

  double get total => unbilledAmount;
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
  final List<BudgetRemainingLine> savingsPlans;
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
      .where((l) => l.isIncluded)
      .fold(0.0, (sum, l) => sum + l.budget.amount);

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
  final List<BudgetRemainingLine> budgetLines;
  final List<BudgetRemainingLine> savingsPlans;
  final List<PlannedPurchase> purchases;

  /// บิลของบัตรแต่ละใบ (key = account id) เก็บไว้ใช้ต่อในงวดถัดไป
  final Map<String, List<CreditCardBill>> cardBills;

  const CashFlowForecast({
    required this.windowStart,
    required this.windowEnd,
    required this.liquidLines,
    required this.itemLines,
    required this.cardLines,
    this.cardBills = const {},
    this.budgetLines = const [],
    this.savingsPlans = const [],
    this.purchases = const [],
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

  double get budgetTotal => budgetLines
      .where((l) => l.isIncluded)
      .fold(0.0, (sum, l) => sum + l.remaining);

  double get savingsTotal => savingsPlans
      .where((l) => l.isIncluded)
      .fold(0.0, (sum, l) => sum + l.budget.amount);

  double get purchaseTotal => purchases
      .where((p) => p.isIncludedCurrent)
      .fold(0.0, (sum, p) => sum + p.amount);

  double get projectedLeftover =>
      liquidTotal +
      incomingTotal -
      outgoingTotal -
      cardTotal -
      budgetTotal -
      savingsTotal -
      purchaseTotal;

  /// จำนวนบัตรที่ผู้ใช้ควรตรวจ: เลยกำหนด หรือนับจากยอดที่ยังไม่สรุป
  int get warningCount =>
      cardLines.where((l) => l.isOverdue || l.hasUnclosedStatement).length;
}

/// คำนวณ Projected leftover ตามนิยามใน CONTEXT.md (Cash-flow forecast)
class CashFlowForecastService {
  static const _liquidTypes = {AccountType.cash, AccountType.bankAccount};

  /// งวด = วันถัดจากวันเคลียร์ยอดครั้งก่อน ถึงวันเคลียร์ยอดครั้งถัดไป (ตั้งแต่วันนี้)
  /// ([anchorDay] = วันเคลียร์ยอด เช่น วันเงินเดือนออกและจ่ายหนี้); คืน null เมื่อยังไม่ได้ตั้ง
  static CashFlowForecast? calculate({
    required DateTime today,
    required int? anchorDay,
    required List<Account> accounts,
    required double Function(Account account) balanceInThb,
    required List<AppTransaction> transactions,
    required List<FixedCashFlowItem> items,
    required List<FixedCashFlowPaidMark> paidMarks,
    List<Budget> budgets = const [],
    List<PlannedPurchase> plannedPurchases = const [],
    int monthlyCycleStartDay = 1,
  }) {
    if (anchorDay == null) return null;

    final day = _dayOf(today);
    final settleDate = _firstAnchorOnOrAfter(anchorDay, day);
    final windowStart = _dayAfter(
      clampedDayOfMonth(settleDate.year, settleDate.month - 1, anchorDay),
    );
    final cardBills = _cardBills(accounts, transactions, day);

    return CashFlowForecast(
      windowStart: windowStart,
      windowEnd: settleDate,
      liquidLines: _liquidLines(accounts, balanceInThb),
      itemLines: _itemLines(items, paidMarks, windowStart, settleDate, day),
      cardLines: _cardLines(accounts, cardBills, settleDate, day),
      cardBills: cardBills,
      purchases: plannedPurchases,
      budgetLines: _budgetLines(
        budgets,
        accounts,
        transactions,
        day,
        monthlyCycleStartDay,
        day,
        settleDate,
        BudgetType.expense,
      ),
      savingsPlans: _budgetLines(
        budgets,
        accounts,
        transactions,
        day,
        monthlyCycleStartDay,
        day,
        settleDate,
        BudgetType.savings,
      ),
    );
  }

  /// คาดการณ์งวดถัดไป (ถึงวันเคลียร์ยอดครั้งถัดไป) ต่อจาก [current] โดยนับเพิ่ม:
  /// รายการประจำของงวดถัดไป, ยอดที่ยังไม่สรุปของบิลที่สรุปหลังวันเคลียร์ยอดของงวดนี้,
  /// งบและแผนออมของรอบที่สิ้นสุดในงวดถัดไป; หักรายการอยากซื้อที่เลือกสำหรับงวดถัดไป
  static NextPeriodForecast calculateNextPeriod({
    required CashFlowForecast current,
    required DateTime today,
    required int monthlyCycleStartDay,
    required int anchorDay,
    required List<Account> accounts,
    required List<AppTransaction> transactions,
    required List<FixedCashFlowItem> items,
    required List<FixedCashFlowPaidMark> paidMarks,
    required List<Budget> budgets,
    required List<PlannedPurchase> plannedPurchases,
  }) {
    final day = _dayOf(today);
    final settleDate = current.windowEnd;
    final windowStart = _dayAfter(settleDate);
    final windowEnd = clampedDayOfMonth(
      settleDate.year,
      settleDate.month + 1,
      anchorDay,
    );

    return NextPeriodForecast(
      windowStart: windowStart,
      windowEnd: windowEnd,
      startingLeftover: current.projectedLeftover,
      itemLines: _itemLines(items, paidMarks, windowStart, windowEnd, day),
      cardLines: [
        for (final card in accounts)
          if (current.cardBills[card.id] case final bills?)
            ?_nextCardLine(card, bills, settleDate),
      ],
      budgetLines: _budgetLines(
        budgets,
        accounts,
        transactions,
        day,
        monthlyCycleStartDay,
        windowStart,
        windowEnd,
        BudgetType.expense,
        isNextPeriod: true,
      ),
      savingsPlans: _budgetLines(
        budgets,
        accounts,
        transactions,
        day,
        monthlyCycleStartDay,
        windowStart,
        windowEnd,
        BudgetType.savings,
        isNextPeriod: true,
      ),
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
    DateTime settleDate,
    DateTime today,
  ) => [
    for (final card in accounts)
      if (cardBills[card.id] case final bills?)
        ?_cardLine(card, bills, settleDate, today),
  ];

  /// หนี้บัตรที่ต้องเคลียร์ในวันเคลียร์ยอด: ยอดค้างของบิลที่สรุปแล้ว
  /// และยอดที่รูดไปแล้วของบิลที่จะสรุปก่อนวันเคลียร์ยอด (ยังไม่สรุป)
  static CardObligationLine? _cardLine(
    Account card,
    List<CreditCardBill> bills,
    DateTime settleDate,
    DateTime today,
  ) {
    final split = _splitBills(bills);
    final openBill = split.openBill;
    final isUnclosedBeforeSettle =
        openBill != null && openBill.statementDate.isBefore(settleDate);
    final unbilled = isUnclosedBeforeSettle ? split.unbilledAmount : 0.0;
    final outstanding = split.statementAmount + unbilled;
    if (outstanding == 0) return null;

    final latestDue = split.latestClosed?.dueDate;
    return CardObligationLine(
      account: card,
      outstanding: outstanding,
      dueDate: split.statementAmount > 0 ? latestDue : openBill?.dueDate,
      isOverdue:
          split.statementAmount > 0 &&
          latestDue != null &&
          latestDue.isBefore(today),
      hasUnclosedStatement: unbilled > 0,
    );
  }

  /// ยอดที่ยังไม่สรุปของบิลที่สรุปหลังวันเคลียร์ยอดของงวดนี้ (ไปอยู่งวดถัดไป)
  static NextCardLine? _nextCardLine(
    Account card,
    List<CreditCardBill> bills,
    DateTime settleDate,
  ) {
    final split = _splitBills(bills);
    final openBill = split.openBill;
    if (openBill == null || openBill.statementDate.isBefore(settleDate)) {
      return null;
    }
    if (split.unbilledAmount == 0) return null;
    return NextCardLine(
      account: card,
      unbilledAmount: split.unbilledAmount,
      statementDate: openBill.statementDate,
    );
  }

  /// แยกยอดบัตร ณ วันนี้เป็นยอดค้างของบิลที่สรุปแล้ว และยอดที่รูดไปแล้วของบิลที่ยังเปิดอยู่
  static ({
    double statementAmount,
    double unbilledAmount,
    CreditCardBill? latestClosed,
    CreditCardBill? openBill,
  })
  _splitBills(List<CreditCardBill> bills) {
    final openBill = bills.where((b) => b.isOpen).firstOrNull;
    // bills เรียงใหม่ → เก่า; รอบที่ปิดล่าสุดมียอดค้างของรอบก่อน ๆ ยกมาแล้ว
    final latest = bills.where((b) => !b.isOpen).firstOrNull;
    // การชำระหลัง due date ของรอบล่าสุดถูกนับเข้ารอบเปิด: หักยอดค้างรอบล่าสุดก่อน
    // ส่วนที่เกินถือเป็นการจ่ายล่วงหน้าให้รอบที่ยังเปิด
    final paidAfterDue = openBill?.paidAmount ?? 0;
    final latestRemaining = latest?.remainingAmount ?? 0;
    final prepaid = _positive(paidAfterDue - latestRemaining);
    return (
      statementAmount: _positive(latestRemaining - paidAfterDue),
      unbilledAmount: openBill == null
          ? 0
          : _positive(openBill.expensesAmount - prepaid),
      latestClosed: latest,
      openBill: openBill,
    );
  }

  /// จัดงบตามวันสิ้นสุดรอบ: รอบปัจจุบันหักยอดใช้จริง รอบอนาคตกันเต็มจำนวน
  static List<BudgetRemainingLine> _budgetLines(
    List<Budget> budgets,
    List<Account> accounts,
    List<AppTransaction> transactions,
    DateTime today,
    int monthlyCycleStartDay,
    DateTime windowStart,
    DateTime windowEnd,
    BudgetType type, {
    bool isNextPeriod = false,
  }) {
    final lines = <BudgetRemainingLine>[];
    var month = monthlyCycleReportingMonth(today, monthlyCycleStartDay);
    while (true) {
      final cycle = monthlyCyclePeriod(month, monthlyCycleStartDay);
      final cycleEnd = DateTime(
        cycle.endExclusive.year,
        cycle.endExclusive.month,
        cycle.endExclusive.day - 1,
      );
      if (cycleEnd.isAfter(windowEnd)) break;
      if (!cycleEnd.isBefore(windowStart)) {
        final spentByCategoryId =
            type == BudgetType.expense && !cycle.start.isAfter(today)
            ? BudgetSpendingService.spentByCategoryId(
                transactions: transactions,
                start: cycle.start,
                end: _dayAfter(today).subtract(const Duration(microseconds: 1)),
                accounts: accounts,
              )
            : <String, double>{};
        for (final budget in budgets) {
          if (budget.type != type || budget.isHidden) continue;
          lines.add(
            BudgetRemainingLine(
              budget: budget,
              spent: BudgetSpendingService.spentFor(budget, spentByCategoryId),
              cycleStart: cycle.start,
              cycleEnd: cycleEnd,
              isNextPeriod: isNextPeriod,
            ),
          );
        }
      }
      month = DateTime(month.year, month.month + 1);
    }
    return lines;
  }

  static DateTime _firstAnchorOnOrAfter(int anchorDay, DateTime from) {
    final sameMonth = clampedDayOfMonth(from.year, from.month, anchorDay);
    if (!sameMonth.isBefore(from)) return sameMonth;
    return clampedDayOfMonth(from.year, from.month + 1, anchorDay);
  }

  static DateTime _dayAfter(DateTime d) => DateTime(d.year, d.month, d.day + 1);

  static double _positive(double value) {
    final rounded = (value * 100).roundToDouble() / 100;
    return rounded > 0 ? rounded : 0;
  }

  static DateTime _dayOf(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}
