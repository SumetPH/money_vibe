import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/account.dart';
import '../providers/account_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transaction_provider.dart';
import '../theme/app_colors.dart';
import '../main.dart';
import 'account_icon_widget.dart';

/// วิดเจ็ตเลือกบัญชีแบบ Bottom Sheet (Deep Module)
/// จัดการดึงข้อมูล จัดกลุ่ม เรียงลำดับ และดึงยอดเงินด้วยตัวเอง
/// ลดภาระความซับซ้อนของหน้าจอหลัก (TransactionFormScreen) ให้สั้นและกระชับ
class AccountPickerBottomSheet extends StatelessWidget {
  final String title;
  final String? selectedAccountId;
  final List<Account>? accountsOverride; // ถ้าไม่ส่ง จะดึงจาก Provider เอง
  final bool isDebtOnly;

  const AccountPickerBottomSheet({
    super.key,
    required this.title,
    this.selectedAccountId,
    this.accountsOverride,
    this.isDebtOnly = false,
  });

  /// เมธอดสถิตสำหรับเรียกแสดง BottomSheet อย่างสะดวก (Leverage Interface)
  static Future<String?> show(
    BuildContext context, {
    required String title,
    String? selectedAccountId,
    List<Account>? accountsOverride,
    bool isDebtOnly = false,
  }) {
    final isDarkMode = context.read<SettingsProvider>().isDarkMode;
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDarkMode ? AppColors.darkSurface : Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AccountPickerBottomSheet(
        title: title,
        selectedAccountId: selectedAccountId,
        accountsOverride: accountsOverride,
        isDebtOnly: isDebtOnly,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accountProvider = context.read<AccountProvider>();
    final txProvider = context.read<TransactionProvider>();
    final transactions = txProvider.transactions;

    final isDarkMode = context.select<SettingsProvider, bool>(
      (s) => s.isDarkMode,
    );
    final colorScheme = Theme.of(context).colorScheme;

    // ดึงข้อมูลบัญชีตามโหมด
    final rawAccounts =
        accountsOverride ??
        (isDebtOnly ? accountProvider.debtAccounts : accountProvider.accounts);

    // จัดกลุ่มบัญชีตามประเภท
    final Map<String, List<Account>> groupedAccounts = {};
    for (final account in rawAccounts) {
      final group = accountTypeDisplayGroup(account.type);
      groupedAccounts.putIfAbsent(group, () => []).add(account);
    }

    // เรียงลำดับภายในกลุ่ม
    for (final group in groupedAccounts.keys) {
      groupedAccounts[group]!.sort(
        (a, b) => a.sortOrder.compareTo(b.sortOrder),
      );
    }

    // กำหนดลำดับของกลุ่ม
    final groupOrder = isDebtOnly
        ? const ['บัตรเครดิต', 'หนี้สิน']
        : const [
            'เงินสด / เงินฝาก',
            'บัตรเครดิต',
            'หนี้สิน',
            'ทรัพย์สิน',
            'ลงทุน',
          ];

    final orderedGroups = groupOrder
        .where(groupedAccounts.containsKey)
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDarkMode ? AppColors.darkDivider : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: isDarkMode
                  ? AppColors.darkTextPrimary
                  : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: orderedGroups.length,
              padding: EdgeInsets.zero,
              itemBuilder: (ctx, groupIndex) {
                final groupName = orderedGroups[groupIndex];
                final groupAccounts = groupedAccounts[groupName]!;
                final headerBgColor = isDarkMode
                    ? AppColors.darkBackground
                    : AppColors.background;
                final headerTextColor = isDarkMode
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section Header
                    SizedBox(
                      width: double.infinity,
                      child: Container(
                        color: headerBgColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          groupName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: headerTextColor,
                          ),
                        ),
                      ),
                    ),
                    // Account Items
                    ...groupAccounts.map((acc) {
                      final balance = accountProvider.getBalance(
                        acc.id,
                        transactions,
                      );
                      final selected = selectedAccountId == acc.id;
                      final surfaceColor = isDarkMode
                          ? AppColors.darkSurface
                          : AppColors.surface;
                      final textPrimaryColor = isDarkMode
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary;
                      final dividerColor = isDarkMode
                          ? AppColors.darkDivider
                          : AppColors.divider;

                      return Column(
                        children: [
                          InkWell(
                            onTap: () => Navigator.pop(context, acc.id),
                            child: Container(
                              color: surfaceColor,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  AccountIconWidget(
                                    account: acc,
                                    size: 36,
                                    isDarkMode: isDarkMode,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          acc.name,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: textPrimaryColor,
                                          ),
                                        ),
                                        Text(
                                          formatAmount(balance),
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.getAmountColor(
                                              balance,
                                              isDarkMode,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (selected)
                                    Icon(
                                      Icons.check,
                                      color: colorScheme.primary,
                                    ),
                                ],
                              ),
                            ),
                          ),
                          Divider(height: 1, color: dividerColor),
                        ],
                      );
                    }),
                  ],
                );
              },
            ),
          ),
          const SafeArea(top: false, child: SizedBox()),
        ],
      ),
    );
  }
}
