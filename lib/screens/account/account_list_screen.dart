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

class AccountListScreen extends StatefulWidget {
  const AccountListScreen({super.key});

  @override
  State<AccountListScreen> createState() => _AccountListScreenState();
}

class _AccountListScreenState extends State<AccountListScreen> {
  bool _isReorderMode = false;

  @override
  Widget build(BuildContext context) {
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
            icon: const Icon(Icons.pie_chart_outline),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () => _showAppMenu(context),
          ),
        ],
      ),
      body: Consumer3<AccountProvider, TransactionProvider, SettingsProvider>(
        builder: (context, accountProvider, txProvider, settingsProvider, _) {
          final isDarkMode = settingsProvider.isDarkMode;
          final transactions = txProvider.transactions;
          final accounts = accountProvider.visibleAccounts;
          final isReorderMode = _isReorderMode;
          final netWorth = accountProvider.getTotalNetWorth(transactions);
          final groupTotals = accountProvider.getGroupTotals(transactions);

          // Group accounts by display group
          final Map<String, List<Account>> grouped = {};
          for (final account in accounts) {
            final group = accountTypeDisplayGroup(account.type);
            grouped.putIfAbsent(group, () => []).add(account);
          }

          // Display order
          const groupOrder = [
            'เงินสด / เงินฝาก',
            'บัตรเครดิต',
            'หนี้สิน',
            'ลงทุน',
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
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
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
    }
  }

  void _openEditForm(BuildContext context, Account account) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AccountFormScreen(account: account)),
    );
  }

  void _showAppMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
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
                    _openForm(context, null);
                  },
                ),
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
                      setState(() => _isReorderMode = value);
                      Navigator.pop(context);
                    },
                  ),
                  onTap: () {
                    setState(() => _isReorderMode = !_isReorderMode);
                    Navigator.pop(context);
                  },
                ),
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
                      Navigator.pop(context);
                    },
                  ),
                  onTap: () {
                    accountProvider.toggleShowHiddenAccounts();
                    Navigator.pop(context);
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

class _TotalRow extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color iconColor;
  final bool isTopLevel;
  final bool isDarkMode;

  const _TotalRow({
    required this.label,
    required this.amount,
    required this.icon,
    required this.iconColor,
    this.isTopLevel = false,
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
          IconButton(
            icon: Icon(Icons.more_horiz, color: textSecondaryColor, size: 20),
            onPressed: () => _showTotalMenu(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  void _showTotalMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
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
                const SizedBox(height: 8),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: handleColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  tileColor: bgColor,
                  leading: Icon(Icons.info_outline, color: textColor),
                  title: Text(
                    'รายละเอียดทรัพย์สิน',
                    style: TextStyle(color: textColor),
                  ),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        },
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
                IconButton(
                  icon: Icon(
                    Icons.more_horiz,
                    color: textSecondaryColor,
                    size: 20,
                  ),
                  onPressed: () => _showAccountMenu(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
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
