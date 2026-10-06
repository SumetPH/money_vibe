# 12 budget_form_screen.dart (1,226 lines)

Status: resolved

- `budget_form_screen.dart` — State, keyboard, save/delete, conflict handling
- `budget_form_rows.dart` — `_buildInputFieldRow`, `_buildAmountInputRow`, `_buildTypeSelectorRow`, `_buildPickerRow`,
  `_buildSwitchRow`, `_buildDeleteRow`
- `budget_live_preview_card.dart` — `_buildLivePreviewCard`
- `budget_category_picker_sheet.dart` — `_pickCategories` (~190 lines)

## Comments

Done. 1,226 → 749. Category picker gets the same mutable `_selectedCategoryIds` set (mutated in place, as before) plus `confirmCategoryTransfer` / `isMounted` / `onChanged` callbacks. Amount and type-selector rows stay in State (they call setState).
