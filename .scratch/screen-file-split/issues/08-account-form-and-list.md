# 08 account_form_screen.dart (1,645) + account_list_screen.dart (1,553)

Status: resolved

One commit per file.

account_form:
- `account_form_screen.dart` — State, keyboard, save/delete
- `account_form_rows.dart` — `_buildTextFieldRow`, `_buildPickerRow`, `_buildReadOnlyRow`, `_buildSwitchRow`,
  `_buildDayPickerRow`, `_buildExchangeRateField`, `_buildDeleteCard` (check `lib/widgets/app_form_row.dart` first; reuse it where identical)
- `account_balance_hero_card.dart` — `_buildHeroBalanceCard`
- `account_type_picker_sheet.dart`, `account_currency_picker_sheet.dart`
- `account_icon_picker_sheet.dart` — `_pickIcon`, `_pickCustomIcon`, `_showIconGrid`, `_buildCustomIconPreview`

account_list:
- `account_list_screen.dart` — State, list, navigation
- `account_app_menu_sheet.dart` — `_showAppMenu`
- `account_summary_sheet.dart` — `_showSummaryModal`, `_SummaryRow`
- `account_total_row.dart` — `_AccountTotals`, `_TotalRow` + its menu
- `account_net_worth_filter_sheet.dart` — `_NetWorthFilterSheet`
- `account_list_item.dart` — `_AccountItem` + its menu

## Comments

Done. account_list 1,553 → 692 (pure move). account_form 1,645 → 873: row builders, hero/delete cards → `account_form_rows.dart`; type/currency/icon-source sheets → `account_form_pickers.dart` with callbacks. Drops below 800 after ticket 18.
