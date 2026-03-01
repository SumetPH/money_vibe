import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/account.dart';
import '../../providers/account_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../theme/app_colors.dart';
import '../../main.dart';
import '../../widgets/app_drawer.dart';
import 'account_form_screen.dart';

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
      body: Consumer2<AccountProvider, TransactionProvider>(
        builder: (context, accountProvider, txProvider, _) {
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

          return CustomScrollView(
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
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(8),
                                    child: child,
                                  ),
                                );
                              },
                              child: child,
                            );
                          },
                          itemBuilder: (context, index) {
                            final account = groupedAccounts[groupName]![index];
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
                            );
                          },
                        ),
                      ],
                    ),
                  ),
              // Footer padding
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          );
        },
      ),
    );
  }

  void _openForm(BuildContext context, Account? account) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AccountFormScreen(account: account)),
    );
  }

  void _showAppMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('เพิ่มบัญชีใหม่'),
              onTap: () {
                Navigator.pop(context);
                _openForm(context, null);
              },
            ),
            ListTile(
              leading: const Icon(Icons.reorder),
              title: const Text('จัดเรียงลำดับ'),
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
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('จัดการการแสดงบัญชี'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
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
                    fontSize: 16,
                    fontWeight: isTopLevel
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                Text(
                  '${formatAmount(amount)} บาท',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.amountColor(amount),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.more_horiz,
              color: AppColors.textSecondary,
              size: 20,
            ),
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
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('รายละเอียดทรัพย์สิน'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
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
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            '${formatAmount(total)} บาท',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.amountColor(total),
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

  const _AccountItem({
    super.key,
    required this.account,
    required this.balance,
    this.isReorderMode = false,
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // Drag handle (only visible in reorder mode)
                if (isReorderMode) ...[
                  const Icon(
                    Icons.drag_indicator,
                    color: AppColors.divider,
                    size: 20,
                  ),
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
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${formatAmount(balance)} บาท',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.amountColor(balance),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.more_horiz,
                    color: AppColors.textSecondary,
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
        const Divider(height: 1, color: AppColors.divider),
      ],
    );
  }

  void _showAccountMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('แก้ไข'),
              onTap: () {
                Navigator.pop(context);
                onTap();
              },
            ),
          ],
        ),
      ),
    );
  }
}
