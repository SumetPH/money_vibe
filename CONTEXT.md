# Money Vibe Context

## Glossary

- **Recurring transaction**: A saved schedule that produces dated occurrences.
- **Occurrence**: One dated instance of a recurring transaction, with a pending, completed, or skipped state.
- **Current-month occurrence**: An occurrence dated in the calendar month containing the user's local current date. It remains in the current-and-upcoming view for that whole month.
- **Past occurrence**: An occurrence dated before the first day of the user's local current month.
- **Current net worth**: The combined value of included assets and liabilities at the user's current local time; it is the single value shown when all reporting periods are selected, with a zero baseline.
- **Period net worth**: The opening and closing net-worth values represented by the first and last visible points in the selected reporting period.
- **Net worth change**: The difference and percentage change between the first and last net-worth points visible in the selected reporting period.
- **Monthly financial cycle**: The period used by budgets and yearly statistics, named for the month in which it ends. With a start day of 21, September runs from 21 August through 20 September. If a month lacks the configured start day, its cycle starts on the month's final day.
- **Monthly cycle start day**: The single application setting that determines every monthly financial cycle.

## Reinstall reminders

- **Reinstall deadline**: The local-time instant five days after the first app launch following each installation, including reinstalling the same or an older version. _Avoid_: expiry date, install date
- **Reinstall reminder**: A one-time local notification issued when a reinstall deadline is reached. _Avoid_: expiry notification
- **Reinstall reminder setting**: The user preference that permits the reinstall reminder without hiding the reinstall deadline or its in-app status. _Avoid_: expiry setting
- **Installation status**: The in-app representation of the time remaining until, or passage of, a reinstall deadline. _Avoid_: expiration status

## iOS installation

- **Target iOS app**: The app identified by the Bundle ID of the current Xcode Runner target; test-target identifiers are separate apps.
- **Wireless install target**: A physical iPhone that Flutter reports through its wireless-device filter; simulators and wired devices are excluded.
- **App provisioning profile**: A signing profile whose application identifier exactly matches the target Team ID and Bundle ID; profiles for other apps or teams are unrelated.

## UI Design System

- **Main Tab**: One of the three primary mobile work areas: accounts, budgets, or transactions. Switching a Main Tab preserves each area's visible state. _Avoid_: Main route, bottom-nav page
- **Secondary Screen**: A screen opened from a Main Tab or another navigation entry that is not itself a Main Tab. Its bottom action surface may contain only the action applicable to that screen. _Avoid_: Nested tab, sub-tab
- **Primary Navigation**: The mobile Bottom Navigation, Drawer, and desktop Sidebar expose the same three Main Tabs rather than separate navigation hierarchies. _Avoid_: Drawer-only screen, sidebar-only screen
- **Inset Grouped Card**: An iOS-style rounded container card (`AppRadii.xLarge`) with horizontal margins, a subtle border, and an uppercase section title outside the card. _Avoid_: Full-width container, elevated Material card
- **Selection Bottom Sheet**: A modal bottom sheet displayed via `showAppModalBottomSheet` used to present choices in a vertical list with clear selected state. _Avoid_: Dropdown, DropdownButtonFormField
- **Status Capsule**: A pill-shaped badge (`AppRadii.full`) with a semantic tint background and bold text to indicate state (e.g. overweight, underweight, balanced). _Avoid_: Chip, raw colored text
- **Metric Grid**: A structured 2-column or 2x3 grid of rounded tiles showing related financial figures (e.g. target, current, diff). _Avoid_: Arbitrary Wrap, unaligned text column
- **Numeric Input Box**: A rounded container housing a right-aligned bold numeric input with an integrated unit/currency label and tap-outside dismiss behavior. _Avoid_: Default underlined TextField
