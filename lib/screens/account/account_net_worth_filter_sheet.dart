import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/account.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/account_icon_widget.dart';
import '../../widgets/app_inset_card.dart';
import '../../widgets/app_modal_bottom_sheet.dart';
import '../../widgets/group_header.dart';

class AccountNetWorthFilterSheet extends StatefulWidget {
  final List<Account> accounts;
  final Set<String>? filterIds;
  final bool isDarkMode;
  final Future<void> Function(Set<String>?) onSave;

  const AccountNetWorthFilterSheet({
    super.key,
    required this.accounts,
    required this.filterIds,
    required this.isDarkMode,
    required this.onSave,
  });

  @override
  State<AccountNetWorthFilterSheet> createState() =>
      _NetWorthFilterSheetState();
}

class _NetWorthFilterSheetState extends State<AccountNetWorthFilterSheet> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    // null = all selected
    _selected = widget.filterIds != null
        ? Set.from(widget.filterIds!)
        : widget.accounts.map((a) => a.id).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = widget.isDarkMode;
    final bgColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final textPrimary = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final textSecondary = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final accentColor = AppColors.accentFor(
      isDarkMode,
      context.watch<SettingsProvider>().themeColor,
    );
    // Theme accents are dark in light mode and light in dark mode.
    final onAccentColor =
        ThemeData.estimateBrightnessForColor(accentColor) == Brightness.dark
        ? Colors.white
        : Colors.black;

    final allIds = widget.accounts.map((a) => a.id).toSet();
    final isAllSelected = _selected.containsAll(allIds);

    final Map<String, List<Account>> grouped = {};
    for (final a in widget.accounts) {
      grouped.putIfAbsent(accountTypeDisplayGroup(a.type), () => []).add(a);
    }

    return SafeArea(
      child: AppDraggableSheet(
        builder: (_, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'เลือกบัญชีที่คำนวณยอดรวม',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    onPressed: () {
                      setState(() {
                        if (isAllSelected) {
                          _selected.clear();
                        } else {
                          _selected = Set.from(allIds);
                        }
                      });
                    },
                    child: Text(
                      isAllSelected ? 'ยกเลิกทั้งหมด' : 'เลือกทั้งหมด',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                children: [
                  for (final group in accountGroupsForAccountList)
                    if (grouped.containsKey(group.label)) ...[
                      GroupHeader(title: group.label, isDarkMode: isDarkMode),
                      for (final account in grouped[group.label]!)
                        CheckboxListTile(
                          tileColor: bgColor,
                          value: _selected.contains(account.id),
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                _selected.add(account.id);
                              } else {
                                _selected.remove(account.id);
                              }
                            });
                          },
                          secondary: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: account.color.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: AccountIconWidget(
                              account: account,
                              size: 20,
                              isDarkMode: isDarkMode,
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                account.name,
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 15,
                                ),
                              ),
                              if (account.isHidden) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? Colors.white.withValues(alpha: 0.1)
                                        : Colors.black.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'ซ่อนอยู่',
                                    style: TextStyle(
                                      color: textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          activeColor: accentColor,
                          checkColor: onAccentColor,
                          controlAffinity: ListTileControlAffinity.trailing,
                        ),
                      const AppCardDivider(),
                    ],
                ],
              ),
            ),
            Container(
              color: bgColor,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: onAccentColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    // If all selected → save null (no filter)
                    final saveValue =
                        _selected.containsAll(allIds) &&
                            allIds.containsAll(_selected)
                        ? null
                        : _selected.isEmpty
                        ? <String>{}
                        : _selected;
                    await widget.onSave(saveValue);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Text(
                    'บันทึก',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
