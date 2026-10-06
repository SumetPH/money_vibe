# 07 transaction_list_screen.dart (1,510 lines)

Status: resolved

Proposed files in `lib/screens/transaction/`:
- `transaction_list_screen.dart` — State, filtering, grouping
- `transaction_list_models.dart` — `_TransactionListData`, `_TransactionDateGroup`, `_MutableTransactionDateGroup`,
  `_PeriodFilter`, `_TransactionTypeFilter`
- `transaction_search_sheet.dart` — `_showSearchSheet` (~320 lines)
- `transaction_period_picker_sheet.dart` — `_showPeriodPicker`, `_pickCustomRange`
- `transaction_cash_flow_summary.dart` — `_CashFlowSummary`, `_SummaryAmount`, `_HeaderAction`
- `transaction_list_item.dart` — `_TransactionItem`

## Comments

Done. Screen 1,510 → 792 lines. Search sheet stays in the State on purpose: its builder re-reads `_searchQuery` on every rebuild (keyboard insets), so moving it out would change behavior.
