import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'providers/account_provider.dart';
import 'providers/category_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/settings_provider.dart';
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
  final settingsProvider = SettingsProvider();

  await Future.wait([
    accountProvider.init(),
    categoryProvider.init(),
    transactionProvider.init(),
    settingsProvider.loadSettings(),
  ]);

  runApp(
    MyApp(
      accountProvider: accountProvider,
      categoryProvider: categoryProvider,
      transactionProvider: transactionProvider,
      settingsProvider: settingsProvider,
    ),
  );
}

class MyApp extends StatelessWidget {
  final AccountProvider accountProvider;
  final CategoryProvider categoryProvider;
  final TransactionProvider transactionProvider;
  final SettingsProvider settingsProvider;

  const MyApp({
    super.key,
    required this.accountProvider,
    required this.categoryProvider,
    required this.transactionProvider,
    required this.settingsProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: accountProvider),
        ChangeNotifierProvider.value(value: categoryProvider),
        ChangeNotifierProvider.value(value: transactionProvider),
        ChangeNotifierProvider.value(value: settingsProvider),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, _) {
          return MaterialApp(
            title: 'Money',
            theme: AppTheme.getTheme(settingsProvider.isDarkMode),
            debugShowCheckedModeBanner: false,
            initialRoute: '/',
            routes: {
              '/': (_) => const TransactionListScreen(),
              '/accounts': (_) => const AccountListScreen(),
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
