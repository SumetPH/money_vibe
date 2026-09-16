import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/account.dart';
import '../../models/transaction.dart';
import '../../providers/account_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../main.dart';
import '../../providers/sync_provider.dart';
import '../../widgets/account_icon_widget.dart';
import '../../widgets/app_bottom_navigation.dart';
import '../../widgets/app_modal_bottom_sheet.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/group_header.dart';
import 'account_form_screen.dart';
import 'portfolio_detail_screen.dart';
import 'credit_card_bill_screen.dart';
import '../transaction/transaction_list_screen.dart';
import '../transaction/transaction_form_screen.dart';

class AccountListScreen extends StatefulWidget {
  const AccountListScreen({super.key});

  @override
  State<AccountListScreen> createState() => _AccountListScreenState();
}

class _AccountListScreenState extends State<AccountListScreen> {
  bool _isReorderMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<SyncProvider>().checkAndSync();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<SettingsProvider>().isDarkMode;
    final filterIds = context.select<SettingsProvider, Set<String>?>(
      (settingsProvider) => settingsProvider.netWorthFilterIds,
    );

    final isLargeScreen = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      drawer: isLargeScreen ? null : const AppDrawer(currentRoute: '/accounts'),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 104,
        backgroundColor: isDarkMode
            ? AppColors.darkBackground
            : AppColors.background,
        foregroundColor: isDarkMode
            ? AppColors.darkTextPrimary
            : AppColors.textPrimary,
        centerTitle: false,
        titleSpacing: isLargeScreen ? 24 : 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ภาพรวมการเงิน',
              style: TextStyle(
                color: isDarkMode
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'บัญชี',
              style: TextStyle(
                color: isDarkMode
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
                fontSize: 30,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Material(
              color: isDarkMode ? AppColors.darkSurface : AppColors.surface,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: IconButton(
                icon: const Icon(Icons.more_horiz),
                onPressed: () => _showAppMenu(context),
              ),
            ),
          ),
        ],
      ),
      body: Consumer2<AccountProvider, TransactionProvider>(
        builder: (context, accountProvider, txProvider, _) {
          final transactions = txProvider.transactions;
          final allAccounts = accountProvider.accounts;
          final accounts = accountProvider.visibleAccounts;
          final isReorderMode = _isReorderMode;
          final totals = _buildAccountTotals(
            accountProvider: accountProvider,
            allAccounts: allAccounts,
            visibleAccounts: accounts,
            transactions: transactions,
            filterIds: filterIds,
          );

          // Group accounts by display group
          final Map<String, List<Account>> groupedAccounts = {};
          for (final account in accounts) {
            final group = accountTypeDisplayGroup(account.type);
            groupedAccounts.putIfAbsent(group, () => []).add(account);
          }
          final orderedGroups = groupedAccounts.entries.toList();

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverToBoxAdapter(
                  child: _TotalRow(
                    label: 'ยอดเงินสุทธิ',
                    amount: totals.netWorth,
                    isDarkMode: isDarkMode,
                    accounts: allAccounts,
                    filterIds: filterIds,
                    isReorderMode: isReorderMode,
                    onAddTransaction: () => _openAddTransactionForm(context),
                    onAddAccount: () => _openAddAccountForm(context),
                    onShowSummary: () => _showSummaryModal(context),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'บัญชีของฉัน',
                          style: TextStyle(
                            color: isDarkMode
                                ? AppColors.darkTextPrimary
                                : AppColors.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverReorderableList(
                  itemCount: orderedGroups.length,
                  onReorderItem: isReorderMode
                      ? accountProvider.reorderAccountGroups
                      : (_, _) {},
                  proxyDecorator: (child, index, animation) =>
                      Material(color: Colors.transparent, child: child),
                  itemBuilder: (context, groupIndex) {
                    final entry = orderedGroups[groupIndex];
                    final groupTotal = totals.groupTotals[entry.key] ?? 0;
                    return Padding(
                      key: ValueKey('account_group_${entry.key}'),
                      padding: const EdgeInsets.only(bottom: 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    entry.key,
                                    style: TextStyle(
                                      color: isDarkMode
                                          ? AppColors.darkTextSecondary
                                          : AppColors.textSecondary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${formatAmount(groupTotal)} บาท',
                                  style: TextStyle(
                                    color: isDarkMode
                                        ? AppColors.darkTextSecondary
                                        : AppColors.textSecondary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (isReorderMode)
                                  ReorderableDragStartListener(
                                    index: groupIndex,
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: Icon(
                                        Icons.drag_indicator,
                                        color: isDarkMode
                                            ? AppColors.darkDivider
                                            : AppColors.divider,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppRadii.xLarge,
                            ),
                            child: ReorderableListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              buildDefaultDragHandles: false,
                              itemCount: entry.value.length,
                              onReorderItem: isReorderMode
                                  ? (oldIndex, newIndex) {
                                      accountProvider.reorderAccountsInGroup(
                                        entry.key,
                                        oldIndex,
                                        newIndex,
                                      );
                                    }
                                  : (_, _) {},
                              proxyDecorator: (child, index, animation) =>
                                  Material(
                                    elevation: 6,
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.xLarge,
                                    ),
                                    child: child,
                                  ),
                              itemBuilder: (context, index) {
                                final account = entry.value[index];
                                final balance =
                                    totals.balancesByAccountId[account.id] ?? 0;
                                return _AccountItem(
                                  key: ValueKey(account.id),
                                  account: account,
                                  balance: balance,
                                  isReorderMode: isReorderMode,
                                  reorderIndex: isReorderMode ? index : null,
                                  onTap: () => _openForm(context, account),
                                  onTapEdit: () =>
                                      _openEditForm(context, account),
                                  isDarkMode: isDarkMode,
                                  showDivider: index < entry.value.length - 1,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: isLargeScreen
          ? null
          : Builder(
              builder: (context) => AppBottomNavigation(
                currentRoute: '/accounts',
                onAdd: () => _openAddTransactionForm(context),
                onOpenDrawer: () => Scaffold.of(context).openDrawer(),
              ),
            ),
    );
  }

  void _openForm(BuildContext context, Account? account) {
    if (account != null && account.isPortfolio) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PortfolioDetailScreen(account: account),
        ),
      );
    } else if (account != null && account.type == AccountType.creditCard) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreditCardBillScreen(account: account),
        ),
      );
    } else if (account != null) {
      // cash, bankAccount, debt → ไปดู transaction ของ account นี้
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TransactionListScreen(accountId: account.id),
        ),
      );
    }
  }

  void _openEditForm(BuildContext context, Account account) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AccountFormScreen(account: account)),
    );
  }

  void _openAddTransactionForm(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TransactionFormScreen()),
    );
  }

  void _openAddAccountForm(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AccountFormScreen(account: null)),
    );
  }

  void _showAppMenu(BuildContext context) {
    showAppModalBottomSheet(
      context: context,
      builder: (_) => Consumer2<AccountProvider, SettingsProvider>(
        builder: (context, accountProvider, settingsProvider, _) {
          final isDarkMode = settingsProvider.isDarkMode;
          final showHiddenAccounts = accountProvider.showHiddenAccounts;
          final bgColor = isDarkMode
              ? AppColors.darkSurface
              : AppColors.surface;
          final textColor = isDarkMode
              ? AppColors.darkTextPrimary
              : AppColors.textPrimary;
          final dividerColor = isDarkMode
              ? AppColors.darkDivider
              : AppColors.divider;

          return StatefulBuilder(
            builder: (context, setStateModal) {
              return SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      tileColor: bgColor,
                      leading: const Icon(Icons.add_circle_outline),
                      title: Text(
                        'เพิ่มบัญชีใหม่',
                        style: TextStyle(color: textColor),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _openAddAccountForm(context);
                      },
                    ),
                    Divider(height: 1, color: dividerColor),
                    ListTile(
                      tileColor: bgColor,
                      leading: const Icon(Icons.reorder),
                      title: Text(
                        'จัดเรียงลำดับ',
                        style: TextStyle(color: textColor),
                      ),
                      trailing: Switch(
                        value: _isReorderMode,
                        onChanged: (value) {
                          setStateModal(() => _isReorderMode = value);
                          setState(() => _isReorderMode = value);
                        },
                      ),
                    ),
                    Divider(height: 1, color: dividerColor),
                    ListTile(
                      tileColor: bgColor,
                      leading: const Icon(Icons.visibility_outlined),
                      title: Text(
                        'แสดงบัญชีที่ซ่อน',
                        style: TextStyle(color: textColor),
                      ),
                      trailing: Switch(
                        value: showHiddenAccounts,
                        onChanged: (value) {
                          accountProvider.toggleShowHiddenAccounts();
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showSummaryModal(BuildContext context) {
    final accountProvider = context.read<AccountProvider>();
    final txProvider = context.read<TransactionProvider>();
    final isDarkMode = context.read<SettingsProvider>().isDarkMode;

    final transactions = txProvider.transactions;
    final totals = _buildAccountTotals(
      accountProvider: accountProvider,
      allAccounts: accountProvider.accounts,
      visibleAccounts: accountProvider.visibleAccounts,
      transactions: transactions,
      filterIds: context.read<SettingsProvider>().netWorthFilterIds,
    );
    final groupTotals = totals.groupTotals;

    final totalAssets = accountGroupsForSummary
        .where((group) => group.isAsset)
        .fold(0.0, (sum, group) => sum + (groupTotals[group.label] ?? 0));
    final totalLiabilities = accountGroupsForSummary
        .where((group) => !group.isAsset)
        .fold(0.0, (sum, group) => sum + (groupTotals[group.label] ?? 0));
    final netWorth = totalAssets + totalLiabilities;

    showAppModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final textPrimary = isDarkMode
            ? AppColors.darkTextPrimary
            : AppColors.textPrimary;
        final textSecondary = isDarkMode
            ? AppColors.darkTextSecondary
            : AppColors.textSecondary;
        final dividerColor = isDarkMode
            ? AppColors.darkDivider
            : AppColors.divider;

        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppModalBottomSheetHeader(title: 'สรุปภาพรวมการเงิน'),
                  const SizedBox(height: 16),

                  _SummaryRow(
                    label: 'ยอดสุทธิ',
                    amount: netWorth,
                    isDarkMode: isDarkMode,
                    fontSize: 20,
                    isBold: true,
                  ),
                  const SizedBox(height: 16),
                  Divider(color: dividerColor),
                  const SizedBox(height: 16),

                  // Main Summary
                  _SummaryRow(
                    label: 'ทรัพย์สินรวม',
                    amount: totalAssets,
                    isDarkMode: isDarkMode,
                    fontSize: 16,
                  ),
                  const SizedBox(height: 12),
                  _SummaryRow(
                    label: 'หนี้สินรวม',
                    amount: totalLiabilities,
                    isDarkMode: isDarkMode,
                    fontSize: 16,
                  ),
                  const SizedBox(height: 16),
                  Divider(color: dividerColor),
                  const SizedBox(height: 16),

                  // Breakdown Header
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'รายละเอียดแยกตามกลุ่ม',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Group breakdown
                  ...accountGroupsForSummary.map((group) {
                    final total = groupTotals[group.label] ?? 0;
                    if (total == 0) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            group.label,
                            style: TextStyle(color: textPrimary, fontSize: 15),
                          ),
                          Text(
                            '${formatAmount(total)} บาท',
                            style: TextStyle(
                              color: AppColors.getAmountColor(
                                total,
                                isDarkMode,
                              ),
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

_AccountTotals _buildAccountTotals({
  required AccountProvider accountProvider,
  required List<Account> allAccounts,
  required List<Account> visibleAccounts,
  required List<AppTransaction> transactions,
  Set<String>? filterIds,
}) {
  final accountsById = {for (final account in allAccounts) account.id: account};
  final balancesByAccountId = <String, double>{};

  for (final account in allAccounts) {
    balancesByAccountId[account.id] = account.isPortfolio
        ? accountProvider.getBalance(account.id, const [])
        : account.initialBalance;
  }

  for (final tx in transactions) {
    final fromAccount = accountsById[tx.accountId];
    if (fromAccount != null && !fromAccount.isPortfolio) {
      final current = balancesByAccountId[tx.accountId] ?? 0;
      final delta =
          tx.type == TransactionType.income ||
              tx.type == TransactionType.increaseBalance
          ? tx.amount
          : -tx.amount;
      balancesByAccountId[tx.accountId] = current + delta;
    }

    final toAccountId = tx.toAccountId;
    if (toAccountId != null && tx.type.usesDestinationAccount) {
      final toAccount = accountsById[toAccountId];
      if (toAccount != null && !toAccount.isPortfolio) {
        balancesByAccountId[toAccountId] =
            (balancesByAccountId[toAccountId] ?? 0) +
            (tx.toAmount ?? tx.amount);
      }
    }
  }

  double toThb(Account account) {
    final balance = balancesByAccountId[account.id] ?? 0;
    return account.currency == 'USD' ? balance * account.exchangeRate : balance;
  }

  final groupTotals = <String, double>{};
  for (final account in visibleAccounts) {
    final group = accountTypeDisplayGroup(account.type);
    groupTotals[group] = (groupTotals[group] ?? 0) + toThb(account);
  }

  var netWorth = 0.0;
  for (final account in allAccounts) {
    if (account.excludeFromNetWorth) continue;
    if (filterIds != null && !filterIds.contains(account.id)) continue;
    netWorth += toThb(account);
  }

  return _AccountTotals(
    balancesByAccountId: balancesByAccountId,
    groupTotals: groupTotals,
    netWorth: netWorth,
  );
}

class _AccountTotals {
  final Map<String, double> balancesByAccountId;
  final Map<String, double> groupTotals;
  final double netWorth;

  const _AccountTotals({
    required this.balancesByAccountId,
    required this.groupTotals,
    required this.netWorth,
  });
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool isDarkMode;
  final List<Account> accounts;
  final Set<String>? filterIds;
  final bool isReorderMode;
  final VoidCallback onAddTransaction;
  final VoidCallback onAddAccount;
  final VoidCallback onShowSummary;

  const _TotalRow({
    required this.label,
    required this.amount,
    required this.isDarkMode,
    required this.accounts,
    required this.filterIds,
    required this.isReorderMode,
    required this.onAddTransaction,
    required this.onAddAccount,
    required this.onShowSummary,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final textPrimaryColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final textSecondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final actionColor = isDarkMode
        ? AppColors.darkSurfaceVariant
        : AppColors.sectionHeader;

    return Material(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(AppRadii.sheet),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.sheet),
        onTap: isReorderMode ? null : () => _showTotalMenu(context),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textSecondaryColor,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.visibility_outlined,
                    size: 18,
                    color: textSecondaryColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    filterIds == null
                        ? 'ทุกบัญชี'
                        : '${filterIds!.length} บัญชี',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textSecondaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '฿ ${formatAmount(amount)}',
                  style: TextStyle(
                    fontSize: 36,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    color: textPrimaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildAction(
                      icon: Icons.add,
                      label: 'เพิ่มรายการ',
                      color: actionColor,
                      onTap: onAddTransaction,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildAction(
                      icon: Icons.insert_chart_outlined,
                      label: 'สรุปผล',
                      color: actionColor,
                      onTap: onShowSummary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final accent = isDarkMode ? AppColors.darkFabYellow : AppColors.fabYellow;
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;

    return Material(
      color: color,
      borderRadius: BorderRadius.circular(AppRadii.large),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTotalMenu(BuildContext context) {
    showAppModalBottomSheet(
      context: context,
      builder: (_) => Consumer<SettingsProvider>(
        builder: (context, settingsProvider, _) {
          final isDarkMode = settingsProvider.isDarkMode;
          final bgColor = isDarkMode
              ? AppColors.darkSurface
              : AppColors.surface;
          final textColor = isDarkMode
              ? AppColors.darkTextPrimary
              : AppColors.textPrimary;
          final accentColor = isDarkMode
              ? AppColors.darkFabYellow
              : AppColors.fabYellow;

          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  tileColor: bgColor,
                  leading: Icon(Icons.filter_list, color: textColor),
                  title: Text(
                    'เลือกบัญชีที่คำนวณ',
                    style: TextStyle(color: textColor),
                  ),
                  trailing: filterIds != null
                      ? Text(
                          '${filterIds!.length}/${accounts.length}',
                          style: TextStyle(
                            color: accentColor,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    _showNetWorthFilterSheet(context, settingsProvider);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showNetWorthFilterSheet(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    showAppModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _NetWorthFilterSheet(
        accounts: accounts,
        filterIds: filterIds,
        isDarkMode: isDarkMode,
        onSave: (selected) => settingsProvider.setNetWorthFilterIds(selected),
      ),
    );
  }
}

class _AccountItem extends StatelessWidget {
  final Account account;
  final double balance;
  final bool isReorderMode;
  final int? reorderIndex;
  final VoidCallback onTap;
  final VoidCallback onTapEdit;
  final bool isDarkMode;
  final bool showDivider;

  const _AccountItem({
    super.key,
    required this.account,
    required this.balance,
    this.isReorderMode = false,
    this.reorderIndex,
    required this.onTap,
    required this.onTapEdit,
    required this.isDarkMode,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final textPrimaryColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;

    return Column(
      children: [
        InkWell(
          onTap: isReorderMode ? null : onTap,
          onLongPress: isReorderMode ? null : () => _showAccountMenu(context),
          child: Container(
            color: surfaceColor,
            padding: const EdgeInsets.only(
              left: 14,
              right: 14,
              top: 12,
              bottom: 12,
            ),
            child: Row(
              children: [
                // Drag handle (only visible in reorder mode)
                if (reorderIndex != null) ...[
                  ReorderableDragStartListener(
                    index: reorderIndex!,
                    child: Icon(
                      Icons.drag_indicator,
                      color: dividerColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                // Account icon
                AccountIconWidget(
                  account: account,
                  size: 46,
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        account.type.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDarkMode
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '฿ ${formatAmount(account.currency == 'USD' ? balance * account.exchangeRate : balance)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.getAmountColor(balance, isDarkMode),
                      ),
                    ),
                    Text(
                      account.currency == 'USD'
                          ? '${formatAmount(balance)} USD'
                          : 'THB',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 72),
            child: Divider(height: 1, color: dividerColor),
          ),
      ],
    );
  }

  void _showAccountMenu(BuildContext context) {
    final bgColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;

    showAppModalBottomSheet(
      context: context,
      builder: (_) => Consumer<SettingsProvider>(
        builder: (context, settingsProvider, _) {
          final isDarkMode = settingsProvider.isDarkMode;
          final textColor = isDarkMode
              ? AppColors.darkTextPrimary
              : AppColors.textPrimary;

          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  tileColor: bgColor,
                  leading: Icon(Icons.edit_outlined, color: textColor),
                  title: Text('แก้ไข', style: TextStyle(color: textColor)),
                  onTap: () {
                    Navigator.pop(context);
                    onTapEdit();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NetWorthFilterSheet extends StatefulWidget {
  final List<Account> accounts;
  final Set<String>? filterIds;
  final bool isDarkMode;
  final Future<void> Function(Set<String>?) onSave;

  const _NetWorthFilterSheet({
    required this.accounts,
    required this.filterIds,
    required this.isDarkMode,
    required this.onSave,
  });

  @override
  State<_NetWorthFilterSheet> createState() => _NetWorthFilterSheetState();
}

class _NetWorthFilterSheetState extends State<_NetWorthFilterSheet> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    // null = all selected
    _selected = widget.filterIds != null
        ? Set.from(widget.filterIds!)
        : widget.accounts.map((a) => a.id).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = widget.isDarkMode;
    final bgColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final textPrimary = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final textSecondary = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;
    final accentColor = isDarkMode
        ? AppColors.darkFabYellow
        : AppColors.fabYellow;

    final allIds = widget.accounts.map((a) => a.id).toSet();
    final isAllSelected = _selected.containsAll(allIds);

    final Map<String, List<Account>> grouped = {};
    for (final a in widget.accounts) {
      grouped.putIfAbsent(accountTypeDisplayGroup(a.type), () => []).add(a);
    }

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        builder: (_, scrollController) => Column(
          children: [
            Container(
              color: bgColor,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'เลือก account ที่คำนวณยอดรวม',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () {
                            setState(() {
                              if (isAllSelected) {
                                _selected.clear();
                              } else {
                                _selected = Set.from(allIds);
                              }
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            child: Text(
                              isAllSelected ? 'ยกเลิกทั้งหมด' : 'เลือกทั้งหมด',
                              style: TextStyle(color: accentColor),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: dividerColor),
            Expanded(
              child: ListView(
                controller: scrollController,
                children: [
                  for (final group in accountGroupsForAccountList)
                    if (grouped.containsKey(group.label)) ...[
                      GroupHeader(title: group.label, isDarkMode: isDarkMode),
                      for (final account in grouped[group.label]!)
                        CheckboxListTile(
                          tileColor: bgColor,
                          value: _selected.contains(account.id),
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                _selected.add(account.id);
                              } else {
                                _selected.remove(account.id);
                              }
                            });
                          },
                          secondary: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: account.color.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: AccountIconWidget(
                              account: account,
                              size: 20,
                              isDarkMode: isDarkMode,
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                account.name,
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 15,
                                ),
                              ),
                              if (account.isHidden) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? Colors.white.withValues(alpha: 0.1)
                                        : Colors.black.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'ซ่อนอยู่',
                                    style: TextStyle(
                                      color: textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          activeColor: accentColor,
                          checkColor: Colors.black,
                          controlAffinity: ListTileControlAffinity.trailing,
                        ),
                      Divider(height: 1, color: dividerColor),
                    ],
                ],
              ),
            ),
            Container(
              color: bgColor,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    // If all selected → save null (no filter)
                    final saveValue =
                        _selected.containsAll(allIds) &&
                            allIds.containsAll(_selected)
                        ? null
                        : _selected.isEmpty
                        ? <String>{}
                        : _selected;
                    await widget.onSave(saveValue);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Text(
                    'บันทึก',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool isDarkMode;
  final double fontSize;
  final bool isBold;

  const _SummaryRow({
    required this.label,
    required this.amount,
    required this.isDarkMode,
    this.fontSize = 15,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: textPrimary,
          ),
        ),
        Text(
          '${formatAmount(amount)} บาท',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: AppColors.getAmountColor(amount, isDarkMode),
          ),
        ),
      ],
    );
  }
}
