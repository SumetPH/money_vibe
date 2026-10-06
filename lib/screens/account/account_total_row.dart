import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/account.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../main.dart';
import '../../widgets/app_modal_bottom_sheet.dart';
import 'account_net_worth_filter_sheet.dart';

class AccountTotalRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool isDarkMode;
  final List<Account> accounts;
  final Set<String>? filterIds;
  final bool isReorderMode;
  final VoidCallback onAddTransaction;
  final VoidCallback onAddAccount;
  final VoidCallback onShowSummary;

  const AccountTotalRow({
    super.key,
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
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppRadii.xLarge),
        border: Border.all(
          color: dividerColor.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadii.large),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadii.large),
                    onTap: isReorderMode ? null : () => _showTotalMenu(context),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
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
                    ),
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
            const SizedBox(height: 12),
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
    );
  }

  Widget _buildAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;

    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadii.large),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: textColor),
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
          final textColor = isDarkMode
              ? AppColors.darkTextPrimary
              : AppColors.textPrimary;
          final textSecondary = isDarkMode
              ? AppColors.darkTextSecondary
              : AppColors.textSecondary;
          final dividerColor = isDarkMode
              ? AppColors.darkDivider
              : AppColors.divider;
          final accentColor = isDarkMode
              ? AppColors.darkFabYellow
              : AppColors.fabYellow;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppModalBottomSheetHeader(title: 'ยอดเงินสุทธิ'),
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
                    child: ListTile(
                      leading: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadii.medium),
                        ),
                        child: Icon(
                          Icons.filter_list_rounded,
                          color: accentColor,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        'เลือกบัญชีที่คำนวณ',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'กำหนดว่าบัญชีใดบ้างที่จะนำมาคิดยอดรวม',
                        style: TextStyle(color: textSecondary, fontSize: 12),
                      ),
                      trailing: filterIds != null
                          ? Text(
                              '${filterIds!.length}/${accounts.length}',
                              style: TextStyle(
                                color: accentColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            )
                          : null,
                      onTap: () {
                        Navigator.pop(context);
                        _showNetWorthFilterSheet(context, settingsProvider);
                      },
                    ),
                  ),
                ],
              ),
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
      builder: (_) => AccountNetWorthFilterSheet(
        accounts: accounts,
        filterIds: filterIds,
        isDarkMode: isDarkMode,
        onSave: (selected) => settingsProvider.setNetWorthFilterIds(selected),
      ),
    );
  }
}
