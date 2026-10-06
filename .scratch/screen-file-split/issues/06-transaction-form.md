# 06 transaction_form_screen.dart (1,976 lines)

Status: resolved

Proposed files in `lib/screens/transaction/`:
- `transaction_form_screen.dart` — State, keyboard, save/delete, pickers
- `transaction_type_picker.dart` — `_TypeSegmentedControl`, `_showAllTypePicker`
- `transaction_amount_hero_card.dart` — `_AmountHeroCard` (~320 lines)
- `transaction_selection_group_card.dart` — `_SelectionGroupCard`, `_SelectionRow`
- `transaction_meta_info_card.dart` — `_MetaInfoCard`

Do not touch the keyboard/amount-format logic here (see ticket 18).

## Comments

Done. Screen 1,976 → 824 lines; drops below 800 once ticket 18 removes the duplicated keyboard code. Type picker sheet is `showTransactionTypePicker` (keyboard close stays in the State).
