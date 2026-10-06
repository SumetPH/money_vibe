# 09 portfolio_investment_plan_screen.dart (1,642 lines)

Status: resolved

- `portfolio_investment_plan_screen.dart` — State, save/debounce (unchanged), DCA handling
- `investment_plan_target_editor.dart` — `_buildTargetEditor`, `_buildTargetRow`, `_TargetTotalBadge`
- `investment_plan_stock_selection_sheet.dart` — `_showStockSelectionSheet`
- `investment_plan_rebalance.dart` — `_buildRebalanceRows`, `_RebalanceRow`
- `investment_plan_recommendation.dart` — `_buildBuyRecommendation`, `_RecommendationRow`
- `investment_plan_widgets.dart` — `_Section`, `_MetricTile`, `_buildDcaChecklist`

Debounce timers and target save logic must stay in the State.

## Comments

Done. Screen 1,642 → 795. Stock selection sheet takes `targetFor`/`saveTarget` closures so it still reads live targets after each save. Debounce/save logic untouched in State.
