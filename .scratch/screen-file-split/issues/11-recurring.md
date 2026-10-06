# 11 recurring_form (1,527) / recurring_detail (1,328) / recurring_list (830)

Status: resolved

recurring_form:
- `recurring_form_screen.dart` — State, keyboard, save/delete
- `recurring_form_widgets.dart` — `_RecurringTypeSegmentedControl`, `_RecurringAmountHeroCard`, `_ToggleRow`, `_RowTile`
- `recurring_month_year_picker.dart` — `_showMonthYearPicker` (~160 lines)
- `recurring_pickers.dart` — type, category, day-of-month, notification-time sheets

recurring_detail:
- `recurring_occurrence_item.dart` — `_OccurrenceItem`, `_StatusBadge`, `_ActionButton`
- `recurring_detail_widgets.dart` — `_DetailRow`, `_TypeBadge`, `_EmptyState`, `_RemainingSummary`

recurring_list:
- `recurring_list_item.dart` — `_RecurringItem` + menu, `_StatusChip`
- `_TypeBadge` is defined in both list and detail: share one `recurring_type_badge.dart` if identical.

## Comments

Done. detail 1,328 → 670 and list 830 → 530 (pure moves). form 1,527 → 890: pickers → `recurring_form_pickers.dart` (selected + onSelected), month range rows and delete button → widgets. Form drops below 800 after ticket 18. `_TypeBadge` differs between list/detail (font 11 vs 12) so they stay separate until ticket 17.
