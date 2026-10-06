import 'package:flutter/material.dart';
import 'package:money_vibe/screens/account/portfolio_analyze_screen.dart';
import 'package:provider/provider.dart';
import '../../models/account.dart';
import '../../models/stock_holding.dart';
import '../../providers/account_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../widgets/app_inset_card.dart';
import '../../widgets/app_modal_bottom_sheet.dart';
import '../trade/broker_report_list_screen.dart';

void showPortfolioMenuSheet(
  BuildContext context, {
  required Account account,
  required void Function(BuildContext context) onBuy,
  required void Function(BuildContext context) onAddHolding,
  required void Function(List<StockHolding> holdings, bool isDarkMode)
  onReorderGroups,
}) {
  final isDarkMode = context.read<SettingsProvider>().isDarkMode;
  final textColor = isDarkMode
      ? AppColors.darkTextPrimary
      : AppColors.textPrimary;
  final textSecondary = isDarkMode
      ? AppColors.darkTextSecondary
      : AppColors.textSecondary;
  final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;
  final incomeColor = isDarkMode ? AppColors.darkIncome : AppColors.income;

  showAppModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setStateModal) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppModalBottomSheetHeader(
                    title: 'ตัวเลือกพอร์ตการลงทุน',
                  ),
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
                        _buildPortfolioMenuTile(
                          icon: Icons.add_shopping_cart_rounded,
                          iconColor: incomeColor,
                          title: 'ซื้อหุ้นใหม่',
                          subtitle: 'บันทึกรายการซื้อหุ้นเข้าพอร์ต',
                          textColor: textColor,
                          secondaryColor: textSecondary,
                          bgColor: isDarkMode
                              ? AppColors.darkSurface
                              : AppColors.surface,
                          onTap: () {
                            Navigator.pop(context);
                            onBuy(context);
                          },
                        ),
                        const AppCardDivider(),
                        _buildPortfolioMenuTile(
                          icon: Icons.add_circle_outline_rounded,
                          iconColor: textColor,
                          title: 'เพิ่มหุ้นเป็นยอดตั้งต้น',
                          subtitle: 'เพิ่มข้อมูลหุ้นเดิมที่มีอยู่แล้วเข้าพอร์ต',
                          textColor: textColor,
                          secondaryColor: textSecondary,
                          bgColor: isDarkMode
                              ? AppColors.darkSurface
                              : AppColors.surface,
                          onTap: () {
                            Navigator.pop(context);
                            onAddHolding(context);
                          },
                        ),
                        if (account.isUsPortfolio) ...[
                          const AppCardDivider(),
                          _buildPortfolioMenuTile(
                            icon: Icons.edit_document,
                            iconColor: textColor,
                            title: 'ปรับรายงานประจำปี',
                            subtitle: 'นำเข้าและตรวจทานรายงาน Broker สหรัฐฯ',
                            textColor: textColor,
                            secondaryColor: textSecondary,
                            bgColor: isDarkMode
                                ? AppColors.darkSurface
                                : AppColors.surface,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BrokerReportListScreen(
                                    portfolioId: account.id,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                        const AppCardDivider(),
                        _buildPortfolioMenuTile(
                          icon: Icons.auto_awesome_rounded,
                          iconColor: isDarkMode
                              ? AppColors.darkFabYellow
                              : AppColors.fabYellow,
                          title: 'วิเคราะห์พอร์ต',
                          subtitle: 'ตรวจสอบการกระจายความเสี่ยงและผลตอบแทน',
                          textColor: textColor,
                          secondaryColor: textSecondary,
                          bgColor: isDarkMode
                              ? AppColors.darkSurface
                              : AppColors.surface,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PortfolioAnalyzeScreen(
                                  accountId: account.id,
                                ),
                              ),
                            );
                          },
                        ),
                        const AppCardDivider(),
                        _buildPortfolioMenuTile(
                          icon: Icons.account_tree_outlined,
                          iconColor: textColor,
                          title: 'จัดลำดับกลุ่ม',
                          subtitle: 'ลากและสลับลำดับการแสดงผลของกลุ่มพอร์ต',
                          textColor: textColor,
                          secondaryColor: textSecondary,
                          bgColor: isDarkMode
                              ? AppColors.darkSurface
                              : AppColors.surface,
                          onTap: () {
                            final holdings = context
                                .read<AccountProvider>()
                                .getHoldings(account.id);
                            Navigator.pop(context);
                            onReorderGroups(holdings, isDarkMode);
                          },
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
  );
}

Widget _buildPortfolioMenuTile({
  required IconData icon,
  required Color iconColor,
  required String title,
  required String subtitle,
  required Color textColor,
  required Color secondaryColor,
  required Color bgColor,
  required VoidCallback onTap,
}) {
  return ListTile(
    leading: Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: iconColor, size: 20),
    ),
    title: Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
    ),
    subtitle: Text(
      subtitle,
      style: TextStyle(fontSize: 12, color: secondaryColor),
    ),
    trailing: Icon(
      Icons.chevron_right_rounded,
      size: 18,
      color: secondaryColor.withValues(alpha: 0.5),
    ),
    onTap: onTap,
  );
}
