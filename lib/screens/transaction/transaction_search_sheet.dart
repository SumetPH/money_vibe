import 'package:flutter/cupertino.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_modal_bottom_sheet.dart';

void showTransactionSearchSheet(
  BuildContext context,
  bool isDarkMode, {
  required String query,
  required ValueChanged<String> onChanged,
}) {
  final textPrimary = isDarkMode
      ? AppColors.darkTextPrimary
      : AppColors.textPrimary;
  final textSecondary = isDarkMode
      ? AppColors.darkTextSecondary
      : AppColors.textSecondary;

  showAppModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          20 + MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppModalBottomSheetHeader(title: 'ค้นหาธุรกรรม'),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: CupertinoSearchTextField(
                controller: TextEditingController(text: query)
                  ..selection = TextSelection.collapsed(offset: query.length),
                autofocus: true,
                onChanged: onChanged,
                onSubmitted: (_) => Navigator.pop(sheetContext),
                onSuffixTap: () {
                  onChanged('');
                  Navigator.pop(sheetContext);
                },
                placeholder: 'ค้นหาบัญชี หมวดหมู่ หรือโน้ต...',
                placeholderStyle: TextStyle(
                  fontSize: 14,
                  color: textSecondary.withValues(alpha: 0.55),
                ),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: textPrimary,
                ),
                backgroundColor: isDarkMode
                    ? AppColors.darkSurfaceVariant
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 0,
                ),
                prefixInsets: const EdgeInsetsDirectional.fromSTEB(10, 0, 6, 0),
                suffixInsets: const EdgeInsetsDirectional.fromSTEB(0, 0, 8, 0),
                itemColor: textSecondary.withValues(alpha: 0.6),
                itemSize: 18,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
