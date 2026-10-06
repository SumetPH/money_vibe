# Split large screen files into per-widget files

Status: needs-triage

## Problem

`lib/screens/cash_flow/` splits sections, sheets and dialogs into their own files (largest file: 536 lines).
Every other module keeps everything inside one screen file. 27 files exceed 400 lines; 14 exceed 1,000
(largest: `trade_tracker_screen.dart` at 3,545). Large files are slow to navigate, produce noisy diffs, and
agents often read only part of them and edit the wrong place.

## Goal

Every module under `lib/screens/` follows the `cash_flow` layout, with **zero behavior change**.

## Conventions

- Target: screen files ≤ ~400 lines, hard cap 800 (`rules/coding-style.md`).
- Extract when a piece is self-contained: a tab, section, bottom sheet, dialog, list item, summary card, or
  a data/aggregation class used only by the UI.
- Do not extract a widget under ~40 lines that is only used in one place.
- Keep files flat inside the module folder (same as `cash_flow`). File name = widget role, prefixed by feature:
  `trade_annual_tax_tab.dart`, `budget_group_details_sheet.dart`, `account_net_worth_filter_sheet.dart`.
- Extracted classes become public with a feature prefix (`_MetricTile` → `BudgetMetricTile`) to avoid name clashes.
  Do not use `part` / `part of`.
- The screen file keeps: the `State`, lifecycle, Provider wiring, navigation, and save/delete actions.
  Extracted widgets receive data plus callbacks; no new state management.
- If many widgets in one module need the same derived data, add a `<feature>_scope.dart` helper like
  `cash_flow_forecast_scope.dart` (functions over `context.watch`), not a new Provider.
- Pure data/aggregation classes (`_TradeSummary`, `_BudgetGroupSummary`, ...) move unchanged into
  `<feature>_models.dart` next to the screen. Do not move them into `lib/models/` in this effort.

## Zero regression rules

- Move code; do not rewrite it. Calculation, validation, debounce, Provider and repository calls stay byte-identical
  apart from renamed identifiers and passed-in parameters.
- One screen file per commit, so each step can be reverted on its own.
- Each ticket must pass: `dart format .`, `flutter analyze` (no new issues), `tool/check_design.sh`.
- Manually open the affected screen once (light + dark) before closing a ticket.

## Order

1. Ticket 01 (rules + guard) first.
2. Then largest/most-edited files first (tickets 02–16). Tickets are independent and can run in any order.
3. Ticket 17 (deduplicate private widgets into `lib/widgets`) after the module tickets that touch them.
4. Ticket 18 (calculator keyboard mixin): first make the mixin preserve the cursor, then migrate forms one by one.

## Out of scope

- Visual redesign, new features, renaming public screen classes or routes.
- Moving logic from screens into providers/services (separate effort if wanted).
- Files already ≤ 600 lines unless touched for another reason (`auth_screen`, `cash_flow_forecast_screen`,
  `portfolio_analyze_screen`, `broker_report_*`).
