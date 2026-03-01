import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/account_provider.dart';
import 'providers/category_provider.dart';
import 'providers/transaction_provider.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';
import 'screens/account/account_list_screen.dart';
import 'screens/category/category_list_screen.dart';
import 'screens/transaction/transaction_list_screen.dart';
import 'screens/settings/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final accountProvider = AccountProvider();
  final categoryProvider = CategoryProvider();
  final transactionProvider = TransactionProvider();

  await Future.wait([
    accountProvider.init(),
    categoryProvider.init(),
    transactionProvider.init(),
  ]);

  runApp(
    MyApp(
      accountProvider: accountProvider,
      categoryProvider: categoryProvider,
      transactionProvider: transactionProvider,
    ),
  );
}

class MyApp extends StatelessWidget {
  final AccountProvider accountProvider;
  final CategoryProvider categoryProvider;
  final TransactionProvider transactionProvider;

  const MyApp({
    super.key,
    required this.accountProvider,
    required this.categoryProvider,
    required this.transactionProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: accountProvider),
        ChangeNotifierProvider.value(value: categoryProvider),
        ChangeNotifierProvider.value(value: transactionProvider),
      ],
      child: MaterialApp(
        title: 'Money',
        theme: AppTheme.theme,
        debugShowCheckedModeBanner: false,
        initialRoute: '/',
        routes: {
          '/': (_) => const TransactionListScreen(),
          '/accounts': (_) => const AccountListScreen(),
          '/categories': (_) => const CategoryListScreen(),
          '/settings': (_) => const SettingsScreen(),
        },
      ),
    );
  }
}

// Shared helper for amount formatting
String formatAmount(double amount, {bool showSign = false}) {
  final abs = amount.abs();
  final parts = abs.toStringAsFixed(2).split('.');
  final intPart = parts[0].replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
  final result = '$intPart.${parts[1]}';
  if (showSign && amount > 0) return '+$result';
  if (amount < 0) return '-$result';
  return result;
}

String formatAmountShort(double amount) {
  final abs = amount.abs();
  String formatted;
  if (abs >= 1000000) {
    formatted = '${(abs / 1000000).toStringAsFixed(2)}M';
  } else if (abs >= 1000) {
    final parts = abs.toStringAsFixed(2).split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    formatted = '$intPart.${parts[1]}';
  } else {
    formatted = abs.toStringAsFixed(2);
  }
  if (amount < 0) return '-$formatted';
  return formatted;
}

Color amountColor(double amount) => AppColors.amountColor(amount);
