# 05 budget_list_screen.dart (2,023 lines)

Status: resolved

Proposed files in `lib/screens/budget/`:
- `budget_list_screen.dart` — State, month navigation, list, menu
- `budget_summary_header.dart` — `_SummaryHeader`, `_MetricTile`
- `budget_item_card.dart` — `_BudgetItemCard`, `_BudgetItemRow`, `_BudgetProgressBar`
- `budget_group_details_sheet.dart` — `_BudgetGroupSummary`, `_BudgetGroupDetailsSheet`, `_GroupDetailMetric`
- `budget_empty_state.dart` — `_buildEmptyState`

## Comments

Done. Screen 2,023 → 664 lines. Menu sheet takes `isReorderMode` + `onReorderModeChanged`; empty state is `BudgetEmptyState`; `_buildBudgetList` stays in State.
