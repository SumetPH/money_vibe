import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/transaction.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../widgets/app_modal_bottom_sheet.dart';

/// หัวข้อสรุปผลการค้นหา เช่น `ค้นหา "กาแฟ" · รายจ่าย · เงินต่างประเทศ`
String transactionSearchTitle(
  String query,
  TransactionType? type,
  bool isForeignOnly,
) {
  final typeLabel = type?.label;
  return [
    if (query.isNotEmpty) 'ค้นหา "$query"',
    if (typeLabel != null) query.isEmpty ? 'ประเภท $typeLabel' : typeLabel,
    if (isForeignOnly) 'เงินต่างประเทศ',
  ].join(' · ');
}

/// เปิด sheet ค้นหาธุรกรรมด้วยข้อความและกรองตามประเภท ([type] = null คือทุกประเภท)
/// และกรองเฉพาะรายการที่ชำระด้วยเงินต่างประเทศ ([isForeignOnly])
void showTransactionSearchSheet(
  BuildContext context,
  bool isDarkMode, {
  required String query,
  required TransactionType? type,
  required bool isForeignOnly,
  required Color accentColor,
  required ValueChanged<String> onChanged,
  required ValueChanged<TransactionType?> onTypeChanged,
  required ValueChanged<bool> onForeignOnlyChanged,
  required VoidCallback onClear,
}) {
  showAppModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => TransactionSearchSheetContent(
      isDarkMode: isDarkMode,
      initialQuery: query,
      initialType: type,
      initialForeignOnly: isForeignOnly,
      accentColor: accentColor,
      onChanged: onChanged,
      onTypeChanged: onTypeChanged,
      onForeignOnlyChanged: onForeignOnlyChanged,
      onClear: onClear,
    ),
  );
}

class TransactionSearchSheetContent extends StatefulWidget {
  final bool isDarkMode;
  final String initialQuery;
  final TransactionType? initialType;
  final bool initialForeignOnly;
  final Color accentColor;
  final ValueChanged<String> onChanged;
  final ValueChanged<TransactionType?> onTypeChanged;
  final ValueChanged<bool> onForeignOnlyChanged;
  final VoidCallback onClear;

  const TransactionSearchSheetContent({
    super.key,
    required this.isDarkMode,
    required this.initialQuery,
    required this.initialType,
    required this.initialForeignOnly,
    required this.accentColor,
    required this.onChanged,
    required this.onTypeChanged,
    required this.onForeignOnlyChanged,
    required this.onClear,
  });

  @override
  State<TransactionSearchSheetContent> createState() =>
      _TransactionSearchSheetContentState();
}

class _TransactionSearchSheetContentState
    extends State<TransactionSearchSheetContent> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialQuery,
  )..selection = TextSelection.collapsed(offset: widget.initialQuery.length);
  late TransactionType? _type = widget.initialType;
  late bool _isForeignOnly = widget.initialForeignOnly;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _selectType(TransactionType? type) {
    setState(() => _type = type);
    widget.onTypeChanged(type);
  }

  void _toggleForeignOnly() {
    final value = !_isForeignOnly;
    setState(() => _isForeignOnly = value);
    widget.onForeignOnlyChanged(value);
  }

  void _clear() {
    widget.onClear();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = widget.isDarkMode;
    final textPrimary = AppColors.textPrimaryFor(isDarkMode);
    final textSecondary = AppColors.textSecondaryFor(isDarkMode);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppModalBottomSheetHeader(title: 'ค้นหาธุรกรรม'),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: CupertinoSearchTextField(
                controller: _controller,
                autofocus: true,
                onChanged: widget.onChanged,
                onSubmitted: (_) => Navigator.pop(context),
                onSuffixTap: _clear,
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
            const SizedBox(height: 16),
            Text(
              'ประเภทรายการ',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in <TransactionType?>[
                  null,
                  ...TransactionType.values,
                ])
                  TransactionSearchTypeChip(
                    label: type?.label ?? 'ทั้งหมด',
                    isSelected: _type == type,
                    isDarkMode: isDarkMode,
                    accentColor: widget.accentColor,
                    onTap: () => _selectType(type),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'การชำระเงิน',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TransactionSearchTypeChip(
                label: 'ชำระด้วยเงินต่างประเทศ',
                isSelected: _isForeignOnly,
                isDarkMode: isDarkMode,
                accentColor: widget.accentColor,
                onTap: _toggleForeignOnly,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ชิปเลือกประเภทรายการใน sheet ค้นหา
class TransactionSearchTypeChip extends StatelessWidget {
  static const double _selectedTintAlpha = 0.12;

  final String label;
  final bool isSelected;
  final bool isDarkMode;
  final Color accentColor;
  final VoidCallback onTap;

  const TransactionSearchTypeChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.isDarkMode,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? accentColor.withValues(alpha: _selectedTintAlpha)
          : AppColors.insetFillFor(isDarkMode),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.full),
        side: BorderSide(
          color: isSelected ? accentColor : AppColors.borderFor(isDarkMode),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? accentColor
                  : AppColors.textSecondaryFor(isDarkMode),
            ),
          ),
        ),
      ),
    );
  }
}
