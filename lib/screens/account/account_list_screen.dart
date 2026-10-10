import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/account.dart';
import '../../providers/account_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../main.dart';
import '../../widgets/app_reorder_mode.dart';
import '../../widgets/app_inset_card.dart';
import '../../widgets/app_modal_bottom_sheet.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_drawer_button.dart';
import 'account_form_screen.dart';
import 'portfolio_detail_screen.dart';
import 'credit_card_bill_screen.dart';
import '../transaction/transaction_list_screen.dart';
import '../transaction/transaction_form_screen.dart';
import '../../widgets/app_switch.dart';
import 'account_list_models.dart';
import 'account_total_row.dart';
import 'account_list_item.dart';
import 'account_summary_row.dart';

class AccountListScreen extends StatefulWidget {
  final bool showPrimaryNavigation;

  const AccountListScreen({super.key, this.showPrimaryNavigation = true});

  @override
  State<AccountListScreen> createState() => _AccountListScreenState();
}

class _AccountListScreenState extends State<AccountListScreen> {
  bool _isReorderMode = false;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<SettingsProvider>().isDarkMode;
    final filterIds = context.select<SettingsProvider, Set<String>?>(
      (settingsProvider) => settingsProvider.netWorthFilterIds,
    );

    final isLargeScreen = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      drawer: isLargeScreen || !widget.showPrimaryNavigation
          ? null
          : const AppDrawer(currentRoute: '/accounts'),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: isLargeScreen ? null : const AppDrawerButton(),
        leadingWidth: 64,
        toolbarHeight: 100,
        elevation: 0,
        scrolledUnderElevation: 0,
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
          if (_isReorderMode)
            AppReorderDoneButton(
              onPressed: () => setState(() => _isReorderMode = false),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Material(
                color: isDarkMode ? AppColors.darkSurface : AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.full),
                  side: BorderSide(
                    color: AppColors.borderFor(isDarkMode),
                    width: 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: IconButton(
                  icon: const Icon(Icons.more_horiz),
                  color: isDarkMode
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
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
          final totals = buildAccountTotals(
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
              if (isReorderMode)
                const SliverToBoxAdapter(
                  child: AppReorderBanner(
                    message:
                        'แตะค้างที่ไอคอนลากเพื่อจัดเรียงลำดับกลุ่มและบัญชี',
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                sliver: SliverToBoxAdapter(
                  child: AccountTotalRow(
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
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  24 + MediaQuery.paddingOf(context).bottom,
                ),
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
                          Theme(
                            data: Theme.of(context).copyWith(
                              splashFactory: NoSplash.splashFactory,
                              splashColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              hoverColor: Colors.transparent,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? AppColors.darkSurface
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(
                                  AppRadii.xLarge,
                                ),
                                border: Border.all(
                                  color: isDarkMode
                                      ? AppColors.darkDivider.withValues(
                                          alpha: 0.4,
                                        )
                                      : AppColors.divider.withValues(
                                          alpha: 0.4,
                                        ),
                                ),
                              ),
                              child: ClipRRect(
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
                                          accountProvider
                                              .reorderAccountsInGroup(
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
                                        totals.balancesByAccountId[account
                                            .id] ??
                                        0;
                                    return AccountListItem(
                                      key: ValueKey(account.id),
                                      account: account,
                                      balance: balance,
                                      isReorderMode: isReorderMode,
                                      reorderIndex: isReorderMode
                                          ? index
                                          : null,
                                      onTap: () => _openForm(context, account),
                                      onTapEdit: () =>
                                          _openEditForm(context, account),
                                      isDarkMode: isDarkMode,
                                      showDivider:
                                          index < entry.value.length - 1,
                                    );
                                  },
                                ),
                              ),
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
      bottomNavigationBar: null,
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
          final textColor = isDarkMode
              ? AppColors.darkTextPrimary
              : AppColors.textPrimary;
          final textSecondary = isDarkMode
              ? AppColors.darkTextSecondary
              : AppColors.textSecondary;
          final dividerColor = isDarkMode
              ? AppColors.darkDivider
              : AppColors.divider;
          final incomeColor = isDarkMode
              ? AppColors.darkIncome
              : AppColors.income;
          final yellowColor = isDarkMode
              ? AppColors.darkFabYellow
              : AppColors.fabYellow;

          return StatefulBuilder(
            builder: (context, setStateModal) {
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppModalBottomSheetHeader(title: 'ตัวเลือกบัญชี'),
                      const SizedBox(height: 8),
                      Material(
                        color: isDarkMode
                            ? AppColors.darkSurfaceVariant
                            : AppColors.background,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.xLarge),
                          side: BorderSide(
                            color: dividerColor.withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            ListTile(
                              leading: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: yellowColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.medium,
                                  ),
                                ),
                                child: Icon(
                                  Icons.add_rounded,
                                  color: yellowColor,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                'เพิ่มบัญชีใหม่',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                'สร้างบัญชีเงินสด เงินฝาก บัตร หรือพอร์ต',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                _openAddAccountForm(context);
                              },
                            ),
                            const AppCardDivider(),
                            ListTile(
                              leading: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: incomeColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.medium,
                                  ),
                                ),
                                child: Icon(
                                  Icons.reorder_rounded,
                                  color: incomeColor,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                'จัดเรียงลำดับ',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                'เปิดโหมดลากสลับตำแหน่งบัญชี',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: AppSwitch(
                                value: _isReorderMode,
                                onChanged: (value) {
                                  setState(() => _isReorderMode = value);
                                  Navigator.pop(context);
                                },
                              ),
                            ),
                            const AppCardDivider(),
                            ListTile(
                              leading: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: textColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.medium,
                                  ),
                                ),
                                child: Icon(
                                  Icons.visibility_outlined,
                                  color: textColor,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                'แสดงบัญชีที่ซ่อน',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                'แสดงบัญชีที่ถูกตั้งค่าซ่อนไว้',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: AppSwitch(
                                value: showHiddenAccounts,
                                onChanged: (_) {
                                  accountProvider.toggleShowHiddenAccounts();
                                  Navigator.pop(context);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
    final totals = buildAccountTotals(
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

        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppModalBottomSheetHeader(title: 'สรุปภาพรวมการเงิน'),
                  const SizedBox(height: 16),

                  AccountSummaryRow(
                    label: 'ยอดสุทธิ',
                    amount: netWorth,
                    isDarkMode: isDarkMode,
                    fontSize: 20,
                    isBold: true,
                  ),
                  const SizedBox(height: 16),
                  const AppCardDivider(),
                  const SizedBox(height: 16),

                  // Main Summary
                  AccountSummaryRow(
                    label: 'ทรัพย์สินรวม',
                    amount: totalAssets,
                    isDarkMode: isDarkMode,
                    fontSize: 16,
                  ),
                  const SizedBox(height: 12),
                  AccountSummaryRow(
                    label: 'หนี้สินรวม',
                    amount: totalLiabilities,
                    isDarkMode: isDarkMode,
                    fontSize: 16,
                  ),
                  const SizedBox(height: 16),
                  const AppCardDivider(),
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
