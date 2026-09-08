# Shared monthly financial cycle

Status: resolved

## Behavior

- Settings provides one monthly cycle start day for budgets and yearly statistics.
- Existing budget start day wins when migrating from separate settings; the old statistics value is the fallback.
- A cycle is named for its starting month. With day 21, September is 21 September through 20 October.
- For days 29-31, each month's start is clamped independently to that month's final day.
- Tapping a populated month row in yearly statistics opens the transactions included in that row's totals.

## Validation

- `dart format .`
- `flutter analyze`
