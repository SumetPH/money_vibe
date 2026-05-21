import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:money_vibe/models/account.dart';
import 'package:money_vibe/models/category.dart';
import 'package:money_vibe/models/transaction.dart';
import 'package:money_vibe/models/recurring_transaction.dart';
import 'package:money_vibe/models/stock_holding.dart';
import 'package:money_vibe/models/budget.dart';
import 'package:money_vibe/providers/account_provider.dart';
import 'package:money_vibe/providers/category_provider.dart';
import 'package:money_vibe/providers/transaction_provider.dart';
import 'package:money_vibe/providers/settings_provider.dart';
import 'package:money_vibe/providers/recurring_transaction_provider.dart';
import 'package:money_vibe/services/database_manager.dart';
import 'package:money_vibe/repositories/database_repository.dart';
import 'package:money_vibe/screens/transaction/transaction_form_screen.dart';
import 'package:money_vibe/widgets/calculator_keyboard.dart';

class FakeDatabaseRepository implements DatabaseRepository {
  final List<Account> accounts;
  final List<Category> categories;

  FakeDatabaseRepository({required this.accounts, required this.categories});

  @override
  String get name => 'FakeDatabaseRepository';

  @override
  bool get isAuthenticated => true;

  @override
  String? get currentUserId => 'test-user';

  @override
  Future<void> init() async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> clearAllData() async {}

  @override
  Future<bool> isConnected() async => true;

  @override
  Future<Map<String, dynamic>> healthCheck() async => {'status': 'ok'};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName.toString();
    if (name.contains('getAccounts')) {
      return Future.value(accounts);
    }
    if (name.contains('getCategories')) {
      return Future.value(categories);
    }
    if (name.contains('getTransactions')) {
      return Future.value(<AppTransaction>[]);
    }
    if (name.contains('getPortfolioHoldings')) {
      return Future.value(<StockHolding>[]);
    }
    if (name.contains('getRecurringTransactions')) {
      return Future.value(<RecurringTransaction>[]);
    }
    if (name.contains('getRecurringOccurrences')) {
      return Future.value(<RecurringOccurrence>[]);
    }
    if (name.contains('getSyncLogs')) {
      return Future.value(<String, DateTime>{});
    }
    if (name.contains('getBudgets')) {
      return Future.value(<Budget>[]);
    }
    return null;
  }
}

void main() {
  late SettingsProvider settingsProvider;
  late AccountProvider accountProvider;
  late CategoryProvider categoryProvider;
  late TransactionProvider transactionProvider;
  late RecurringTransactionProvider recurringProvider;

  setUp(() async {
    final fakeDb = FakeDatabaseRepository(
      accounts: [
        Account(
          id: 'acc-1',
          name: 'Cash Account',
          type: AccountType.cash,
          initialBalance: 1000,
          currency: 'THB',
          icon: Icons.money,
        ),
      ],
      categories: [
        Category(
          id: 'cat-1',
          name: 'Food',
          type: CategoryType.expense,
          icon: Icons.restaurant,
          color: Colors.red,
        ),
      ],
    );
    DatabaseManager().repository = fakeDb;

    settingsProvider = SettingsProvider();
    accountProvider = AccountProvider(settingsProvider: settingsProvider);
    categoryProvider = CategoryProvider();
    transactionProvider = TransactionProvider();
    recurringProvider = RecurringTransactionProvider();

    await accountProvider.init();
    await categoryProvider.init();
    await transactionProvider.init();
  });

  Widget createTestWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ChangeNotifierProvider<AccountProvider>.value(value: accountProvider),
        ChangeNotifierProvider<CategoryProvider>.value(value: categoryProvider),
        ChangeNotifierProvider<TransactionProvider>.value(
          value: transactionProvider,
        ),
        ChangeNotifierProvider<RecurringTransactionProvider>.value(
          value: recurringProvider,
        ),
      ],
      child: const MaterialApp(home: TransactionFormScreen()),
    );
  }

  testWidgets(
    'Tapping amount field opens calculator keyboard and handles inputs',
    (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find the amount text field. In the form, it has hint text 'จำนวน'
      final amountFieldFinder = find.widgetWithText(TextField, 'จำนวน');
      expect(amountFieldFinder, findsOneWidget);

      // Initially, the calculator keyboard is visible due to autofocus on amount field
      expect(find.byType(CalculatorKeyboard), findsOneWidget);

      // Close the keyboard by tapping 'ตกลง'
      await tester.tap(find.text('ตกลง'));
      await tester.pumpAndSettle();

      // Keyboard should now be closed
      expect(find.byType(CalculatorKeyboard), findsNothing);

      // Tap the field to focus it and reopen the keyboard
      await tester.tap(amountFieldFinder);
      await tester.pumpAndSettle();

      // The CalculatorKeyboard bottom sheet should be visible again
      expect(find.byType(CalculatorKeyboard), findsOneWidget);

      // Let's verify we can type numbers: '1', '5', '0', '0'
      await tester.tap(find.text('1'));
      await tester.tap(find.text('5'));
      await tester.tap(find.text('0'));
      await tester.tap(find.text('0'));
      await tester.pumpAndSettle();

      // Verify text formats with commas as '1,500' since there are no operators
      final textField = tester.widget<TextField>(amountFieldFinder);
      expect(textField.controller?.text, '1,500');

      // Tap operator '+'
      await tester.tap(find.text('+'));
      await tester.pumpAndSettle();
      expect(
        textField.controller?.text,
        '1500+',
      ); // commas stripped when operator is present

      // Tap '2', '0', '0'
      await tester.tap(find.text('2'));
      await tester.tap(find.text('0'));
      await tester.tap(find.text('0'));
      await tester.pumpAndSettle();
      expect(textField.controller?.text, '1500+200');

      // Tap '=' to evaluate
      await tester.tap(find.text('='));
      await tester.pumpAndSettle();
      expect(
        textField.controller?.text,
        '1,700',
      ); // result formatted back with commas

      // Tap 'ตกลง' to close
      await tester.tap(find.text('ตกลง'));
      await tester.pumpAndSettle();

      // Keyboard should close
      expect(find.byType(CalculatorKeyboard), findsNothing);
    },
  );
}
