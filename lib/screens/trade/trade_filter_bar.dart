import 'package:flutter/material.dart';

import '../../models/account.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../widgets/app_modal_bottom_sheet.dart';
import 'trade_tracker_models.dart';

class TradeFilterBar extends StatelessWidget {
  final List<Account> portfolios;
  final String? selectedPortfolioId;
  final TradePnlFilter selectedPnlFilter;
  final bool isDarkMode;
  final ValueChanged<String?> onPortfolioChanged;
  final ValueChanged<TradePnlFilter> onPnlFilterChanged;

  const TradeFilterBar({
    super.key,
    required this.portfolios,
    required this.selectedPortfolioId,
    required this.selectedPnlFilter,
    required this.isDarkMode,
    required this.onPortfolioChanged,
    required this.onPnlFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final secondaryColor = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 640;
        Account? selectedPortfolio;
        for (final portfolio in portfolios) {
          if (portfolio.id == selectedPortfolioId) {
            selectedPortfolio = portfolio;
            break;
          }
        }
        final portfolioSelector = SizedBox(
          width: isWide ? 260 : double.infinity,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.medium),
            onTap: () async {
              final selected = await showTradePortfolioPickerSheet(
                context: context,
                portfolios: portfolios,
                selectedPortfolioId: selectedPortfolioId,
                isDarkMode: isDarkMode,
                includeAllOption: true,
              );
              if (selected == TradePortfolioPickerCanceled.value) return;
              onPortfolioChanged(
                selected == TradePortfolioPickerAll.value
                    ? null
                    : selected as String,
              );
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'พอร์ต',
                labelStyle: TextStyle(color: secondaryColor),
                prefixIcon: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: secondaryColor,
                  size: 20,
                ),
                suffixIcon: Icon(
                  Icons.keyboard_arrow_down,
                  color: secondaryColor,
                ),
                isDense: true,
                filled: true,
                fillColor: isDarkMode
                    ? AppColors.darkSurfaceVariant
                    : AppColors.sectionHeader,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              child: Text(
                selectedPortfolio?.name ?? 'ทุกพอร์ต',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: textColor, fontSize: 14),
              ),
            ),
          ),
        );

        final filters = TradePnlFilterChips(
          selected: selectedPnlFilter,
          isDarkMode: isDarkMode,
          onChanged: onPnlFilterChanged,
        );

        if (isWide) {
          return Row(
            children: [
              portfolioSelector,
              const SizedBox(width: 12),
              Expanded(
                child: Align(alignment: Alignment.centerRight, child: filters),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [portfolioSelector, const SizedBox(height: 12), filters],
        );
      },
    );
  }
}

enum TradePortfolioPickerCanceled { value }

enum TradePortfolioPickerAll { value }

Future<Object?> showTradePortfolioPickerSheet({
  required BuildContext context,
  required List<Account> portfolios,
  required String? selectedPortfolioId,
  required bool isDarkMode,
  required bool includeAllOption,
}) {
  final textColor = isDarkMode
      ? AppColors.darkTextPrimary
      : AppColors.textPrimary;
  final secondaryColor = isDarkMode
      ? AppColors.darkTextSecondary
      : AppColors.textSecondary;

  return showAppModalBottomSheet<Object?>(
    context: context,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppModalBottomSheetHeader(title: 'เลือกพอร์ต'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  if (includeAllOption)
                    TradePortfolioPickerTile(
                      title: 'ทุกพอร์ต',
                      selected: selectedPortfolioId == null,
                      textColor: textColor,
                      secondaryColor: secondaryColor,
                      onTap: () => Navigator.pop(
                        sheetContext,
                        TradePortfolioPickerAll.value,
                      ),
                    ),
                  ...portfolios.map(
                    (portfolio) => TradePortfolioPickerTile(
                      title: portfolio.name,
                      selected: portfolio.id == selectedPortfolioId,
                      textColor: textColor,
                      secondaryColor: secondaryColor,
                      onTap: () => Navigator.pop(sheetContext, portfolio.id),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  ).then((value) => value ?? TradePortfolioPickerCanceled.value);
}

class TradePortfolioPickerTile extends StatelessWidget {
  final String title;
  final bool selected;
  final Color textColor;
  final Color secondaryColor;
  final VoidCallback onTap;

  const TradePortfolioPickerTile({
    super.key,
    required this.title,
    required this.selected,
    required this.textColor,
    required this.secondaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: textColor),
      ),
      trailing: selected ? Icon(Icons.check, color: secondaryColor) : null,
      onTap: onTap,
    );
  }
}

class TradePnlFilterChips extends StatelessWidget {
  final TradePnlFilter selected;
  final bool isDarkMode;
  final ValueChanged<TradePnlFilter> onChanged;

  const TradePnlFilterChips({
    super.key,
    required this.selected,
    required this.isDarkMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        TradeFilterChipButton(
          icon: Icons.list_alt_outlined,
          label: 'ทั้งหมด',
          selected: selected == TradePnlFilter.all,
          isDarkMode: isDarkMode,
          onTap: () => onChanged(TradePnlFilter.all),
        ),
        TradeFilterChipButton(
          icon: Icons.trending_up,
          label: 'กำไร',
          selected: selected == TradePnlFilter.profit,
          isDarkMode: isDarkMode,
          color: isDarkMode ? AppColors.darkIncome : AppColors.income,
          onTap: () => onChanged(TradePnlFilter.profit),
        ),
        TradeFilterChipButton(
          icon: Icons.trending_down,
          label: 'ขาดทุน',
          selected: selected == TradePnlFilter.loss,
          isDarkMode: isDarkMode,
          color: isDarkMode ? AppColors.darkExpense : AppColors.expense,
          onTap: () => onChanged(TradePnlFilter.loss),
        ),
      ],
    );
  }
}

class TradeFilterChipButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool isDarkMode;
  final Color? color;
  final VoidCallback onTap;

  const TradeFilterChipButton({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.isDarkMode,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final selectedColor =
        color ?? (isDarkMode ? AppColors.darkTransfer : AppColors.transfer);
    final textColor = selected
        ? selectedColor
        : (isDarkMode ? AppColors.darkTextSecondary : AppColors.textSecondary);
    final bgColor = selected
        ? selectedColor.withValues(alpha: 0.14)
        : (isDarkMode ? AppColors.darkSurfaceVariant : AppColors.sectionHeader);
    final borderColor = selected
        ? selectedColor.withValues(alpha: 0.42)
        : Colors.transparent;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.medium),
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadii.medium),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: textColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
