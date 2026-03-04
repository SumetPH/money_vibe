import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'providers/account_provider.dart';
import 'providers/budget_provider.dart';
import 'providers/category_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/recurring_transaction_provider.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';
import 'screens/account/account_list_screen.dart';
import 'screens/budget/budget_list_screen.dart';
import 'screens/category/category_list_screen.dart';
import 'screens/transaction/transaction_list_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/recurring/recurring_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('Main: Starting app initialization...');

  final accountProvider = AccountProvider();
  final budgetProvider = BudgetProvider();
  final categoryProvider = CategoryProvider();
  final transactionProvider = TransactionProvider();
  final settingsProvider = SettingsProvider();
  final recurringProvider = RecurringTransactionProvider();

  try {
    await Future.wait([
      _initProvider('Account', accountProvider.init),
      _initProvider('Budget', budgetProvider.init),
      _initProvider('Category', categoryProvider.init),
      _initProvider('Transaction', transactionProvider.init),
      _initProvider('Settings', settingsProvider.loadSettings),
      _initProvider('Recurring', recurringProvider.init),
    ]);
    debugPrint('Main: All providers initialized successfully');
  } catch (e, stackTrace) {
    debugPrint('Main: Fatal error during initialization: $e');
    debugPrint('Main: Stack trace: $stackTrace');
    // Continue running app anyway - providers may partially work
  }

  runApp(
    MyApp(
      accountProvider: accountProvider,
      budgetProvider: budgetProvider,
      categoryProvider: categoryProvider,
      transactionProvider: transactionProvider,
      settingsProvider: settingsProvider,
      recurringProvider: recurringProvider,
    ),
  );
}

Future<void> _initProvider(String name, Future<void> Function() initFn) async {
  try {
    debugPrint('Main: Initializing $name provider...');
    await initFn();
    debugPrint('Main: $name provider initialized');
  } catch (e, stackTrace) {
    debugPrint('Main: Error initializing $name provider: $e');
    debugPrint('Main: Stack trace for $name: $stackTrace');
    rethrow;
  }
}

class MyApp extends StatelessWidget {
  final AccountProvider accountProvider;
  final BudgetProvider budgetProvider;
  final CategoryProvider categoryProvider;
  final TransactionProvider transactionProvider;
  final SettingsProvider settingsProvider;
  final RecurringTransactionProvider recurringProvider;

  const MyApp({
    super.key,
    required this.accountProvider,
    required this.budgetProvider,
    required this.categoryProvider,
    required this.transactionProvider,
    required this.settingsProvider,
    required this.recurringProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: accountProvider),
        ChangeNotifierProvider.value(value: budgetProvider),
        ChangeNotifierProvider.value(value: categoryProvider),
        ChangeNotifierProvider.value(value: transactionProvider),
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider.value(value: recurringProvider),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, _) {
          return MaterialApp(
            title: 'Money Vibe',
            theme: AppTheme.getTheme(settingsProvider.isDarkMode),
            debugShowCheckedModeBanner: false,
            initialRoute: '/accounts',
            routes: {
              '/accounts': (_) => const AccountListScreen(),
              '/transactions': (_) => const TransactionListScreen(),
              '/budgets': (_) => const BudgetListScreen(),
              '/recurring': (_) => const RecurringListScreen(),
              '/categories': (_) => const CategoryListScreen(),
              '/settings': (_) => const SettingsScreen(),
            },
          );
        },
      ),
    );
  }
}

// Shared helper for amount formatting
String formatAmount(double amount, {bool showSign = false}) {
  // Handle -0.0 case explicitly
  if (amount == 0.0 || amount == -0.0) {
    return '0.00';
  }
  final formatter = NumberFormat('#,##0.00', 'en_US');
  final result = formatter.format(amount);
  if (result == '-0.00') return '0.00';
  if (showSign && amount > 0 && !result.startsWith('+')) return '+$result';
  return result;
}

String formatAmountShort(double amount) {
  // Handle -0.0 case explicitly
  if (amount == 0.0 || amount == -0.0) return '0.00';
  final abs = amount.abs();
  String formatted;
  if (abs >= 1000000) {
    formatted = '${NumberFormat('#,##0.00', 'en_US').format(abs / 1000000)}M';
  } else {
    formatted = NumberFormat('#,##0.00', 'en_US').format(abs);
  }
  if (amount < 0) return '-$formatted';
  return formatted;
}

Color amountColor(double amount) => AppColors.amountColor(amount);
