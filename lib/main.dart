import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:money_vibe/providers/llm_provider.dart';
import 'package:provider/provider.dart';

import 'providers/account_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/budget_provider.dart';
import 'providers/category_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/recurring_transaction_provider.dart';
import 'providers/sync_provider.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/auth/setup_screen.dart';
import 'screens/account/account_list_screen.dart';
import 'screens/budget/budget_list_screen.dart';
import 'screens/category/category_list_screen.dart';
import 'screens/recurring/recurring_list_screen.dart';
import 'screens/recurring/recurring_detail_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/statistics/statistics_screen.dart';
import 'screens/trade/trade_tracker_screen.dart';
import 'screens/transaction/transaction_list_screen.dart';
import 'services/database_manager.dart';
import 'services/debug_bootstrap_service.dart';
import 'services/recurring_notification_service.dart';
import 'services/splash_service.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'utils/web_safe_area_insets.dart';
import 'widgets/app_sidebar.dart';

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

  final settingsProvider = SettingsProvider();
  final accountProvider = AccountProvider(settingsProvider: settingsProvider);
  final budgetProvider = BudgetProvider();
  final categoryProvider = CategoryProvider();
  final transactionProvider = TransactionProvider();
  final recurringProvider = RecurringTransactionProvider();
  final authProvider = AuthProvider();
  final llmProvider = LlmProvider();
  final syncProvider = SyncProvider(
    repository: dbManager.repositoryOrNull,
    accountProvider: accountProvider,
    categoryProvider: categoryProvider,
    transactionProvider: transactionProvider,
    budgetProvider: budgetProvider,
    recurringProvider: recurringProvider,
  );

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
      llmProvider: llmProvider,
      syncProvider: syncProvider,
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

class MyApp extends StatefulWidget {
  final AccountProvider accountProvider;
  final AuthProvider authProvider;
  final BudgetProvider budgetProvider;
  final CategoryProvider categoryProvider;
  final TransactionProvider transactionProvider;
  final SettingsProvider settingsProvider;
  final RecurringTransactionProvider recurringProvider;
  final LlmProvider llmProvider;
  final SyncProvider syncProvider;

  const MyApp({
    super.key,
    required this.accountProvider,
    required this.authProvider,
    required this.budgetProvider,
    required this.categoryProvider,
    required this.transactionProvider,
    required this.settingsProvider,
    required this.recurringProvider,
    required this.llmProvider,
    required this.syncProvider,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final DatabaseManager _databaseManager;
  late final _AppRouterRefreshNotifier _routerRefreshNotifier;
  late final GoRouter _router;
  late final VoidCallback _routeInformationListener;
  String? _pendingRecurringDetailId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
          routes: [
            GoRoute(
              path: ':id',
              builder: (context, state) => _RecurringDetailRouteScreen(
                recurringId: state.pathParameters['id']!,
              ),
            ),
          ],
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
        GoRoute(
          path: '/trade-tracker',
          builder: (context, state) => const TradeTrackerScreen(),
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
    _routeInformationListener = () {
      if (mounted) {
        setState(() {});
      }
    };
    _router.routeInformationProvider.addListener(_routeInformationListener);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      RecurringNotificationService.instance.setOnNotificationTap(
        _handleRecurringNotificationTap,
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.authProvider.isLoggedIn) {
      widget.syncProvider.checkAndSync();
    }
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
        ChangeNotifierProvider.value(value: widget.llmProvider),
        ChangeNotifierProvider.value(value: widget.syncProvider),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, _) {
          return MaterialApp.router(
            title: 'Money Vibe',
            theme: AppTheme.getTheme(
              settingsProvider.isDarkMode,
              settingsProvider.themeColor,
            ),
            debugShowCheckedModeBanner: false,
            routerConfig: _router,
            builder: kIsWeb
                ? (context, child) {
                    final mediaQuery = MediaQuery.of(context);
                    final isLargeScreen = mediaQuery.size.width >= 800;

                    final authProvider = context.watch<AuthProvider>();
                    final isLoggedIn = authProvider.isLoggedIn;

                    final currentPath =
                        _router.routeInformationProvider.value.uri.path;
                    final isAuthOrSetup =
                        currentPath == '/auth' || currentPath == '/setup';

                    if (isLargeScreen && !isAuthOrSetup && isLoggedIn) {
                      final isDarkMode = settingsProvider.isDarkMode;
                      final bgColor = isDarkMode
                          ? AppColors.darkBackground
                          : AppColors.background;

                      return ColoredBox(
                        color: bgColor,
                        child: Row(
                          children: [
                            SizedBox(
                              width: 260,
                              child: AppSidebar(
                                currentRoute: currentPath,
                                onNavigate: (route) => _router.go(route),
                              ),
                            ),
                            Expanded(
                              child: Align(
                                alignment: Alignment.center,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 1100,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                    ),
                                    child: child!,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

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
                          width: 800,
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
    RecurringNotificationService.instance.clearOnNotificationTap();
    _router.routeInformationProvider.removeListener(_routeInformationListener);
    _routerRefreshNotifier.dispose();
    _router.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _handleRecurringNotificationTap(String payload) async {
    final recurringId = RecurringNotificationService.recurringIdFromPayload(
      payload,
    );
    if (recurringId == null || !mounted || !widget.authProvider.isLoggedIn) {
      return;
    }

    await _waitForRecurringProvider();
    if (!mounted) return;

    final recurring = widget.recurringProvider.allRecurring
        .where((item) => item.id == recurringId)
        .firstOrNull;
    final currentPath = _currentPath;
    final detailPath = '/recurring/$recurringId';

    if (recurring == null) {
      if (currentPath != '/recurring') {
        _router.go('/recurring');
      }
      return;
    }

    if (currentPath == detailPath) return;

    _pendingRecurringDetailId = recurringId;
    _router.go('/recurring');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pendingRecurringDetailId != recurringId) return;

      _pendingRecurringDetailId = null;
      if (_currentPath == detailPath) return;
      _router.push(detailPath);
    });
  }

  Future<void> _waitForRecurringProvider() async {
    while (mounted && widget.recurringProvider.isLoading) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  String get _currentPath => _router.routeInformationProvider.value.uri.path;
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

class _RecurringDetailRouteScreen extends StatefulWidget {
  final String recurringId;

  const _RecurringDetailRouteScreen({required this.recurringId});

  @override
  State<_RecurringDetailRouteScreen> createState() =>
      _RecurringDetailRouteScreenState();
}

class _RecurringDetailRouteScreenState
    extends State<_RecurringDetailRouteScreen> {
  bool _redirectScheduled = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<RecurringTransactionProvider>(
      builder: (context, provider, _) {
        final recurring = provider.allRecurring
            .where((item) => item.id == widget.recurringId)
            .firstOrNull;

        if (recurring != null) {
          _redirectScheduled = false;
          return RecurringDetailScreen(recurring: recurring);
        }

        if (!provider.isLoading && !_redirectScheduled) {
          _redirectScheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.go('/recurring');
            }
          });
        }

        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}

// Shared helper for amount formatting
final NumberFormat _amountFormatter = NumberFormat('#,##0.00', 'en_US');

String formatAmount(double amount, {bool showSign = false}) {
  // Handle -0.0 case explicitly
  if (amount == 0.0 || amount == -0.0) {
    return '0.00';
  }
  final result = _amountFormatter.format(amount);
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
    formatted = '${_amountFormatter.format(abs / 1000000)}M';
  } else {
    formatted = _amountFormatter.format(abs);
  }
  if (amount < 0) return '-$formatted';
  return formatted;
}

Color amountColor(double amount) => AppColors.amountColor(amount);
