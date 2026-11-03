import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';
import '../utils/currency_utils.dart';
import 'app_modal_bottom_sheet.dart';

/// sheet เลือกสกุลเงินจาก [CurrencyUtils.currencies]
void showCurrencyPickerSheet(
  BuildContext context, {
  required String selectedCurrency,
  required ValueChanged<String> onSelected,
  Set<String> excludedCurrencies = const {},
}) {
  final currencies = CurrencyUtils.currencies
      .where((c) => !excludedCurrencies.contains(c.code))
      .toList(growable: false);
  showAppModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => Consumer<SettingsProvider>(
      builder: (context, settingsProvider, _) {
        final isDarkMode = settingsProvider.isDarkMode;
        final surfaceColor = isDarkMode
            ? AppColors.darkSurface
            : AppColors.surface;
        final textPrimaryColor = isDarkMode
            ? AppColors.darkTextPrimary
            : AppColors.textPrimary;
        final textSecondaryColor = isDarkMode
            ? AppColors.darkTextSecondary
            : AppColors.textSecondary;
        final headerColor = isDarkMode
            ? AppColors.darkIncome
            : AppColors.header;

        return AppDraggableSheet(
          builder: (context, scrollController) => SafeArea(
            child: CustomScrollView(
              controller: scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: AppModalBottomSheetHeader(title: 'เลือกสกุลเงิน'),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate((_, i) {
                    final currency = currencies[i];
                    final code = currency.code;
                    final symbol = currency.symbol;
                    final name = currency.name;
                    final selected = code == selectedCurrency;
                    return ListTile(
                      tileColor: surfaceColor,
                      title: Text(
                        '$code - $name',
                        style: TextStyle(color: textPrimaryColor, fontSize: 15),
                      ),
                      subtitle: Text(
                        'สัญลักษณ์: $symbol',
                        style: TextStyle(
                          color: textSecondaryColor,
                          fontSize: 13,
                        ),
                      ),
                      trailing: selected
                          ? Icon(Icons.check, color: headerColor)
                          : null,
                      onTap: () {
                        onSelected(code);
                        Navigator.pop(context);
                      },
                    );
                  }, childCount: currencies.length),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
