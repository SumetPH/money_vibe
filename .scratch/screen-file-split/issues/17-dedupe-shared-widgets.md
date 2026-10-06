# 17 Deduplicate private widgets into lib/widgets

Status: resolved

Blocked by: 02, 03, 05, 09, 11

## Findings and decisions

| Private widgets | Difference | Action |
|---|---|---|
| `_StatisticsInsetCard`, `_TradeInsetCard` | Same look as `AppInsetCard` (surface, `xLarge` radius, border alpha 0.4); only bottom margin 16 | Replace with `AppInsetCard(margin: EdgeInsets.fromLTRB(16, 0, 16, 16), ...)`. No visual change |
| recurring `_TypeBadge` ×2, `_StatusChip`, `_StatusBadge` | Same as `AppStatusChip`, only padding/font size differ (5–7 / 1–3 px, font 10–12) | Replace with `AppStatusChip`. Accepted: badges change by 1–2 px for consistency. `_StatusBadge` keeps its status → (label, color) mapping |
| budget `_MetricTile` (value 14), plan `_MetricTile` (value 13), trade `_SummaryMetric` (label w600, gap 3, colored value, `alignEnd`) | Same label/value layout, minor typography | New `AppMetricText` (label 11/w600, value 13/w700, `valueColor`, `alignEnd`). Accepted: budget value 14 → 13 |
| statistics `_StatSummaryMetric` | `AppMetricText` inside a tinted box | Compose: box + `AppMetricText` |
| statistics `_StatsYearSelector`, trade `_YearSelector` | Same chevron + year row; statistics adds a cycle-period line, trade wraps it in an inset card | New `AppYearSelector` (chevron row + tooltips). Statistics adds its period line below; trade wraps it in `AppInsetCard` |

## Rules

- Add `AppMetricText` and `AppYearSelector` to `docs/design.md` ("Shared widgets และ tokens").
- Add `tool/check_design.sh` rules if a pattern is easy to detect (e.g. `withValues(alpha: 0.12)` + `AppRadii.full` outside `app_status_chip.dart`).
- Check light and dark mode for every replaced site.

## Comments

Done (one commit per row of the table):
- Inset cards → `AppInsetCard(margin: AppInsetCard.stackedMargin)` (19 sites).
- Recurring badges → `AppStatusChip`; `RecurringOccurrenceStatusBadge` keeps only its status mapping.
- New `AppMetricText` replaces Budget/InvestmentPlan metric tiles and `TradeSummaryMetric`; `StatisticsSummaryMetric` keeps its tinted box around it.
- New `AppYearSelector` (with tooltips, `buttonInset`) used by statistics and trade.
- No check_design rule added: the patterns span multiple lines and are not reliably greppable.
