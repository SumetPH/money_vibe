import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/account.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../main.dart';
import '../../widgets/account_icon_widget.dart';
import '../../widgets/app_modal_bottom_sheet.dart';

class AccountListItem extends StatelessWidget {
  final Account account;
  final double balance;
  final bool isReorderMode;
  final int? reorderIndex;
  final VoidCallback onTap;
  final VoidCallback onTapEdit;
  final bool isDarkMode;
  final bool showDivider;

  const AccountListItem({
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
                  size: 40,
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              account.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: textPrimaryColor,
                              ),
                            ),
                          ),
                          if (account.isHidden) ...[
                            const SizedBox(width: 6),
                            Tooltip(
                              message: 'บัญชีนี้ถูกซ่อน',
                              child: Icon(
                                Icons.visibility_off_outlined,
                                size: 16,
                                color: isDarkMode
                                    ? AppColors.darkTextSecondary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
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
          Divider(height: 1, color: AppColors.listDividerFor(isDarkMode)),
      ],
    );
  }

  void _showAccountMenu(BuildContext context) {
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
          final incomeColor = isDarkMode
              ? AppColors.darkIncome
              : AppColors.income;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppModalBottomSheetHeader(title: account.name),
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
                          color: incomeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadii.medium),
                        ),
                        child: Icon(
                          Icons.edit_rounded,
                          color: incomeColor,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        'แก้ไขข้อมูลบัญชี',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'เปลี่ยนชื่อ ชนิด หรือการตั้งค่าของบัญชี',
                        style: TextStyle(color: textSecondary, fontSize: 12),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: textSecondary.withValues(alpha: 0.6),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        onTapEdit();
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
}
