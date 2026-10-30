# Quickstart: Validate Reduced Auto Sync and Pull-to-Refresh

**Feature**: [spec.md](spec.md) | **Contracts**: [contracts/](contracts/) | **Data model**: [data-model.md](data-model.md)

## Prerequisites

- Flutter SDK matching the project, and a configured Supabase project (`docs/setup/SUPABASE_SETUP.md`).
- Two signed-in devices or emulators on the **same account**: Device A, the one under test, and Device B.
- Device A running in debug mode, so you can read its console output (`flutter run`).

## 1. Automated checks

```bash
dart format .
flutter analyze
flutter test test/sync_provider_test.dart
flutter test
bash tool/check_design.sh   # Git Bash on Windows
```

**Expected**: all of these pass. The new tests in `sync_provider_test.dart` cover self-write acknowledgement, foreign change before a write, side-effect reload, a failed write, an acknowledgement read failure, pull bypassing the cooldown and forcing modules, pull rethrowing errors, and reset.

## 2. Manual scenarios

Filter Device A's console for `[SyncProvider]`.

| # | Steps | Expected | Spec |
|---|-------|----------|------|
| 1 | On A, switch between all 4 main tabs and open/close several screens for over 1 minute without backgrounding | No `trigger=` log lines | FR-004, SC-001 |
| 2 | On A, add a transaction, then background and resume after 30 s or more | One `trigger=localWriteAck acknowledged=[transactions]` line after the save. On resume, `trigger=resume` with **no** `transactions` in `reloaded` | FR-001, SC-002 |
| 3 | On A, save a transfer into a portfolio account | The ack line shows `acknowledged=[transactions]` and `reloaded=[accounts]`. Portfolio cash is correct on A | FR-003 |
| 4 | On B, edit a budget. On A, background then resume | `trigger=resume reloaded=[budgets]`, and the change is visible on A | FR-002, FR-005, SC-003 |
| 5 | On B, add a transaction. On A, keep the app in the foreground and pull down on the Transactions list | Spinner shows and the new transaction appears. `trigger=pull` | FR-006–FR-008, SC-003/004 |
| 6 | On B, add a transaction. On A, without checking first, add a different transaction | A's ack does **not** list `transactions` as acknowledged. It reloads, and B's transaction appears | FR-002 (pre-write snapshot) |
| 7 | On A, pull twice within 5 s | Both pulls run (no cooldown). No overlapping refresh while the spinner is visible | FR-007, FR-009 |
| 8 | Put A in airplane mode and pull on the Accounts list | Spinner ends, the SnackBar `รีเฟรชข้อมูลไม่สำเร็จ ลองใหม่อีกครั้ง` appears, and the list is unchanged | FR-010, SC-005 |
| 9 | Pull on an empty Budgets list (new account or filtered period) | The pull gesture still works | Edge case |
| 10 | Sign out and sign in as another user | No reloads based on the previous user's baseline. Initial load runs | FR-014 |
| 11 | Restart A; Settings → Data Management import/reset | Full load works as before | FR-011 |
| 12 | Compare balances and totals on the main screens with values before the change | Identical | SC-006 |

## 3. Design check

- The pull indicator matches the theme accent in both light and dark mode, and looks native on iOS (Cupertino spinner) and Android.
- `docs/design.md` lists `AppRefreshIndicator` in the shared widgets table.
