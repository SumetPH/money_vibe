# 04 portfolio_detail_screen.dart (2,099 lines)

Status: resolved

Proposed files in `lib/screens/account/`:
- `portfolio_detail_screen.dart` — State, refresh, open forms
- `portfolio_hero_summary_card.dart` — `_HeroPortfolioSummaryCard`
- `portfolio_group_section.dart` — `_buildGroupSection` (~330 lines) as a widget
- `portfolio_menu_sheet.dart` — `_showMenuSheet` + `_buildMenuSheetTile`
- `portfolio_group_reorder_dialog.dart` — `_showGroupReorderDialog`
- `portfolio_edit_sheets.dart` — `_editExchangeRate`, `_editCashBalance`
- `portfolio_holding_logo.dart` — logo enrich/backfill/upload helpers (move unchanged; consider a service later)

## Comments

Done. Screen 2,099 → 793 lines. Group section is now `PortfolioGroupSection` (callbacks for holding actions); menu sheet, edit dialogs and group reorder dialog are top-level functions (reorder returns via `onSave`); service-free helpers live in `portfolio_holding_actions.dart`. Bodies unchanged apart from wiring.
