import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/account.dart';
import '../../providers/account_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../theme/app_colors.dart';
import '../../main.dart';
import '../../widgets/app_drawer.dart';
import 'account_form_screen.dart';

class AccountListScreen extends StatelessWidget {
  const AccountListScreen({super.key});

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
            onPressed: () {},
          ),
        ],
      ),
      body: Consumer2<AccountProvider, TransactionProvider>(
        builder: (context, accountProvider, txProvider, _) {
          final transactions = txProvider.transactions;
          final accounts = accountProvider.visibleAccounts;
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

          return ListView(
            children: [
              // ยอดรวม header
              _TotalRow(
                label: 'ยอดรวม',
                amount: netWorth,
                icon: Icons.account_balance_wallet,
                iconColor: const Color(0xFFFFB300),
                isTopLevel: true,
              ),
              const SizedBox(height: 8),
              // Each group
              for (final groupName in groupOrder)
                if (grouped.containsKey(groupName)) ...[
                  _SectionHeader(
                    title: groupName,
                    total: groupTotals[groupName] ?? 0,
                  ),
                  ...grouped[groupName]!.map((account) {
                    final balance = accountProvider.getBalance(
                        account.id, transactions);
                    return _AccountItem(
                      account: account,
                      balance: balance,
                      onTap: () => _openForm(context, account),
                    );
                  }),
                  const SizedBox(height: 8),
                ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(context, null),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _openForm(BuildContext context, Account? account) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AccountFormScreen(account: account),
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

  const _TotalRow({
    required this.label,
    required this.amount,
    required this.icon,
    required this.iconColor,
    this.isTopLevel = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
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
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    fontWeight:
                        isTopLevel ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
                Text(
                  '${formatAmount(amount)} บาท',
                  style: TextStyle(
                    fontSize: isTopLevel ? 16 : 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.amountColor(amount),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz,
                color: AppColors.textSecondary, size: 20),
            onPressed: () {},
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final double total;

  const _SectionHeader({required this.title, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            '${formatAmount(total)} บาท',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.amountColor(total),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.more_horiz,
              color: AppColors.textSecondary, size: 18),
        ],
      ),
    );
  }
}

class _AccountItem extends StatelessWidget {
  final Account account;
  final double balance;
  final VoidCallback onTap;

  const _AccountItem({
    required this.account,
    required this.balance,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Container(
            color: AppColors.surface,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // Drag handle
                const Icon(Icons.drag_indicator,
                    color: AppColors.divider, size: 20),
                const SizedBox(width: 8),
                // Account icon
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: account.color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child:
                      Icon(account.icon, color: account.color, size: 20),
                ),
                const SizedBox(width: 12),
                // Name and balance
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${formatAmount(balance)} บาท',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.amountColor(balance),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: AppColors.textSecondary, size: 20),
              ],
            ),
          ),
        ),
        const Divider(indent: 72),
      ],
    );
  }
}
