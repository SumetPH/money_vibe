import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/sync_provider.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/app_drawer.dart';
import 'account/account_list_screen.dart';
import 'budget/budget_list_screen.dart';
import 'transaction/transaction_form_screen.dart';
import 'transaction/transaction_list_screen.dart';
import 'statistics/statistics_screen.dart';

class MainTabScreen extends StatefulWidget {
  final int initialTab;

  const MainTabScreen({super.key, this.initialTab = 0});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  late int _selectedTab;
  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab.clamp(0, 3);
    _tabs = const [
      AccountListScreen(showPrimaryNavigation: false),
      BudgetListScreen(showPrimaryNavigation: false),
      TransactionListScreen(showPrimaryNavigation: false),
      StatisticsScreen(showPrimaryNavigation: false),
    ];
  }

  void _selectTab(int index) {
    if (index == _selectedTab) return;
    setState(() => _selectedTab = index);
    final syncProvider = context.read<SyncProvider>();
    if (!syncProvider.hasBaseline) return;
    syncProvider.checkAndSync().catchError((error) {
      debugPrint('[MainTabScreen] Background sync failed: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.sizeOf(context).width >= 800;

    return Scaffold(
      drawer: isLargeScreen
          ? null
          : AppDrawer(
              currentRoute: _routeForTab(_selectedTab),
              onSelectTab: (route) => _selectTab(switch (route) {
                '/budgets' => 1,
                '/transactions' => 2,
                '/statistics' => 3,
                _ => 0,
              }),
            ),
      body: isLargeScreen
          ? _tabs[_selectedTab]
          : IndexedStack(index: _selectedTab, children: _tabs),
      bottomNavigationBar: isLargeScreen
          ? null
          : Builder(
              builder: (context) => AppBottomNavigation(
                selectedIndex: _selectedTab,
                onSelectTab: _selectTab,
                onAdd: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TransactionFormScreen(),
                  ),
                ),
              ),
            ),
    );
  }

  String _routeForTab(int tab) => switch (tab) {
    1 => '/budgets',
    2 => '/transactions',
    3 => '/statistics',
    _ => '/accounts',
  };
}
