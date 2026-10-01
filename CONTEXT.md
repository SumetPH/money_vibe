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

## Accounts

- **Account**: A user-owned record for a financial balance or position, including assets, liabilities, and investment portfolios. _Avoid_: Wallet as a name for every account type
- **Account type**: The specific kind of Account that determines its financial behavior and destination when opened, such as cash, credit card, debt, or portfolio. _Avoid_: Account group
- **Account group**: A category that collects related Account types for browsing and financial summaries. _Avoid_: Account type
- **Portfolio account**: An Account whose value consists of cash and held investments; US and Thai portfolios are distinct types. _Avoid_: Holding
- **Credit-card account**: An Account representing a card liability and its statement cycles. _Avoid_: Credit-card bill
- **Hidden account**: An Account omitted from the ordinary Account List while retaining its other financial settings. _Avoid_: Excluded account
- **Excluded account**: An Account omitted from net-worth calculation while retaining its list visibility setting. _Avoid_: Hidden account

## Stock trading

- **Portfolio stock trade**: A completed purchase or sale of shares in a portfolio account that changes the held position and portfolio cash. _Avoid_: Standalone trade-history entry
- **Broker order detail image**: A broker's image of a completed stock order used to draft a portfolio stock trade. The image is evidence for data entry, not the portfolio stock trade itself.

## Cash-flow forecast

- **Liquid account**: A cash or bank Account whose balance counts as money available to pay obligations; the user may exclude individual ones, such as an emergency fund. _Avoid_: Wallet, spendable account
- **Statement balance**: The amount a credit-card account owes for a statement cycle that has already closed on its statement date.
- **Outstanding statement balance**: The part of a statement balance not yet paid within that statement's payment window.
- **Unbilled spending**: Credit-card spending after the latest statement date; it belongs to a future statement and is not an obligation until that statement closes.
- **Payment due date**: The date a credit-card statement must be paid, set per card as a day of the month and falling on the first such day after the statement date; when unset it is fifteen days after the statement date.
- **Fixed cash-flow item**: A user-listed, predetermined amount of money coming in or going out, either monthly on a given day of the month or once on a specific date, independent of any Account and of recurring transactions. Credit-card payments are never fixed cash-flow items. _Avoid_: Recurring transaction, fixed cost
- **Paid mark**: The user's confirmation that a fixed cash-flow item has happened for a specific calendar month; each month's occurrence is marked separately, and a one-time item is marked for the month of its date.
- **Clear day**: The day of the month the user settles everything, typically when salary arrives and debts are paid; shown in the app as "วันเคลียร์ยอด". It is not a card statement or payment due date. _Avoid_: วันตัดงวด, วันเงินเข้า, วันเริ่มงวด
- **Forecast window**: From the day after the previous clear day through the next clear day on or after today; the window moves on once the clear day has passed. Each monthly item falls in it once. Balances are taken as of today.
- **Projected leftover**: What is left after settling on the clear day: liquid account balances, plus unmarked incoming and minus unmarked outgoing fixed cash-flow items in the forecast window (earlier ones still count until ticked), minus what each credit card owes for statements closing before the clear day. For a closed statement that is its outstanding balance; for a statement that closes before the clear day but has not closed yet, the unbilled spending so far is used as an estimate. It also reserves remaining budgets and full savings targets for monthly financial cycles ending between today and the clear day, and deducts planned purchases selected for the current window.
- **Next forecast window**: From the day after the clear day through the following clear day.
- **Remaining budget**: For each visible expense Budget in the monthly financial cycle containing today, its amount minus actual spending so far, floored at zero; it stands for spending still expected this cycle. A budget belongs to the forecast window containing its cycle end date; future cycles reserve the full budget. Individual budgets and savings budgets may be excluded from each forecast window independently.
- **Planned purchase**: A user-listed thing the user wants to buy, with an amount and independent on/off selections for the current and next forecast windows; it is not tied to any Account or date. _Avoid_: Wishlist item, fixed cash-flow item
- **Projected next leftover**: The projected leftover, plus unmarked incoming and minus unmarked outgoing fixed cash-flow items in the next forecast window, minus unbilled spending so far on statements closing after the current clear day, minus budgets and full savings targets for monthly financial cycles ending in the next forecast window. It additionally deducts planned purchases selected for the next window; selecting a purchase in both windows reserves its amount twice. It carries forward the current forecast after its budget deductions; current-cycle budgets use the amount remaining as of today, while future cycles reserve their full amount.
