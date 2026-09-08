# Money Vibe Context

## Glossary

- **Recurring transaction**: A saved schedule that produces dated occurrences.
- **Occurrence**: One dated instance of a recurring transaction, with a pending, completed, or skipped state.
- **Current-month occurrence**: An occurrence dated in the calendar month containing the user's local current date. It remains in the current-and-upcoming view for that whole month.
- **Past occurrence**: An occurrence dated before the first day of the user's local current month.
- **Current net worth**: The combined value of included assets and liabilities at the user's current local time; it is the single value shown when all reporting periods are selected, with a zero baseline.
- **Period net worth**: The opening and closing net-worth values represented by the first and last visible points in the selected reporting period.
- **Net worth change**: The difference and percentage change between the first and last net-worth points visible in the selected reporting period.

## Reinstall reminders

- **Reinstall deadline**: The local-time instant five days after the first app launch following each installation, including reinstalling the same or an older version. _Avoid_: expiry date, install date
- **Reinstall reminder**: A one-time local notification issued when a reinstall deadline is reached. _Avoid_: expiry notification
- **Reinstall reminder setting**: The user preference that permits the reinstall reminder without hiding the reinstall deadline or its in-app status. _Avoid_: expiry setting
- **Installation status**: The in-app representation of the time remaining until, or passage of, a reinstall deadline. _Avoid_: expiration status
