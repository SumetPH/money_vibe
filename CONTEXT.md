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
- **Forecast window**: The monthly financial cycle containing today, the same period budgets and statistics use; each monthly item falls in it once. The cycle start day is best set to the day after card statements close. Balances are taken as of today.
- **Projected leftover**: Liquid account balances, plus unmarked incoming fixed cash-flow items, minus unmarked outgoing fixed cash-flow items and outstanding statement balances, all falling due within the forecast window; unmarked items and outstanding statement balances already past their date still count. A statement not yet closed contributes nothing.
- **Next forecast window**: The monthly financial cycle after the forecast window.
- **Remaining budget**: For each visible expense Budget in the monthly financial cycle containing today, its amount minus actual spending so far, floored at zero; it stands for spending still expected this cycle. The user may exclude individual budgets and savings budgets from the next-period forecast, like liquid accounts; the choice is stored on the Budget.
- **Planned purchase**: A user-listed thing the user wants to buy, with an amount and an on/off switch, used to see its effect on the next forecast window; it is not tied to any Account or date. _Avoid_: Wishlist item, fixed cash-flow item
- **Projected next leftover**: The projected leftover, plus unmarked incoming and minus unmarked outgoing fixed cash-flow items in the next forecast window, minus every credit-card amount the current window did not count (closed statements due later plus unbilled spending as of today, even when due after the next window), minus the remaining budget, the full amount of each visible savings Budget (savings are not tracked, so its whole target is set aside from the next period's money), and switched-on planned purchases. Unbilled spending and remaining budget do not overlap because spending already made reduces the remaining budget.
