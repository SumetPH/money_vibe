import 'package:flutter_test/flutter_test.dart';
import 'package:money_vibe/models/account.dart';
import 'package:money_vibe/models/fixed_cash_flow_item.dart';
import 'package:money_vibe/models/transaction.dart';
import 'package:money_vibe/services/cash_flow_forecast_service.dart';

const _cycleStartDay = 21;

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
  dayOfMonth: 30,
  direction: CashFlowDirection.incoming,
);

const _house = FixedCashFlowItem(
  id: 'house',
  name: 'ค่าบ้าน',
  amount: 15000,
  dayOfMonth: 25,
  direction: CashFlowDirection.outgoing,
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

FixedCashFlowPaidMark _mark(FixedCashFlowItem item, String month) =>
    FixedCashFlowPaidMark(
      id: '${item.id}-$month',
      itemId: item.id,
      month: month,
    );

CashFlowForecast? _forecast({
  required DateTime today,
  List<Account>? accounts,
  Map<String, double> balances = const {'bank': 20000},
  List<AppTransaction> transactions = const [],
  List<FixedCashFlowItem> items = const [_salary],
  List<FixedCashFlowPaidMark> marks = const [],
  int? anchorDay = 30,
}) => CashFlowForecastService.calculate(
  today: today,
  monthlyCycleStartDay: _cycleStartDay,
  anchorDay: anchorDay,
  accounts: accounts ?? [_bank],
  balanceInThb: (account) => balances[account.id] ?? 0,
  transactions: transactions,
  items: items,
  paidMarks: marks,
);

void main() {
  group('forecast window', () {
    test('returns null when no anchor day is set', () {
      final forecast = _forecast(today: DateTime(2026, 9, 25), anchorDay: null);

      expect(forecast, isNull);
    });

    test(
      'before payday includes the salary and covers until the day before the following payday',
      () {
        final forecast = _forecast(today: DateTime(2026, 9, 25))!;

        expect(forecast.cycleAnchorDate, DateTime(2026, 9, 30));
        expect(forecast.windowEnd, DateTime(2026, 10, 29));
        expect(forecast.projectedLeftover, 70000);
      },
    );

    test('after payday within the same cycle keeps the same window', () {
      final forecast = _forecast(
        today: DateTime(2026, 10, 1),
        balances: {'bank': 70000},
        marks: [_mark(_salary, '2026-09')],
      )!;

      expect(forecast.windowEnd, DateTime(2026, 10, 29));
      expect(forecast.projectedLeftover, 70000);
    });

    test('rolls over to the next pay period when a new cycle starts', () {
      final forecast = _forecast(
        today: DateTime(2026, 10, 21),
        marks: [_mark(_salary, '2026-09')],
      )!;

      expect(forecast.cycleAnchorDate, DateTime(2026, 10, 30));
      expect(forecast.windowEnd, DateTime(2026, 11, 29));
    });

    test('clamps a day-31 payday to the last day of short months', () {
      final forecast = _forecast(today: DateTime(2026, 10, 25), anchorDay: 31)!;

      expect(forecast.cycleAnchorDate, DateTime(2026, 10, 31));
      expect(forecast.windowEnd, DateTime(2026, 11, 29));
    });
  });

  group('fixed cash-flow items', () {
    test('counts an item twice when both occurrences fall in the window', () {
      final forecast = _forecast(
        today: DateTime(2026, 9, 22),
        items: [_salary, _house],
      )!;

      final houseLines = forecast.itemLines.where((l) => l.item.id == 'house');
      expect(houseLines.map((l) => l.date), [
        DateTime(2026, 9, 25),
        DateTime(2026, 10, 25),
      ]);
      expect(forecast.projectedLeftover, 20000 + 50000 - 30000);
    });

    test('a paid mark removes only that month occurrence', () {
      final forecast = _forecast(
        today: DateTime(2026, 9, 26),
        items: [_salary, _house],
        marks: [_mark(_house, '2026-09')],
      )!;

      expect(forecast.projectedLeftover, 20000 + 50000 - 15000);
      final septemberHouse = forecast.itemLines.firstWhere(
        (l) => l.item.id == 'house' && l.date.month == 9,
      );
      expect(septemberHouse.isMarked, isTrue);
      expect(septemberHouse.isCounted, isFalse);
    });

    test('an unmarked item dated before today still counts and is flagged', () {
      final forecast = _forecast(
        today: DateTime(2026, 9, 27),
        items: [_salary, _house],
      )!;

      final septemberHouse = forecast.itemLines.firstWhere(
        (l) => l.item.id == 'house' && l.date.month == 9,
      );
      expect(septemberHouse.isCounted, isTrue);
      expect(septemberHouse.isOverdueUnmarked, isTrue);
      expect(forecast.projectedLeftover, 20000 + 50000 - 30000);
    });
  });

  group('one-time items', () {
    final bonus = FixedCashFlowItem(
      id: 'bonus',
      name: 'โบนัส',
      amount: 30000,
      oneTimeDate: DateTime(2026, 10, 15),
      direction: CashFlowDirection.incoming,
    );

    test('counts a one-time item once when its date is in the window', () {
      final forecast = _forecast(
        today: DateTime(2026, 9, 25),
        items: [_salary, bonus],
      )!;

      final bonusLines = forecast.itemLines.where((l) => l.item.id == 'bonus');
      expect(bonusLines.map((l) => l.date), [DateTime(2026, 10, 15)]);
      expect(forecast.projectedLeftover, 20000 + 50000 + 30000);
    });

    test('ignores a one-time item dated after the window', () {
      final forecast = _forecast(
        today: DateTime(2026, 9, 25),
        items: [
          _salary,
          bonus.copyWith(oneTimeDate: DateTime(2026, 11, 2)),
        ],
      )!;

      expect(forecast.itemLines.where((l) => l.item.id == 'bonus'), isEmpty);
    });

    test('a paid mark on the one-time month removes it', () {
      final forecast = _forecast(
        today: DateTime(2026, 10, 16),
        items: [_salary, bonus],
        marks: [_mark(_salary, '2026-09'), _mark(bonus, '2026-10')],
      )!;

      expect(forecast.projectedLeftover, 20000);
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
        today: DateTime(2026, 9, 25),
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
      'subtracts the closed statement due in the window and ignores unbilled spending',
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

    test('a payment after the due date reduces the outstanding balance', () {
      final forecast = _forecast(
        today: DateTime(2026, 10, 10),
        accounts: [_bank, _card()],
        transactions: [
          _spend('card', DateTime(2026, 9, 10), 12000),
          _payCard('card', DateTime(2026, 10, 8), 12000),
        ],
        marks: [_mark(_salary, '2026-09')],
      )!;

      expect(forecast.cardLines, isEmpty);
    });

    test('an overdue outstanding statement still counts and is flagged', () {
      final forecast = _forecast(
        today: DateTime(2026, 10, 10),
        accounts: [_bank, _card()],
        transactions: [_spend('card', DateTime(2026, 9, 10), 12000)],
        marks: [_mark(_salary, '2026-09')],
      )!;

      final line = forecast.cardLines.single;
      expect(line.outstanding, 12000);
      expect(line.isOverdue, isTrue);
      expect(forecast.projectedLeftover, 20000 - 12000);
    });

    test(
      'counts an overdue carried-over balance when the latest statement is due after the window',
      () {
        const earlyPayday = FixedCashFlowItem(
          id: 'salary',
          name: 'เงินเดือน',
          amount: 50000,
          dayOfMonth: 1,
          direction: CashFlowDirection.incoming,
        );
        final forecast = CashFlowForecastService.calculate(
          today: DateTime(2026, 9, 25),
          monthlyCycleStartDay: 1,
          anchorDay: 1,
          accounts: [_bank, _card()],
          balanceInThb: (account) => account.id == 'bank' ? 20000 : 0,
          transactions: [_spend('card', DateTime(2026, 8, 10), 4000)],
          items: const [earlyPayday],
          paidMarks: [_mark(earlyPayday, '2026-09')],
        )!;

        expect(forecast.windowEnd, DateTime(2026, 9, 30));
        final line = forecast.cardLines.single;
        expect(line.outstanding, 4000);
        expect(line.isOverdue, isTrue);
        expect(line.dueDate, DateTime(2026, 9, 4));
      },
    );

    test('flags a statement due in the window that has not closed yet', () {
      final forecast = _forecast(
        today: DateTime(2026, 9, 25),
        accounts: [_bank, _card(paymentDueDay: 28)],
        transactions: [_spend('card', DateTime(2026, 9, 23), 3000)],
      )!;

      final line = forecast.cardLines.single;
      expect(line.outstanding, 0);
      expect(line.hasUnclosedStatement, isTrue);
      expect(forecast.projectedLeftover, 20000 + 50000);
    });
  });
}
