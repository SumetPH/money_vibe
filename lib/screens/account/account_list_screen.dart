import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/account.dart';
import '../../providers/account_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../main.dart';
import '../../widgets/app_drawer.dart';
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
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<SettingsProvider>().isDarkMode;
    final filterIds = context.select<SettingsProvider, Set<String>?>(
      (settingsProvider) => settingsProvider.netWorthFilterIds,
    );

    return Scaffold(
      drawer: const AppDrawer(currentRoute: '/accounts'),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text('บัญชี'),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showAppMenu(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddTransactionForm(context),
        backgroundColor: isDarkMode
            ? AppColors.darkFabYellow
            : AppColors.fabYellow,
        foregroundColor: isDarkMode ? AppColors.darkSurface : Colors.white,
        child: const Icon(Icons.add),
      ),
      body: Consumer2<AccountProvider, TransactionProvider>(
        builder: (context, accountProvider, txProvider, _) {
          final transactions = txProvider.transactions;
          final accounts = accountProvider.visibleAccounts;
          final isReorderMode = _isReorderMode;
          final netWorth = accountProvider.getTotalNetWorth(
            transactions,
            filterIds: filterIds,
          );
          final groupTotals = accountProvider.getGroupTotals(transactions);

          // Group accounts by display group
          final Map<String, List<Account>> grouped = {};
          for (final account in accounts) {
            final group = accountTypeDisplayGroup(account.type);
            grouped.putIfAbsent(group, () => []).add(account);
          }

          // Display order
          const groupOrder = [
            'ลงทุน',
            'เงินสด / เงินฝาก',
            'บัตรเครดิต',
            'หนี้สิน',
          ];

          // Group accounts by display group
          final Map<String, List<Account>> groupedAccounts = {};
          for (final account in accounts) {
            final group = accountTypeDisplayGroup(account.type);
            groupedAccounts.putIfAbsent(group, () => []).add(account);
          }

          return SafeArea(
            child: CustomScrollView(
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TotalRow(
                        label: 'ยอดรวม',
                        amount: netWorth,
                        icon: Icons.account_balance_wallet,
                        iconColor: const Color(0xFFFFB300),
                        isTopLevel: true,
                        isDarkMode: isDarkMode,
                        accounts: accountProvider.accounts
                            .where((a) => !a.excludeFromNetWorth)
                            .toList(),
                        filterIds: filterIds,
                        isReorderMode: isReorderMode,
                      ),
                    ],
                  ),
                ),
                // Each group has its own ReorderableListView
                for (final groupName in groupOrder)
                  if (groupedAccounts.containsKey(groupName) &&
                      groupedAccounts[groupName]!.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionHeader(
                            title: groupName,
                            total: groupTotals[groupName] ?? 0,
                            isDarkMode: isDarkMode,
                          ),
                          ReorderableListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            buildDefaultDragHandles: isReorderMode,
                            itemCount: groupedAccounts[groupName]!.length,
                            onReorder: isReorderMode
                                ? (oldIndex, newIndex) {
                                    accountProvider.reorderAccountsInGroup(
                                      groupName,
                                      oldIndex,
                                      newIndex,
                                    );
                                  }
                                : (_, _) {},
                            proxyDecorator: (child, index, animation) {
                              return AnimatedBuilder(
                                animation: animation,
                                builder: (context, child) {
                                  final animValue = Curves.easeInOut.transform(
                                    animation.value,
                                  );
                                  final elevation = 1 + animValue * 8;
                                  final scale = 1 + animValue * 0.02;
                                  return Transform.scale(
                                    scale: scale,
                                    child: Material(
                                      elevation: elevation,
                                      color: isDarkMode
                                          ? AppColors.darkSurface
                                          : AppColors.surface,
                                      borderRadius: BorderRadius.circular(8),
                                      child: child,
                                    ),
                                  );
                                },
                                child: child,
                              );
                            },
                            itemBuilder: (context, index) {
                              final account =
                                  groupedAccounts[groupName]![index];
                              final balance = accountProvider.getBalance(
                                account.id,
                                transactions,
                              );

                              return _AccountItem(
                                key: ValueKey(account.id),
                                account: account,
                                balance: balance,
                                isReorderMode: isReorderMode,
                                onTap: () => _openForm(context, account),
                                onTapEdit: () =>
                                    _openEditForm(context, account),
                                isDarkMode: isDarkMode,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                // Footer padding
                const SliverToBoxAdapter(child: SizedBox(height: 112)),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openForm(BuildContext context, Account? account) {
    if (account != null && account.type == AccountType.portfolio) {
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

  void _showAppMenu(BuildContext context) {
    final isDarkMode = context.read<SettingsProvider>().isDarkMode;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? AppColors.darkSurface : Colors.white,
      builder: (_) => Consumer2<AccountProvider, SettingsProvider>(
        builder: (context, accountProvider, settingsProvider, _) {
          final isDarkMode = settingsProvider.isDarkMode;
          final showHiddenAccounts = accountProvider.showHiddenAccounts;
          final bgColor = isDarkMode ? AppColors.darkSurface : Colors.white;
          final handleColor = isDarkMode
              ? AppColors.darkDivider
              : Colors.grey.shade300;
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
                    const SizedBox(height: 12),
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: handleColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      tileColor: bgColor,
                      leading: const Icon(Icons.add_circle_outline),
                      title: Text(
                        'เพิ่มบัญชีใหม่',
                        style: TextStyle(color: textColor),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AccountFormScreen(account: null),
                          ),
                        );
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
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color iconColor;
  final bool isTopLevel;
  final bool isDarkMode;
  final List<Account> accounts;
  final Set<String>? filterIds;
  final bool isReorderMode;

  const _TotalRow({
    required this.label,
    required this.amount,
    required this.icon,
    required this.iconColor,
    this.isTopLevel = false,
    required this.isDarkMode,
    required this.accounts,
    required this.filterIds,
    required this.isReorderMode,
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

    return Container(
      color: surfaceColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isTopLevel
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: textPrimaryColor,
                  ),
                ),
                Text(
                  '${formatAmount(amount)} บาท',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getAmountColor(amount, isDarkMode),
                  ),
                ),
              ],
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              if (!isReorderMode)
                GestureDetector(
                  onTap: () => _showTotalMenu(context),
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 8,
                      right: 0,
                      top: 8,
                      bottom: 8,
                    ),
                    child: Icon(
                      Icons.more_vert,
                      color: textSecondaryColor,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showTotalMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? AppColors.darkSurface : Colors.white,
      builder: (_) => Consumer<SettingsProvider>(
        builder: (context, settingsProvider, _) {
          final isDarkMode = settingsProvider.isDarkMode;
          final bgColor = isDarkMode ? AppColors.darkSurface : Colors.white;
          final handleColor = isDarkMode
              ? AppColors.darkDivider
              : Colors.grey.shade300;
          final textColor = isDarkMode
              ? AppColors.darkTextPrimary
              : AppColors.textPrimary;

          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: handleColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
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
                            color: const Color(0xFFFFB300),
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
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? AppColors.darkSurface : Colors.white,
      isScrollControlled: true,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _NetWorthFilterSheet(
        accounts: accounts,
        filterIds: filterIds,
        isDarkMode: isDarkMode,
        onSave: (selected) => settingsProvider.setNetWorthFilterIds(selected),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final double total;
  final bool isDarkMode;

  const _SectionHeader({
    required this.title,
    required this.total,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDarkMode
        ? AppColors.darkBackground
        : AppColors.background;
    final textColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
          Text(
            '${formatAmount(total)} บาท',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.getAmountColor(total, isDarkMode),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountItem extends StatelessWidget {
  final Account account;
  final double balance;
  final bool isReorderMode;
  final VoidCallback onTap;
  final VoidCallback onTapEdit;
  final bool isDarkMode;

  const _AccountItem({
    super.key,
    required this.account,
    required this.balance,
    this.isReorderMode = false,
    required this.onTap,
    required this.onTapEdit,
    required this.isDarkMode,
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
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Container(
            color: surfaceColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // Drag handle (only visible in reorder mode)
                if (isReorderMode) ...[
                  Icon(Icons.drag_indicator, color: dividerColor, size: 20),
                  const SizedBox(width: 8),
                ],
                // Account icon
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: account.color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(account.icon, color: account.color, size: 20),
                ),
                const SizedBox(width: 12),
                // Name and balance
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
                      Text(
                        '${formatAmount(balance)} บาท',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.getAmountColor(balance, isDarkMode),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isReorderMode)
                  GestureDetector(
                    onTap: () => _showAccountMenu(context),
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 8,
                        right: 0,
                        top: 8,
                        bottom: 8,
                      ),
                      child: Icon(
                        Icons.more_vert,
                        color: textSecondaryColor,
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Divider(height: 1, color: dividerColor),
      ],
    );
  }

  void _showAccountMenu(BuildContext context) {
    final bgColor = isDarkMode ? AppColors.darkSurface : Colors.white;

    showModalBottomSheet(
      backgroundColor: bgColor,
      context: context,
      builder: (_) => Consumer<SettingsProvider>(
        builder: (context, settingsProvider, _) {
          final isDarkMode = settingsProvider.isDarkMode;
          final handleColor = isDarkMode
              ? AppColors.darkDivider
              : Colors.grey.shade300;
          final textColor = isDarkMode
              ? AppColors.darkTextPrimary
              : AppColors.textPrimary;

          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: handleColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
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
    final bgColor = isDarkMode ? AppColors.darkSurface : Colors.white;
    final handleColor = isDarkMode
        ? AppColors.darkDivider
        : Colors.grey.shade300;
    final textPrimary = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final textSecondary = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;

    final allIds = widget.accounts.map((a) => a.id).toSet();
    final isAllSelected = _selected.containsAll(allIds);

    // Group accounts
    const groupOrder = ['ลงทุน', 'เงินสด / เงินฝาก', 'บัตรเครดิต', 'หนี้สิน'];
    final Map<String, List<Account>> grouped = {};
    for (final a in widget.accounts) {
      grouped.putIfAbsent(accountTypeDisplayGroup(a.type), () => []).add(a);
    }

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, scrollController) => Column(
          children: [
            Container(
              color: bgColor,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: handleColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isAllSelected) {
                                _selected.clear();
                              } else {
                                _selected = Set.from(allIds);
                              }
                            });
                          },
                          child: Text(
                            isAllSelected ? 'ยกเลิกทั้งหมด' : 'เลือกทั้งหมด',
                            style: const TextStyle(color: Color(0xFFFFB300)),
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
                  for (final groupName in groupOrder)
                    if (grouped.containsKey(groupName)) ...[
                      Container(
                        color: isDarkMode
                            ? AppColors.darkBackground
                            : AppColors.background,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          groupName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textSecondary,
                          ),
                        ),
                      ),
                      for (final account in grouped[groupName]!)
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
                            child: Icon(
                              account.icon,
                              color: account.color,
                              size: 20,
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
                          activeColor: const Color(0xFFFFB300),
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
                    backgroundColor: const Color(0xFFFFB300),
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
                  child: const Text(
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
