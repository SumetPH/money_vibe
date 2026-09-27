# Cash-flow forecast

Status: ready-for-agent

## Problem Statement

My credit cards close their statements on the 20th and my salary arrives on the 30th. I keep using the cards in between, so the card balances shown in the app move every day and I cannot tell whether the money I have — plus the salary on its way — will cover what I owe. What I owe is not only credit cards: there are fixed monthly payments such as the house and the car, and some of my income is not salary. I want one stable number that tells me whether I can cover everything until the next payday, and how much will be left.

## Solution

A **cash-flow forecast** card at the top of the "แผน" tab shows a single **projected leftover**, for example "ถึง 29 ต.ค. จะเหลือ +8,500". It combines:

- balances of **liquid accounts** (cash and bank accounts, minus any the user excludes),
- plus unmarked incoming **fixed cash-flow items**,
- minus unmarked outgoing fixed cash-flow items,
- minus **outstanding statement balances** of credit cards,

for everything falling due within the **forecast window**, which is anchored to the **payday item** and the existing **monthly financial cycle**. **Unbilled spending** is deliberately ignored so the number stays still between statement dates.

Tapping the card opens a detail screen that explains the number line by line, lets the user tick **paid marks** for each item per month, choose which liquid accounts count, and manage the fixed cash-flow item list. Each credit card gains an optional **payment due date** (day of month) so due dates line up with the real statement.

Vocabulary follows `CONTEXT.md` → "Cash-flow forecast". Rationale for a separate list rather than recurring transactions: `docs/adr/0004-fixed-cash-flow-items-separate-from-recurring.md`.

## User Stories

1. As a salaried user, I want to see one projected leftover number, so that I know at a glance whether I can cover my obligations until the next payday.
2. As a user, I want the forecast to show the date it covers up to, so that I understand which period the number refers to.
3. As a user, I want the projected leftover to appear with a clear positive or negative sign and colour, so that a shortfall is obvious.
4. As a user, I want the forecast card at the top of the "แผน" tab, so that I see it where I already plan my money.
5. As a user, I want to tap the forecast card to open a breakdown, so that I can verify where the number comes from.
6. As a user, I want the breakdown to list each liquid account balance, so that I can see what money I start with.
7. As a user, I want the breakdown to list each incoming item counted, so that I know which income is assumed.
8. As a user, I want the breakdown to list each outgoing item counted, so that I know which fixed costs are assumed.
9. As a user, I want the breakdown to list each credit card's outstanding statement balance with its payment due date, so that I know what I owe on each card and when.
10. As a user, I want to create a fixed cash-flow item with a name, amount, day of month, and direction (in/out), so that I can describe my fixed income and costs.
11. As a user, I want to edit and delete fixed cash-flow items, so that the list stays accurate when my payments change.
12. As a user, I want to enter an estimated amount for variable bills such as electricity, so that they still count in the forecast.
13. As a user, I want to designate exactly one incoming item as my payday item, so that the forecast knows when my salary arrives.
14. As a user, I want designating a new payday item to remove the designation from the previous one, so that there is never more than one payday item.
15. As a user, I want to tick a paid mark on an item for a specific month, so that money that already moved is not counted twice.
16. As a user, I want paid marks to be per calendar month, so that I never have to reset them and the same item can appear twice in one window without confusion.
17. As a user, I want to untick a paid mark, so that I can correct a mistake.
18. As a user, I want items dated before today that I have not ticked to still count and be labelled "ยังไม่ติ๊ก", so that I am reminded to tick them and the forecast stays cautious.
19. As a user, I want the forecast to exclude credit-card spending after the latest statement date, so that the number does not change every time I swipe a card.
20. As a user, I want cards whose next statement closes inside the window but has not closed yet to show as "ยังไม่สรุปยอด", so that I know the number will change when that statement closes.
21. As a user, I want a partly paid statement to count only its remaining amount, so that payments I already made are not double counted.
22. As a user, I want card payments made after a statement's due date to reduce that statement's outstanding balance in the forecast, so that paying late does not make the number wrongly low.
23. As a user, I want an outstanding statement balance past its due date to still count and be labelled "เลยกำหนด", so that I do not forget an overdue card.
24. As a user, I want credit-card payments never to be fixed cash-flow items, so that card obligations cannot be counted twice.
25. As a user, I want to exclude specific liquid accounts such as an emergency fund from the forecast, so that the number reflects only money I am willing to spend.
26. As a user, I want to choose included liquid accounts from the forecast detail screen, so that the setting sits next to where it has an effect.
27. As a user, I want my exclusions to persist across devices, so that the forecast is the same everywhere I sign in.
28. As a user, I want foreign-currency liquid accounts converted to THB, so that the forecast is a single currency.
29. As a user, I want the forecast before payday to include the upcoming salary and cover until the day before the following payday, so that I know whether this salary covers the month.
30. As a user, I want the forecast after payday (within the same monthly financial cycle) to keep covering until the day before the next payday, so that it tells me whether the salary I just received will last.
31. As a user, I want the forecast to move to the next pay period when a new monthly financial cycle starts, so that it follows my card statements closing.
32. As a user who has not designated a payday item, I want the card to invite me to set one, so that I understand why no number is shown.
33. As a user, I want to set a payment due day (day of month) on each credit card, so that forecasts and bills use my bank's real due date.
34. As a user who does not set a payment due day, I want the due date to remain fifteen days after the statement date, so that existing behaviour is preserved.
35. As a user, I want the credit-card bill screen to use the same payment due date, so that the bill and the forecast agree.
36. As a user, I want the forecast to refresh when I add transactions, tick marks, or edit items, so that it is always current.
37. As a user, I want items whose day does not exist in a month (e.g. 31) to fall on that month's last day, so that they still count every month.

## Implementation Decisions

**Domain rules (the core of the feature)**

- Liquid account = Account of type `cash` or `bankAccount`, not excluded from the forecast. Balance = the same THB balance the account list shows.
- Fixed cash-flow item occurrence: one per calendar month on `dayOfMonth`, clamped to the month's last day. Its paid mark is keyed by item + calendar month (`YYYY-MM`) of the occurrence date.
- Cycle payday: the payday item occurrence that falls within the current monthly financial cycle (existing monthly-cycle utility and `monthlyCycleStartDay` setting). If the cycle contains none, use the first payday occurrence after the cycle start.
- Forecast window: from the current monthly cycle's start date through the day before the payday occurrence that follows the cycle payday.
- Projected leftover = Σ liquid balances + Σ unmarked incoming occurrences in window − Σ unmarked outgoing occurrences in window − Σ outstanding statement balances whose payment due date ≤ window end (including overdue ones).
- Outstanding statement balance per card: take the **latest closed** bill only (earlier unpaid amounts are already carried into it by the bill service), then subtract payments that fall in the following open payment window up to today; floor at zero. A card with no closed bill contributes zero. If the latest closed bill is due after the window end, still count its overdue carried-over amount (carried over minus payments in its payment window), dated at the previous statement's due date.
- A card whose next (not yet closed) statement has its payment due date inside the window contributes zero and is flagged "ยังไม่สรุปยอด" (a statement closing inside the window but due after it does not affect this window).
- No payday item → no forecast; the result is an explicit "needs payday" state.

**Modules**

- **Cash-flow forecast calculator** (new, pure, deep module): a single entry point taking `today`, monthly cycle start day, accounts, transactions, fixed cash-flow items, paid marks, excluded account ids, and returning a forecast result: either "needs payday" or `{windowEnd, cyclePayday, projectedLeftover, liquid lines, item lines (with isOverdueUnmarked), card lines (outstanding, dueDate, isOverdue, isNotYetClosed)}`. No Flutter or Supabase dependencies. Reuses the credit-card bill service and account balance rules rather than re-deriving them.
- **Credit-card bill service** (modified): payment due date derived from the card's new optional `paymentDueDay` — the first date with that day of month (clamped) strictly after the statement date; `null` keeps statement + 15. Payment windows become "day after the previous due date → this due date" instead of the hard-coded +16/+15. Bill model comment updated accordingly.
- **Account model** (modified): add `paymentDueDay` (int?, 1–31, credit cards only) and `isExcludedFromCashForecast` (bool, default false). Account form gets a payment-due-day picker next to the statement-day picker, reusing the same day-picker pattern.
- **Fixed cash-flow item model** (new): `id, name, amount (>0), dayOfMonth (1–31), direction (incoming|outgoing), isPayday, sortOrder`. Validation: only incoming items may be payday.
- **Fixed cash-flow paid mark model** (new): `id, itemId, month (YYYY-MM)`; presence = paid. Prior art: investment-plan month status (`dca_month`).
- **DatabaseRepository / SupabaseRepository** (modified): CRUD for fixed cash-flow items; get/insert/delete paid marks; setting payday clears other payday flags. New Supabase adapter following existing adapters.
- **Cash-flow forecast provider** (new, `CashFlowForecastProvider`): loads items and marks, exposes the forecast by combining Account, Transaction and Settings providers, and exposes actions (add/edit/delete item, set payday, toggle mark, toggle account exclusion). Registered alongside existing providers and refreshed with sync.
- **UI** (new, following `docs/design.md` and shared widgets/tokens): forecast card at the top of the Budget list ("แผน") tab; forecast detail screen (breakdown, tick marks, liquid account checkboxes, entry to item list); fixed cash-flow item list + form. All texts in Thai.

**Schema (new migration + `supabase/init_schema.sql` include)**

- `accounts`: add `payment_due_day integer null check (1..31)`, `is_excluded_from_cash_forecast boolean not null default false`.
- `fixed_cash_flow_items`: `id text pk, user_id uuid fk auth.users cascade, name text not null, amount numeric(15,2) not null check > 0, day_of_month integer not null check 1..31, direction text not null check in ('incoming','outgoing'), is_payday boolean not null default false, sort_order integer not null default 0, created_at, updated_at`; partial unique index on `(user_id) where is_payday`; check `not is_payday or direction = 'incoming'`.
- `fixed_cash_flow_paid_marks`: `id text pk, user_id, item_id fk fixed_cash_flow_items cascade, month text check '^[0-9]{4}-[0-9]{2}$', created_at`; unique `(item_id, month)`.
- RLS "own rows only", `updated_at` trigger, and indexes, mirroring the investment-plan migration.
- Dates remain local time; months serialised as `YYYY-MM`.

## Testing Decisions

- Good tests exercise external behaviour only: given accounts, transactions, items, marks and a `today`, assert the forecast result — not private helpers.
- **Primary seam**: the cash-flow forecast calculator's single entry point. Scenarios: before/after payday within one cycle; rollover at cycle start; item appearing twice in one window; unmarked past item; paid mark excludes item; excluded liquid account; card with closed statement due in window; partly paid statement; payment after due date reducing outstanding; overdue statement; not-yet-closed statement contributing zero; no payday item; day 31 clamping; foreign-currency liquid account.
- **Secondary (existing) seam**: `CreditCardBillService.calculateBills` for the configurable payment due date and shifted payment windows, including the unchanged +15 default.
- Prior art: plain Dart unit tests under `test/` (e.g. recurring notification and reinstall reminder service tests) with injected `now`.
- Tests at both seams were written test-first because the user asked for `/implement` (which uses TDD).

## Out of Scope

- One-off dated items (bonus, annual insurance, tax).
- Projecting unbilled spending or average daily card usage.
- Using recurring transactions as a forecast source.
- Debt-account instalment modelling (house/car are plain outgoing items).
- Notifications about a projected shortfall.
- Multiple payday items or non-monthly pay schedules.
- A forecast timeline/graph of daily balances.

## Further Notes

- The monthly cycle start day is stored locally in settings, so the window depends on the device's setting; this matches budgets and statistics today.
- The monthly cycle start day (21) aligning with the statement day (20) is what makes the forecast roll over right after statements close; users with other combinations still get a correct, if less tidy, window.

## Revision 2026-09-27 (supersedes payday-item decisions above)

User feedback after first use:

- **Forecast anchor day replaces the payday item.** The user picks a day of month on the forecast detail screen ("วันตัดงวด"); it is stored locally in `SettingsProvider` like the monthly cycle start day and is independent of any item. User stories 13, 14 and 32 now read "set / have not set a forecast anchor day". Cycle payday → **cycle anchor date**: the first anchor day on or after the current monthly cycle's start; the window ends the day before the following anchor day. No anchor day → no forecast. `is_payday`, its unique index and check are dropped.
- **One-time items.** A fixed cash-flow item is either monthly (`day_of_month`) or one-time (`one_time_on`, a date), exactly one set (DB check). A one-time item counts once when its date is in the window; its paid mark uses its calendar month. The column is not named `*_date` because the row normalizer replaces null `*_date` values with the current time.
- **Liquid-account selection** moved into a bottom sheet opened from the forecast screen.
- **Item form matches the recurring form**: shared `AppSegmentedTabs` (direction, schedule), `AppAmountHeroCard` with `CalculatorKeyboard` via `CalculatorKeyboardHost`, and `AppFormRow`; the recurring form now uses the same shared widgets. Text inputs in rows are right-aligned (including hints).
- **Performance**: credit-card bill calculation sorts card transactions once and slices each cycle by binary search (forecast ~376 ms → ~14 ms on 20k transactions); output verified identical to the previous implementation.
- **Entry point moved**: the forecast is no longer a card on the "แผน" (budget) tab. It is its own screen at route `/cash-flow`, listed under the "วางแผน" section of the drawer (after รายการประจำ) and in the wide-screen sidebar, with a main-tab style header and drawer like the recurring list. The review-warning chip moved into the summary hero.

## Revision 2026-09-27: next forecast window

User request: see the following period too, counting budgets, card spending so far, and things they want to buy.

- A second hero, "งวดถัดไป", sits under the current summary and shows the **projected next leftover** (definition in `CONTEXT.md`). The current projected leftover is unchanged.
- Budgets count as **remaining budget** of the current monthly cycle (expense budgets that are not hidden), not the next cycle's full budget.
- Cards count closed statements due in the next window that the current window did not count, plus **unbilled spending** as of today when the open statement is due by the next window's end. Payments after the latest due date first settle the latest statement, and anything beyond that reduces the unbilled amount. Future card spending is not projected; the remaining budget covers it.
- **Planned purchases** are a new list (`planned_purchases` table, `cash_flow` sync module) with name, amount and an include switch, managed from the forecast screen.
- Out of scope: instalments, the next cycle's full budget, per-budget include switches, and projecting future card spending.

## Revision 2026-09-28: pay periods follow the money-in day only

User feedback: with a monthly cycle starting on the 1st and money arriving on the 30th, the window ran 1 Sep – 29 Oct, so an item "every 15th" appeared as both 15 Sep and 15 Oct and felt wrong.

- Each forecast window is one pay period: from the latest money-in day (forecast anchor day) on or before today to the day before the next one. The monthly financial cycle no longer shapes it; it is used only for the remaining budget. "Cycle anchor date" is removed.
- The next window is the following pay period.
- The next period counts every card amount the current window did not: closed statements due later and all unbilled spending as of today, even when due after the next window. Each card row shows the due date of each part.
- Budgets and savings plans can be excluded from the next period individually (`budgets.is_excluded_from_cash_forecast`), like liquid accounts.

## Revision 2026-09-28 (b): the current tab shows the upcoming pay period

The pure "period containing today" rule made the current tab show a nearly finished period before payday, while the user wants to see whether the upcoming start day's money covers everything.

- The current window is still exactly one pay period, but it is the one starting at the first anchor day on or after the current monthly cycle start. It rolls to the next pay period when a new monthly cycle starts; with statements closing on the 21st and money on the 30th, the cycle start day should be 22.
- Before the period starts, items from today up to the start count and are shown in a separate "ก่อนเริ่มงวด" group; older unticked items are ignored.
- The UI label for the anchor day is "วันเริ่มงวด".

## Revision 2026-09-28 (c): forecast periods are the monthly cycle

To keep a single setting, the forecast anchor day ("วันเริ่มงวด") is removed. Each forecast window is the monthly financial cycle containing today (the setting shared with budgets and statistics); the next window is the following cycle. With statements closing on the 21st, a cycle start of 22 lines budgets, card statements and forecast periods up. The forecast screen offers the cycle start day row for convenience; it edits the same setting. Items dated earlier in the cycle and not ticked still count and are flagged.
