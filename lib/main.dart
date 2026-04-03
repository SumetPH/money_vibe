import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'providers/account_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/budget_provider.dart';
import 'providers/category_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/recurring_transaction_provider.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/auth/setup_screen.dart';
import 'screens/account/account_list_screen.dart';
import 'screens/budget/budget_list_screen.dart';
import 'screens/category/category_list_screen.dart';
import 'screens/recurring/recurring_list_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/statistics/statistics_screen.dart';
import 'screens/transaction/transaction_list_screen.dart';
import 'services/app_refresh_reminder_service.dart';
import 'services/database_manager.dart';
import 'services/debug_bootstrap_service.dart';
import 'services/recurring_notification_service.dart';
import 'services/splash_service.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'utils/web_safe_area_insets.dart';

void main() async {
  // Initialize and preserve native splash screen
  SplashService.initialize();

  debugPrint('Main: Starting app initialization...');

  try {
    await DebugBootstrapService.instance.primeLocalState();
  } catch (e, stackTrace) {
    debugPrint('Main: Debug bootstrap init error: $e');
    debugPrint('Main: Debug bootstrap stack trace: $stackTrace');
  }

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
    await RecurringNotificationService.instance.init();

    await Future.wait([
      _initProvider('Settings', settingsProvider.loadSettings),
    ]);

    // Initialize AuthProvider หลังจาก DatabaseManager (Supabase) พร้อมแล้ว
    if (dbManager.isConfigured) {
      await _initProvider('Auth', authProvider.init);
      await DebugBootstrapService.instance.signInIfNeeded(authProvider);
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

  WidgetsBinding.instance.addPostFrameCallback((_) {
    AppRefreshReminderService.instance.ensureScheduled();
  });

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

class MyApp extends StatefulWidget {
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
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final DatabaseManager _databaseManager;
  late final _AppRouterRefreshNotifier _routerRefreshNotifier;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _databaseManager = DatabaseManager();
    _routerRefreshNotifier = _AppRouterRefreshNotifier(
      listenables: [widget.authProvider, _databaseManager],
    );
    final initialLocation = _getDefaultTopLevelLocation();
    _router = GoRouter(
      initialLocation: initialLocation,
      overridePlatformDefaultLocation: _shouldOverridePlatformInitialLocation(),
      refreshListenable: _routerRefreshNotifier,
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const SizedBox.shrink(),
        ),
        GoRoute(
          path: '/setup',
          builder: (context, state) => const SetupScreen(),
        ),
        GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
        GoRoute(
          path: '/accounts',
          builder: (context, state) => const AccountListScreen(),
        ),
        GoRoute(
          path: '/transactions',
          builder: (context, state) => const TransactionListScreen(),
        ),
        GoRoute(
          path: '/budgets',
          builder: (context, state) => const BudgetListScreen(),
        ),
        GoRoute(
          path: '/recurring',
          builder: (context, state) => const RecurringListScreen(),
        ),
        GoRoute(
          path: '/categories',
          builder: (context, state) => const CategoryListScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/statistics',
          builder: (context, state) => const StatisticsScreen(),
        ),
      ],
      redirect: (context, state) {
        final location = state.matchedLocation;
        final defaultLocation = _getDefaultTopLevelLocation();
        final isConfigured = _databaseManager.isConfigured;
        final isLoggedIn = widget.authProvider.isLoggedIn;
        final isSetupRoute = location == '/setup';
        final isAuthRoute = location == '/auth';
        final isRootRoute = location == '/';

        if (!isConfigured) {
          return isSetupRoute ? null : '/setup';
        }

        if (!isLoggedIn) {
          return isAuthRoute ? null : '/auth';
        }

        if (isRootRoute || isSetupRoute || isAuthRoute) {
          return defaultLocation;
        }

        return null;
      },
    );
  }

  String _getDefaultTopLevelLocation() {
    if (!_databaseManager.isConfigured) {
      return '/setup';
    }

    if (!widget.authProvider.isLoggedIn) {
      return '/auth';
    }

    return '/accounts';
  }

  bool _shouldOverridePlatformInitialLocation() {
    if (!kIsWeb) {
      return false;
    }

    final path = Uri.base.path;
    return path.isEmpty || path == '/';
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.accountProvider),
        ChangeNotifierProvider.value(value: widget.authProvider),
        ChangeNotifierProvider.value(value: widget.budgetProvider),
        ChangeNotifierProvider.value(value: widget.categoryProvider),
        ChangeNotifierProvider.value(value: widget.transactionProvider),
        ChangeNotifierProvider.value(value: widget.settingsProvider),
        ChangeNotifierProvider.value(value: widget.recurringProvider),
        ChangeNotifierProvider.value(value: _databaseManager),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, _) {
          return MaterialApp.router(
            title: 'Money Vibe',
            theme: AppTheme.getTheme(settingsProvider.isDarkMode),
            debugShowCheckedModeBanner: false,
            routerConfig: _router,
            builder: kIsWeb
                ? (context, child) {
                    final mediaQuery = MediaQuery.of(context);
                    final extraBottomPadding = _getWebMobileBottomPadding(
                      mediaQuery,
                    );
                    final app = MediaQuery(
                      data: mediaQuery.copyWith(
                        padding: mediaQuery.padding.copyWith(
                          bottom: extraBottomPadding,
                        ),
                        viewPadding: mediaQuery.viewPadding.copyWith(
                          bottom: extraBottomPadding,
                        ),
                      ),
                      child: child!,
                    );

                    return ColoredBox(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      child: Center(
                        child: SizedBox(
                          width: 480,
                          child: ClipRect(child: app),
                        ),
                      ),
                    );
                  }
                : null,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _routerRefreshNotifier.dispose();
    _router.dispose();
    super.dispose();
  }
}

class _AppRouterRefreshNotifier extends ChangeNotifier {
  final List<Listenable> listenables;
  final List<VoidCallback> _listeners = [];

  _AppRouterRefreshNotifier({required this.listenables}) {
    for (final listenable in listenables) {
      void listener() => notifyListeners();
      listenable.addListener(listener);
      _listeners.add(listener);
    }
  }

  @override
  void dispose() {
    for (var index = 0; index < listenables.length; index++) {
      listenables[index].removeListener(_listeners[index]);
    }
    super.dispose();
  }
}

double _getWebMobileBottomPadding(MediaQueryData mediaQuery) {
  if (!isMobileWebDevice()) {
    return mediaQuery.padding.bottom;
  }

  return 24;
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
