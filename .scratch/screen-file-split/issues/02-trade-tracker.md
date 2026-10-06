# 02 trade_tracker_screen.dart (3,545 lines)

Status: ready-for-agent

Proposed files in `lib/screens/trade/`:
- `trade_tracker_screen.dart` — State, tab bar, app bar actions, menus, export, open/delete actions
- `trade_tracker_models.dart` — `_TradeSummary`, `_FeeSummary`, `_MonthlyTradeSummary`, `_TradeMonthGroup`,
  `_PurchaseMonthGroup`, `_AnnualTaxSummary`, `_PortfolioAnnualReportSummary`, `_TradePnlFilter`
- `trade_sale_history_tab.dart` — `_SaleHistoryTab`, `_TradeMonthSection`, `_MonthlyTradeTable`
- `trade_purchase_history_tab.dart` — `_PurchaseHistoryTab`, `_PurchaseMonthSection`, `_PurchaseListItem`
- `trade_yearly_tab.dart` — `_YearlyTradeTab`
- `trade_annual_tax_tab.dart` — `_AnnualTaxTab`, `_AnnualTaxSummaryPanel`, `_AnnualPrincipalSummarySection`,
  `_AnnualReportTaxListItem`, `_CompactTaxMetric`
- `trade_summary_panel.dart` — `_SummaryPanel`, `_FeeSummaryPanel`, `_FeeSummaryBreakdown`, `_SummaryMetric`, `_TradeInsetCard`
- `trade_filter_bar.dart` — `_FilterBar`, portfolio picker + tile, `_PnlFilterChips`, `_FilterChipButton`, `_YearSelector`
- `trade_list_item.dart` — `_TradeListItem`, `_TradeDetailRow`, `_TickerFallback`, `_EmptyTradeState`
