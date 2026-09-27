import 'package:flutter_test/flutter_test.dart';
import 'package:money_vibe/models/account.dart';
import 'package:money_vibe/models/transaction.dart';
import 'package:money_vibe/services/credit_card_bill_service.dart';

Account _card({int? paymentDueDay}) => Account(
  id: 'card',
  name: 'Card',
  type: AccountType.creditCard,
  startDate: DateTime(2026, 7, 1),
  statementDay: 20,
  paymentDueDay: paymentDueDay,
);

AppTransaction _spend(DateTime date, double amount) => AppTransaction(
  id: 'spend-${date.toIso8601String()}',
  type: TransactionType.expense,
  amount: amount,
  accountId: 'card',
  dateTime: date,
);

AppTransaction _pay(DateTime date, double amount) => AppTransaction(
  id: 'pay-${date.toIso8601String()}',
  type: TransactionType.transfer,
  amount: amount,
  accountId: 'bank',
  toAccountId: 'card',
  dateTime: date,
);

CreditCardBill _billClosingOn(List<CreditCardBill> bills, DateTime date) =>
    bills.firstWhere((bill) => bill.statementDate == date);

void main() {
  test(
    'keeps due date fifteen days after statement when no due day is set',
    () {
      final bills = CreditCardBillService.calculateBills(
        account: _card(),
        transactions: const [],
        now: DateTime(2026, 9, 25),
      );

      final bill = _billClosingOn(bills, DateTime(2026, 9, 20));
      expect(bill.dueDate, DateTime(2026, 10, 5));
    },
  );

  test('uses the first matching due day after the statement date', () {
    final bills = CreditCardBillService.calculateBills(
      account: _card(paymentDueDay: 8),
      transactions: const [],
      now: DateTime(2026, 9, 25),
    );

    expect(
      _billClosingOn(bills, DateTime(2026, 9, 20)).dueDate,
      DateTime(2026, 10, 8),
    );
  });

  test(
    'uses the same month when the due day is later than the statement day',
    () {
      final bills = CreditCardBillService.calculateBills(
        account: _card(paymentDueDay: 28),
        transactions: const [],
        now: DateTime(2026, 9, 25),
      );

      expect(
        _billClosingOn(bills, DateTime(2026, 9, 20)).dueDate,
        DateTime(2026, 9, 28),
      );
    },
  );

  test('clamps a due day that does not exist in the due month', () {
    final bills = CreditCardBillService.calculateBills(
      account: _card(paymentDueDay: 31),
      transactions: const [],
      now: DateTime(2026, 12, 1),
    );

    expect(
      _billClosingOn(bills, DateTime(2026, 11, 20)).dueDate,
      DateTime(2026, 11, 30),
    );
  });

  test('counts a payment on the custom due date toward that statement', () {
    final bills = CreditCardBillService.calculateBills(
      account: _card(paymentDueDay: 8),
      transactions: [
        _spend(DateTime(2026, 9, 1), 1000),
        _pay(DateTime(2026, 10, 8), 1000),
      ],
      now: DateTime(2026, 10, 10),
    );

    final bill = _billClosingOn(bills, DateTime(2026, 9, 20));
    expect(bill.paidAmount, 1000);
    expect(bill.remainingAmount, 0);
  });

  test(
    'counts a payment after the custom due date toward the next statement',
    () {
      final bills = CreditCardBillService.calculateBills(
        account: _card(paymentDueDay: 8),
        transactions: [
          _spend(DateTime(2026, 9, 1), 1000),
          _pay(DateTime(2026, 10, 9), 400),
        ],
        now: DateTime(2026, 10, 10),
      );

      final closed = _billClosingOn(bills, DateTime(2026, 9, 20));
      final open = bills.firstWhere((bill) => bill.isOpen);
      expect(closed.remainingAmount, 1000);
      expect(open.paidAmount, 400);
      expect(open.paymentStartDate, DateTime(2026, 10, 9));
      expect(open.dueDate, DateTime(2026, 11, 8));
    },
  );
}
