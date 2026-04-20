import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_vibe/models/account.dart';
import 'package:money_vibe/models/transaction.dart';
import 'package:money_vibe/services/credit_card_bill_service.dart';

void main() {
  group('CreditCardBillService', () {
    test('open cycle uses current day and excludes future transactions', () {
      final account = Account(
        id: 'card-1',
        name: 'Card',
        type: AccountType.creditCard,
        startDate: DateTime(2026, 3, 1),
        statementDay: 21,
        icon: Icons.credit_card,
      );

      final transactions = [
        AppTransaction(
          id: 'tx-closed',
          type: TransactionType.expense,
          amount: 500,
          accountId: account.id,
          dateTime: DateTime(2026, 4, 10),
        ),
        AppTransaction(
          id: 'tx-open-today',
          type: TransactionType.expense,
          amount: 300,
          accountId: account.id,
          dateTime: DateTime(2026, 4, 20, 9),
        ),
        AppTransaction(
          id: 'tx-future',
          type: TransactionType.expense,
          amount: 900,
          accountId: account.id,
          dateTime: DateTime(2026, 4, 21, 8),
        ),
      ];

      final bills = CreditCardBillService.calculateBills(
        account: account,
        transactions: transactions,
        now: DateTime(2026, 4, 20, 22, 30),
      );

      expect(bills, isNotEmpty);

      final currentBill = bills.first;
      expect(currentBill.isOpen, isTrue);
      expect(currentBill.statementDate, DateTime(2026, 4, 21));
      expect(currentBill.startDate, DateTime(2026, 3, 22));
      expect(currentBill.expensesAmount, 800);
      expect(currentBill.totalAmount, 800);
      expect(currentBill.expenses.map((tx) => tx.id), [
        'tx-closed',
        'tx-open-today',
      ]);
      expect(
        bills.where(
          (bill) => !bill.isOpen && bill.statementDate == DateTime(2026, 4, 21),
        ),
        isEmpty,
      );
    });

    test('returns open cycle even when no closed bill exists yet', () {
      final account = Account(
        id: 'card-2',
        name: 'Fresh Card',
        type: AccountType.creditCard,
        startDate: DateTime(2026, 4, 1),
        statementDay: 20,
        icon: Icons.credit_card,
      );

      final transactions = [
        AppTransaction(
          id: 'tx-current',
          type: TransactionType.expense,
          amount: 450,
          accountId: account.id,
          dateTime: DateTime(2026, 4, 15, 10),
        ),
      ];

      final bills = CreditCardBillService.calculateBills(
        account: account,
        transactions: transactions,
        now: DateTime(2026, 4, 15, 18),
      );

      expect(bills, hasLength(1));

      final currentBill = bills.first;
      expect(currentBill.isOpen, isTrue);
      expect(currentBill.startDate, DateTime(2026, 4, 1));
      expect(currentBill.statementDate, DateTime(2026, 4, 20));
      expect(currentBill.expensesAmount, 450);
      expect(currentBill.totalAmount, 450);
      expect(currentBill.expenses.map((tx) => tx.id), ['tx-current']);
    });

    test('keeps current cycle on statement day until the next day', () {
      final account = Account(
        id: 'card-3',
        name: 'Day 20 Card',
        type: AccountType.creditCard,
        startDate: DateTime(2026, 3, 1),
        statementDay: 20,
        icon: Icons.credit_card,
      );

      final transactions = [
        AppTransaction(
          id: 'tx-before-cutoff',
          type: TransactionType.expense,
          amount: 700,
          accountId: account.id,
          dateTime: DateTime(2026, 4, 19, 12),
        ),
        AppTransaction(
          id: 'tx-cutoff-day',
          type: TransactionType.expense,
          amount: 300,
          accountId: account.id,
          dateTime: DateTime(2026, 4, 20, 9),
        ),
      ];

      final bills = CreditCardBillService.calculateBills(
        account: account,
        transactions: transactions,
        now: DateTime(2026, 4, 20, 18),
      );

      expect(bills, isNotEmpty);

      final currentBill = bills.first;
      expect(currentBill.isOpen, isTrue);
      expect(currentBill.startDate, DateTime(2026, 3, 21));
      expect(currentBill.statementDate, DateTime(2026, 4, 20));
      expect(currentBill.expensesAmount, 1000);
      expect(currentBill.expenses.map((tx) => tx.id), [
        'tx-before-cutoff',
        'tx-cutoff-day',
      ]);
      expect(
        bills.where(
          (bill) => !bill.isOpen && bill.statementDate == DateTime(2026, 4, 20),
        ),
        isEmpty,
      );
    });
  });
}
