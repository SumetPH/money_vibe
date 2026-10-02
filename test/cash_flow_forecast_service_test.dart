import 'package:flutter/material.dart';
import 'package:money_vibe/models/budget.dart';
import 'package:money_vibe/models/budget_forecast_setting.dart';
import 'package:money_vibe/models/planned_purchase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_vibe/models/account.dart';
import 'package:money_vibe/models/fixed_cash_flow_item.dart';
import 'package:money_vibe/models/transaction.dart';
import 'package:money_vibe/services/cash_flow_forecast_service.dart';

final _bank = Account(
  id: 'bank',
  name: 'Bank',
  type: AccountType.bankAccount,
  startDate: DateTime(2026, 1, 1),
);

Account _card({String id = 'card', int? paymentDueDay}) => Account(
  id: id,
  name: 'Card $id',
  type: AccountType.creditCard,
  startDate: DateTime(2026, 7, 1),
  statementDay: 20,
  paymentDueDay: paymentDueDay,
);

const _salary = FixedCashFlowItem(
  id: 'salary',
  name: 'เงินเดือน',
  amount: 50000,
  direction: CashFlowDirection.incoming,
  period: CashFlowPeriod.current,
);

const _house = FixedCashFlowItem(
  id: 'house',
  name: 'ค่าบ้าน',
  amount: 15000,
  direction: CashFlowDirection.outgoing,
  period: CashFlowPeriod.current,
);

AppTransaction _spend(String cardId, DateTime date, double amount) =>
    AppTransaction(
      id: 'spend-$cardId-${date.toIso8601String()}',
      type: TransactionType.expense,
      amount: amount,
      accountId: cardId,
      dateTime: date,
    );

AppTransaction _payCard(String cardId, DateTime date, double amount) =>
    AppTransaction(
      id: 'pay-$cardId-${date.toIso8601String()}',
      type: TransactionType.transfer,
      amount: amount,
      accountId: 'bank',
      toAccountId: cardId,
      dateTime: date,
    );

CashFlowForecast? _forecast({
  required DateTime today,
  List<Account>? accounts,
  Map<String, double> balances = const {'bank': 20000},
  List<AppTransaction> transactions = const [],
  List<FixedCashFlowItem> items = const [_salary],
  int? anchorDay = 30,
}) => CashFlowForecastService.calculate(
  today: today,
  anchorDay: anchorDay,
  accounts: accounts ?? [_bank],
  balanceInThb: (account) => balances[account.id] ?? 0,
  transactions: transactions,
  items: items,
);

void main() {
  test('each window counts only its own list and skips ticked rows', () {
    const items = [
      _salary,
      _house,
      FixedCashFlowItem(
        id: 'paid',
        name: 'Paid',
        amount: 1000,
        direction: CashFlowDirection.outgoing,
        period: CashFlowPeriod.current,
        isDone: true,
      ),
      FixedCashFlowItem(
        id: 'next-salary',
        name: 'Next salary',
        amount: 40000,
        direction: CashFlowDirection.incoming,
        period: CashFlowPeriod.next,
      ),
    ];
    const purchases = [
      PlannedPurchase(
        id: 'phone',
        name: 'Phone',
        amount: 5000,
        period: CashFlowPeriod.current,
        isIncluded: true,
      ),
      PlannedPurchase(
        id: 'idea',
        name: 'Just listed',
        amount: 900,
        period: CashFlowPeriod.current,
      ),
      PlannedPurchase(
        id: 'trip',
        name: 'Trip',
        amount: 3000,
        period: CashFlowPeriod.next,
        isIncluded: true,
      ),
    ];
    final current = CashFlowForecastService.calculate(
      today: DateTime(2026, 10, 1),
      anchorDay: 30,
      accounts: [_bank],
      balanceInThb: (_) => 20000,
      transactions: [],
      items: items,
      plannedPurchases: purchases,
    )!;
    final next = CashFlowForecastService.calculateNextPeriod(
      current: current,
      today: DateTime(2026, 10, 1),
      monthlyCycleStartDay: 21,
      anchorDay: 30,
      accounts: [_bank],
      transactions: [],
      items: items,
      budgets: [],
      plannedPurchases: purchases,
    );

    expect(current.items.map((i) => i.id), ['salary', 'house', 'paid']);
    expect(current.incomingTotal, 50000);
    expect(current.outgoingTotal, 15000);
    expect(current.purchaseTotal, 5000);
    expect(current.projectedLeftover, 20000 + 50000 - 15000 - 5000);
    expect(next.items.map((i) => i.id), ['next-salary']);
    expect(next.purchaseTotal, 3000);
    expect(next.projectedLeftover, current.projectedLeftover + 40000 - 3000);
  });

  test('lists stay put when the clear day passes', () {
    const items = [
      FixedCashFlowItem(
        id: 'next-only',
        name: 'Next only',
        amount: 1000,
        direction: CashFlowDirection.outgoing,
        period: CashFlowPeriod.next,
      ),
    ];
    final afterClearDay = CashFlowForecastService.calculate(
      today: DateTime(2026, 10, 31),
      anchorDay: 30,
      accounts: [_bank],
      balanceInThb: (_) => 20000,
      transactions: [],
      items: items,
    )!;

    expect(afterClearDay.items, isEmpty);
    expect(afterClearDay.projectedLeftover, 20000);
  });

  test('rows round-trip and old backups default to the current list', () {
    final item = _house.copyWith(period: CashFlowPeriod.next, isDone: true);
    final restored = FixedCashFlowItem.fromMap(item.toMap());
    expect(restored.period, CashFlowPeriod.next);
    expect(restored.isDone, isTrue);
    final legacy = PlannedPurchase.fromMap({
      'id': 'legacy',
      'name': 'Legacy',
      'amount': 100,
    });
    expect(legacy.period, CashFlowPeriod.current);
    expect(legacy.isIncluded, isFalse);
  });

  test('budget settings apply only to the window of their clear day', () {
    const food = Budget(
      id: 'food',
      name: 'Food',
      amount: 10000,
      categoryIds: ['food'],
      icon: Icons.restaurant,
      color: Colors.blue,
    );
    final budgets = [food, food.copyWith(id: 'travel')];
    final settings = [
      BudgetForecastSetting(
        id: 's1',
        budgetId: 'food',
        periodEnd: DateTime(2026, 10, 30),
        isExcluded: true,
      ),
      BudgetForecastSetting(
        id: 's2',
        budgetId: 'travel',
        periodEnd: DateTime(2026, 11, 30),
        isExcluded: true,
      ),
    ];
    ({CashFlowForecast current, NextPeriodForecast next}) run(DateTime today) {
      final current = CashFlowForecastService.calculate(
        today: today,
        anchorDay: 30,
        monthlyCycleStartDay: 21,
        accounts: [_bank],
        balanceInThb: (_) => 20000,
        transactions: [],
        items: [],
        budgets: budgets,
        budgetSettings: settings,
      )!;
      final next = CashFlowForecastService.calculateNextPeriod(
        current: current,
        today: today,
        monthlyCycleStartDay: 21,
        anchorDay: 30,
        accounts: [_bank],
        transactions: [],
        items: [],
        budgets: budgets,
        plannedPurchases: [],
        budgetSettings: settings,
      );
      return (current: current, next: next);
    }

    Iterable<String> included(List<BudgetRemainingLine> lines) =>
        lines.where((l) => l.isIncluded).map((l) => l.budget.id);

    final october = run(DateTime(2026, 10, 1));
    expect(included(october.current.budgetLines), ['travel']);
    expect(included(october.next.budgetLines), ['food']);

    // After the clear day the November selection becomes the current window.
    final november = run(DateTime(2026, 10, 31));
    expect(included(november.current.budgetLines), ['food']);
    expect(included(november.next.budgetLines), ['food', 'travel']);
  });

  test('hidden budgets are left out unless included for a window', () {
    const travel = Budget(
      id: 'travel',
      name: 'Travel',
      amount: 4000,
      categoryIds: ['travel'],
      icon: Icons.flight,
      color: Colors.blue,
      isHidden: true,
    );
    final included = BudgetForecastSetting(
      id: 's1',
      budgetId: 'travel',
      periodEnd: DateTime(2026, 10, 30),
    ).withIncluded(true, isHidden: true);
    CashFlowForecast run(List<BudgetForecastSetting> settings) =>
        CashFlowForecastService.calculate(
          today: DateTime(2026, 10, 1),
          anchorDay: 30,
          monthlyCycleStartDay: 21,
          accounts: [_bank],
          balanceInThb: (_) => 20000,
          transactions: [],
          items: [],
          budgets: [travel],
          budgetSettings: settings,
        )!;

    expect(run([]).budgetTotal, 0);
    expect(run([]).budgetLines.single.isIncluded, isFalse);
    expect(run([included]).budgetTotal, 4000);
    // Turning it back off matches the default, so nothing needs storing.
    expect(included.withIncluded(false, isHidden: true).isDefault, isTrue);
  });

  test('what-if amount replaces the budget amount only in its window', () {
    const food = Budget(
      id: 'food',
      name: 'Food',
      amount: 10000,
      categoryIds: ['food'],
      icon: Icons.restaurant,
      color: Colors.blue,
    );
    const saving = Budget(
      id: 'saving',
      name: 'Saving',
      amount: 2000,
      categoryIds: [],
      type: BudgetType.savings,
      icon: Icons.savings,
      color: Colors.blue,
    );
    final nextEnd = DateTime(2026, 11, 30);
    final settings = [
      BudgetForecastSetting(
        id: 's1',
        budgetId: 'food',
        periodEnd: nextEnd,
        amount: 8000,
      ),
      BudgetForecastSetting(
        id: 's2',
        budgetId: 'saving',
        periodEnd: nextEnd,
        amount: 5000,
      ),
    ];
    final current = CashFlowForecastService.calculate(
      today: DateTime(2026, 10, 1),
      anchorDay: 30,
      monthlyCycleStartDay: 21,
      accounts: [_bank],
      balanceInThb: (_) => 20000,
      transactions: [],
      items: [],
      budgets: [food, saving],
      budgetSettings: settings,
    )!;
    final next = CashFlowForecastService.calculateNextPeriod(
      current: current,
      today: DateTime(2026, 10, 1),
      monthlyCycleStartDay: 21,
      anchorDay: 30,
      accounts: [_bank],
      transactions: [],
      items: [],
      budgets: [food, saving],
      plannedPurchases: [],
      budgetSettings: settings,
    );

    expect(current.budgetTotal, 10000);
    expect(current.savingsTotal, 2000);
    expect(next.budgetTotal, 8000);
    expect(next.savingsTotal, 5000);
    expect(next.budgetLines.single.hasWhatIf, isTrue);
    expect(current.budgetLines.single.hasWhatIf, isFalse);
    expect(
      BudgetForecastSetting.fromMap(settings.first.toMap()).periodEnd,
      nextEnd,
    );
  });

  test('reserves budget cycles once, including future cycles and savings', () {
    const expense = Budget(
      id: 'food',
      name: 'Food',
      amount: 10000,
      categoryIds: ['food'],
      icon: Icons.restaurant,
      color: Colors.blue,
    );
    const savings = Budget(
      id: 'saving',
      name: 'Saving',
      amount: 2000,
      categoryIds: [],
      type: BudgetType.savings,
      icon: Icons.savings,
      color: Colors.blue,
    );
    final budgets = [
      expense,
      savings,
      expense.copyWith(id: 'excluded'),
      expense.copyWith(id: 'hidden', isHidden: true),
      savings.copyWith(id: 'saving-excluded'),
    ];
    // ตัดงบ 2 รายการออกจากทุกงวดที่ใช้ในเทสต์นี้
    final excludedSettings = [
      for (var month = 2; month <= 12; month++)
        for (final id in ['excluded', 'saving-excluded'])
          BudgetForecastSetting(
            id: '$id-$month',
            budgetId: id,
            periodEnd: clampedDayOfMonth(2026, month, 30),
            isExcluded: true,
          ),
    ];
    final card = _card();
    final transactions = [
      AppTransaction(
        id: 'food-spend',
        type: TransactionType.expense,
        amount: 3000,
        accountId: card.id,
        categoryId: 'food',
        dateTime: DateTime(2026, 9, 25),
      ),
    ];
    final accounts = [_bank, card];
    for (final scenario in [
      (
        today: DateTime(2026, 9, 25),
        currentBudget: 0.0,
        nextBudget: 7000.0,
        currentSavings: 0.0,
        nextSavings: 2000.0,
      ),
      (
        today: DateTime(2026, 10, 1),
        currentBudget: 7000.0,
        nextBudget: 10000.0,
        currentSavings: 2000.0,
        nextSavings: 2000.0,
      ),
      (
        today: DateTime(2026, 10, 20),
        currentBudget: 7000.0,
        nextBudget: 10000.0,
        currentSavings: 2000.0,
        nextSavings: 2000.0,
      ),
      (
        today: DateTime(2026, 10, 21),
        currentBudget: 0.0,
        nextBudget: 10000.0,
        currentSavings: 0.0,
        nextSavings: 2000.0,
      ),
      (
        today: DateTime(2026, 10, 31),
        currentBudget: 10000.0,
        nextBudget: 10000.0,
        currentSavings: 2000.0,
        nextSavings: 2000.0,
      ),
    ]) {
      final current = CashFlowForecastService.calculate(
        today: scenario.today,
        anchorDay: 30,
        monthlyCycleStartDay: 21,
        accounts: accounts,
        balanceInThb: (_) => 20000,
        transactions: transactions,
        items: [],
        budgets: budgets,
        budgetSettings: excludedSettings,
      )!;
      final next = CashFlowForecastService.calculateNextPeriod(
        current: current,
        today: scenario.today,
        monthlyCycleStartDay: 21,
        anchorDay: 30,
        accounts: accounts,
        transactions: transactions,
        items: [],
        budgets: budgets,
        budgetSettings: excludedSettings,
        plannedPurchases: [],
      );
      expect(
        current.budgetTotal,
        scenario.currentBudget,
        reason: '${scenario.today} current',
      );
      expect(
        next.budgetTotal,
        scenario.nextBudget,
        reason: '${scenario.today} next',
      );
      expect(current.savingsTotal, scenario.currentSavings);
      expect(next.savingsTotal, scenario.nextSavings);
      expect(next.startingLeftover, current.projectedLeftover);
      expect(
        next.projectedLeftover,
        current.projectedLeftover -
            next.cardTotal -
            scenario.nextBudget -
            scenario.nextSavings,
      );
      if (scenario.today == DateTime(2026, 10, 1)) {
        expect(current.budgetLines.first.cycleStart, DateTime(2026, 9, 21));
        expect(current.budgetLines.first.cycleEnd, DateTime(2026, 10, 20));
        expect(next.budgetLines.first.cycleStart, DateTime(2026, 10, 21));
        expect(next.budgetLines.first.cycleEnd, DateTime(2026, 11, 20));
        expect(
          current.projectedLeftover,
          current.liquidTotal - 3000 - 7000 - 2000,
        );
      }
    }
    final overspent = CashFlowForecastService.calculate(
      today: DateTime(2026, 10, 1),
      anchorDay: 30,
      monthlyCycleStartDay: 21,
      accounts: accounts,
      balanceInThb: (_) => 20000,
      transactions: [transactions.first.copyWith(amount: 12000)],
      items: [],
      budgets: budgets,
      budgetSettings: excludedSettings,
    )!;
    expect(overspent.budgetTotal, 0);
    // A day-30 clear window may include two calendar-month ends after February.
    final shortMonth = CashFlowForecastService.calculate(
      today: DateTime(2026, 3, 1),
      anchorDay: 30,
      monthlyCycleStartDay: 1,
      accounts: accounts,
      balanceInThb: (_) => 20000,
      transactions: [],
      items: [],
      budgets: budgets,
      budgetSettings: excludedSettings,
    )!;
    final afterShortMonth = CashFlowForecastService.calculateNextPeriod(
      current: shortMonth,
      today: DateTime(2026, 3, 1),
      monthlyCycleStartDay: 1,
      anchorDay: 30,
      accounts: accounts,
      transactions: [],
      items: [],
      budgets: budgets,
      budgetSettings: excludedSettings,
      plannedPurchases: [],
    );
    expect(shortMonth.budgetTotal, 0);
    expect(afterShortMonth.budgetTotal, 20000);
    expect(afterShortMonth.savingsTotal, 4000);
  });

  group('forecast window', () {
    test('returns null when no clear day is set', () {
      final forecast = _forecast(today: DateTime(2026, 9, 25), anchorDay: null);

      expect(forecast, isNull);
    });

    test('runs from the day after the previous clear day to the next one', () {
      final forecast = _forecast(today: DateTime(2026, 9, 25))!;

      expect(forecast.windowStart, DateTime(2026, 8, 31));
      expect(forecast.windowEnd, DateTime(2026, 9, 30));
      expect(forecast.projectedLeftover, 20000 + 50000);
    });

    test('keeps the period on the clear day itself', () {
      final forecast = _forecast(today: DateTime(2026, 9, 30))!;

      expect(forecast.windowEnd, DateTime(2026, 9, 30));
    });

    test('moves to the next clear day once the clear day has passed', () {
      final forecast = _forecast(today: DateTime(2026, 10, 1))!;

      expect(forecast.windowStart, DateTime(2026, 10, 1));
      expect(forecast.windowEnd, DateTime(2026, 10, 30));
    });

    test('clamps a day-31 clear day to the last day of short months', () {
      final forecast = _forecast(today: DateTime(2026, 11, 5), anchorDay: 31)!;

      expect(forecast.windowStart, DateTime(2026, 11, 1));
      expect(forecast.windowEnd, DateTime(2026, 11, 30));
    });
  });

  group('liquid accounts', () {
    test('counts only cash and bank accounts that are not excluded', () {
      final emergency = Account(
        id: 'emergency',
        name: 'Emergency',
        type: AccountType.bankAccount,
        isExcludedFromCashForecast: true,
      );
      final wallet = Account(
        id: 'wallet',
        name: 'Wallet',
        type: AccountType.cash,
      );
      final fund = Account(
        id: 'fund',
        name: 'Fund',
        type: AccountType.investment,
      );

      final forecast = _forecast(
        today: DateTime(2026, 10, 1),
        accounts: [_bank, emergency, wallet, fund],
        balances: {
          'bank': 20000,
          'emergency': 100000,
          'wallet': 1000,
          'fund': 500000,
        },
      )!;

      expect(forecast.projectedLeftover, 20000 + 1000 + 50000);
      expect(forecast.liquidLines.map((l) => (l.account.id, l.isIncluded)), [
        ('bank', true),
        ('emergency', false),
        ('wallet', true),
      ]);
    });
  });

  group('credit cards', () {
    test(
      'counts the closed statement and ignores spending on a statement closing after the clear day',
      () {
        final forecast = _forecast(
          today: DateTime(2026, 9, 25),
          accounts: [_bank, _card()],
          transactions: [
            _spend('card', DateTime(2026, 9, 10), 12000),
            _spend('card', DateTime(2026, 9, 23), 3000),
          ],
        )!;

        final line = forecast.cardLines.single;
        expect(line.outstanding, 12000);
        expect(line.dueDate, DateTime(2026, 10, 5));
        expect(line.hasUnclosedStatement, isFalse);
        expect(forecast.projectedLeftover, 20000 + 50000 - 12000);
      },
    );

    test('counts only the remaining amount of a partly paid statement', () {
      final forecast = _forecast(
        today: DateTime(2026, 9, 25),
        accounts: [_bank, _card()],
        transactions: [
          _spend('card', DateTime(2026, 9, 10), 12000),
          _payCard('card', DateTime(2026, 9, 24), 5000),
        ],
      )!;

      expect(forecast.cardLines.single.outstanding, 7000);
    });

    test('a payment after the due date clears the statement', () {
      final forecast = _forecast(
        today: DateTime(2026, 10, 10),
        accounts: [_bank, _card()],
        transactions: [
          _spend('card', DateTime(2026, 9, 10), 12000),
          _payCard('card', DateTime(2026, 10, 8), 12000),
        ],
      )!;

      expect(forecast.cardLines, isEmpty);
    });

    test('an overdue outstanding statement still counts and is flagged', () {
      final forecast = _forecast(
        today: DateTime(2026, 10, 10),
        accounts: [_bank, _card()],
        transactions: [_spend('card', DateTime(2026, 9, 10), 12000)],
        items: [_salary.copyWith(isDone: true)],
      )!;

      final line = forecast.cardLines.single;
      expect(line.outstanding, 12000);
      expect(line.isOverdue, isTrue);
      expect(forecast.projectedLeftover, 20000 - 12000);
    });

    test('counts earlier unpaid statements carried into the latest one', () {
      final forecast = _forecast(
        today: DateTime(2026, 9, 25),
        accounts: [_bank, _card()],
        transactions: [_spend('card', DateTime(2026, 8, 10), 4000)],
      )!;

      expect(forecast.cardLines.single.outstanding, 4000);
    });

    test(
      'estimates a statement that closes before the clear day from spending so far',
      () {
        final forecast = _forecast(
          today: DateTime(2026, 10, 1),
          accounts: [_bank, _card()],
          transactions: [_spend('card', DateTime(2026, 9, 23), 3000)],
        )!;

        final line = forecast.cardLines.single;
        expect(line.outstanding, 3000);
        expect(line.hasUnclosedStatement, isTrue);
        expect(forecast.projectedLeftover, 20000 + 50000 - 3000);
      },
    );
  });
}
