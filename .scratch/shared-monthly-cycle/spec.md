# Shared monthly financial cycle

Status: resolved

## Behavior

- Settings provides one monthly cycle start day for budgets and yearly statistics.
- Existing budget start day wins when migrating from separate settings; the old statistics value is the fallback.
- A cycle is named for its ending month. With day 21, September is 21 August through 20 September.
- With day 1, each reporting month is the matching calendar month.
- Yearly statistics contain the 12 cycles ending from January through December. With day 21, 2026 is 21 December 2025 through 20 December 2026.
- For days 29-31, each month's start is clamped independently to that month's final day.
- The budget app-bar title shows the reporting month and year, while the selector shows its exact date range.
- The budget returns to the current cycle when the start-day setting changes.
- The Settings day picker scrolls within short viewports without overflowing.
- Tapping a populated month row in yearly statistics opens the transactions included in that row's totals.

## Validation

- `dart format .`
- `flutter analyze`
