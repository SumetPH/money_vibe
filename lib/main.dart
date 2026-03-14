import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'providers/account_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/budget_provider.dart';
import 'providers/category_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/recurring_transaction_provider.dart';

import 'screens/auth/auth_screen.dart';
import 'screens/auth/setup_screen.dart';
import 'services/database_manager.dart';
import 'services/splash_service.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';
import 'screens/account/account_list_screen.dart';
import 'screens/budget/budget_list_screen.dart';
import 'screens/category/category_list_screen.dart';
import 'screens/transaction/transaction_list_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/recurring/recurring_list_screen.dart';
import 'screens/statistics/statistics_screen.dart';

void main() async {
  // Initialize and preserve native splash screen
  SplashService.initialize();

  debugPrint('Main: Starting app initialization...');

  // Initialize DatabaseManager first (singleton)
  final dbManager = DatabaseManager();
  try {
    debugPrint('Main: Initializing DatabaseManager...');
    await dbManager.init();
    debugPrint('Main: DatabaseManager initialized');
  } catch (e, stackTrace) {
    debugPrint('Main: DatabaseManager init error: $e');
    debugPrint('Main: Stack trace: $stackTrace');
  }

  final accountProvider = AccountProvider();
  final budgetProvider = BudgetProvider();
  final categoryProvider = CategoryProvider();
  final transactionProvider = TransactionProvider();
  final settingsProvider = SettingsProvider();
  final recurringProvider = RecurringTransactionProvider();
  final authProvider = AuthProvider();

  try {
    await Future.wait([
      _initProvider('Settings', settingsProvider.loadSettings),
    ]);

    // Initialize AuthProvider หลังจาก DatabaseManager (Supabase) พร้อมแล้ว
    if (dbManager.isConfigured) {
      await _initProvider('Auth', authProvider.init);
    }

    // โหลดข้อมูลถ้า Login แล้ว
    if (authProvider.isLoggedIn) {
      await Future.wait([
        _initProvider('Account', accountProvider.init),
        _initProvider('Budget', budgetProvider.init),
        _initProvider('Category', categoryProvider.init),
        _initProvider('Transaction', transactionProvider.init),
        _initProvider('Recurring', recurringProvider.init),
      ]);
    }

    debugPrint('Main: All providers initialized successfully');
  } catch (e, stackTrace) {
    debugPrint('Main: Fatal error during initialization: $e');
    debugPrint('Main: Stack trace: $stackTrace');
    // Continue running app anyway - providers may partially work
  }

  runApp(
    MyApp(
      accountProvider: accountProvider,
      authProvider: authProvider,
      budgetProvider: budgetProvider,
      categoryProvider: categoryProvider,
      transactionProvider: transactionProvider,
      settingsProvider: settingsProvider,
      recurringProvider: recurringProvider,
    ),
  );

  // Remove native splash screen after app is built
  SplashService.remove();
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
  final AuthProvider authProvider;
  final BudgetProvider budgetProvider;
  final CategoryProvider categoryProvider;
  final TransactionProvider transactionProvider;
  final SettingsProvider settingsProvider;
  final RecurringTransactionProvider recurringProvider;

  const MyApp({
    super.key,
    required this.accountProvider,
    required this.authProvider,
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
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: budgetProvider),
        ChangeNotifierProvider.value(value: categoryProvider),
        ChangeNotifierProvider.value(value: transactionProvider),
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider.value(value: recurringProvider),
        // Add DatabaseManager as ChangeNotifierProvider for UI updates
        ChangeNotifierProvider(create: (_) => DatabaseManager()),
      ],
      child: Consumer2<SettingsProvider, AuthProvider>(
        builder: (context, settingsProvider, authProvider, _) {
          return MaterialApp(
            title: 'Money Vibe',
            theme: AppTheme.getTheme(settingsProvider.isDarkMode),
            debugShowCheckedModeBanner: false,
            builder: kIsWeb
                ? (context, child) => ColoredBox(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    child: Center(
                      child: SizedBox(
                        width: 480,
                        child: ClipRect(child: child!),
                      ),
                    ),
                  )
                : null,
            home: _buildHomeScreen(context, authProvider),
            routes: {
              '/accounts': (_) => const AccountListScreen(),
              '/transactions': (_) => const TransactionListScreen(),
              '/budgets': (_) => const BudgetListScreen(),
              '/recurring': (_) => const RecurringListScreen(),
              '/categories': (_) => const CategoryListScreen(),
              '/settings': (_) => const SettingsScreen(),
              '/statistics': (_) => const StatisticsScreen(),
            },
          );
        },
      ),
    );
  }

  Widget _buildHomeScreen(BuildContext context, AuthProvider authProvider) {
    final dbManager = DatabaseManager();

    // 1. ถ้ายังไม่ได้ตั้งค่า Supabase → ไปหน้าตั้งค่า
    if (!dbManager.isConfigured) {
      return const SetupScreen();
    }

    // 2. ถ้าตั้งค่าแล้วแต่ยังไม่ login → ไปหน้า Login
    if (!authProvider.isLoggedIn) {
      return const AuthScreen();
    }

    // 3. ถ้าตั้งค่าแล้วและ login แล้ว → ไปหน้าหลัก
    return const AccountListScreen();
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
