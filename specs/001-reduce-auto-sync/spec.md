# Feature Specification: Reduce Automatic Sync and Add Pull-to-Refresh

**Feature Branch**: `speckit` (no dedicated feature branch created)

**Created**: 2026-10-30

**Status**: Draft

**Input**: Handoff from assessment `.specify/assessments/pull-to-refresh/decision.md` (verdict: go, Option B Hybrid). Original idea: "อยากจะเปลี่ยน auto reload data เป็นการใช้ pull refresh" ("I want to change the automatic data reload to pull-to-refresh"). Owner confirmed multi-device use and that keeping sync on app resume is acceptable.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - No redundant re-downloads after my own changes (Priority: P1)

When a user adds, edits, or deletes data (a transaction, account, budget, category, recurring item, or portfolio entry) on their device, the app already shows the result. The app must not download that same data again later just because the user changed it.

**Why this priority**: The assessment identified this as the most likely source of unnecessary backend requests. Fixing it reduces load without changing what users see or do.

**Independent Test**: Make a change on one device, then trigger a sync check by resuming the app after the cooldown. Verify that the changed area is not re-downloaded and that the screen still shows the correct data.

**Acceptance Scenarios**:

1. **Given** a signed-in user on device A, **When** they save a new transaction and later resume the app, **Then** the app does not re-download transactions because of that save, and the transaction is still shown correctly.
2. **Given** a signed-in user on device A, **When** they save a change that also updates related data on the server (for example, a transfer that adjusts portfolio cash), **Then** the related data on device A is up to date, either already reflected or refreshed once, and never left stale.
3. **Given** the user made a change on device B, **When** device A next checks for updates, **Then** device A still detects and downloads that change.

---

### User Story 2 - Fewer background checks while navigating (Priority: P1)

While a user moves between screens and tabs, the app no longer checks the server for updates on every navigation. The app checks automatically only when it returns to the foreground.

**Why this priority**: Navigation is the most frequent trigger of background checks. Removing it cuts most automatic traffic. Keeping the foreground check preserves freshness for a user who switches between devices, which the owner confirmed.

**Independent Test**: Navigate repeatedly between tabs and screens with no app backgrounding and confirm that no update checks occur. Background and resume the app and confirm that exactly one check occurs, subject to the existing cooldown.

**Acceptance Scenarios**:

1. **Given** a signed-in user on the main tabs, **When** they switch tabs or open and close screens, **Then** no automatic update check is triggered.
2. **Given** the user edited data on device B, **When** they bring the app on device A back to the foreground, **Then** device A checks for updates and shows device B's changes without further action.
3. **Given** the app was resumed less than the cooldown period ago, **When** it is resumed again, **Then** no additional automatic check runs.

---

### User Story 3 - Pull down to refresh on main lists (Priority: P2)

On the main list screens, a user can pull down from the top of the list to fetch the latest data on demand, for example after making a change on another device while this app stayed open in the foreground.

**Why this priority**: This gives users explicit control, which was the original request. It also replaces the freshness that navigation-triggered checks used to provide, but it is secondary to reducing waste.

**Independent Test**: On each supported screen, change data from another device, pull down on the list, and verify that the new data appears and that a refresh indicator is shown and then dismissed.

**Acceptance Scenarios**:

1. **Given** the Accounts list is open and data changed on another device, **When** the user pulls down on the list, **Then** a refresh indicator appears, the latest data loads, and the indicator disappears.
2. **Given** a sync check ran a few seconds ago, which is within the cooldown, **When** the user pulls to refresh, **Then** the refresh still runs, because a manual refresh is never blocked by the cooldown.
3. **Given** the device is offline, **When** the user pulls to refresh, **Then** the indicator disappears, a short error message tells the user the refresh failed, and the currently shown data remains visible and unchanged.
4. **Given** a refresh is already in progress, **When** the user pulls again, **Then** no second, parallel refresh starts.

---

### Edge Cases

- **App restored after a long time in the background**: the resume check runs as normal (cooldown elapsed).
- **Pull-to-refresh during the initial data load after login**: waits for or joins the in-progress load rather than starting a separate one.
- **Lists that are empty or shorter than the screen**: pull-to-refresh still works.
- **Signing out and signing in as a different user**: no change-tracking state from the previous user carries over.
- **A change made on this device fails to save**: the device must not treat any server change as "already known" because of the failed save.
- **Two devices change the same area at almost the same time**: the other device's change must still be detected on the next check or pull.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The app MUST NOT re-download a data area solely because of changes this device itself saved successfully, when those changes are already reflected on this device.
- **FR-002**: The app MUST still detect and download changes to a data area made from another device or session, including when this device also changed the same area recently.
- **FR-003**: When a change saved on this device causes the server to update a related data area that this device does not already show correctly (for example, portfolio cash after a transfer), the app MUST bring that related area up to date.
- **FR-004**: The app MUST NOT run an automatic update check when the user switches main tabs or navigates between screens.
- **FR-005**: The app MUST run an automatic update check when it returns to the foreground while signed in, subject to the existing cooldown between automatic checks.
- **FR-006**: The Accounts list, Transactions list, and Budgets list screens MUST support pull-to-refresh. The Portfolio detail screen SHOULD support it where its layout allows.
- **FR-007**: A pull-to-refresh MUST fetch the latest data regardless of the automatic-check cooldown.
- **FR-008**: A pull-to-refresh MUST bring the data shown on the current screen up to date, and SHOULD also update any other data areas detected as changed during the same refresh.
- **FR-009**: While a refresh is in progress, the app MUST show a visible refresh indicator and MUST NOT start a duplicate concurrent refresh.
- **FR-010**: If a pull-to-refresh fails (for example, offline or a server error), the app MUST keep the currently displayed data and show a brief, non-blocking error message.
- **FR-011**: The full data load at app start and sign-in, and the reload after data import or reset, MUST continue to work as they do today.
- **FR-012**: The pull-to-refresh interaction MUST follow the project's design system and be documented there as a reusable pattern.
- **FR-013**: The app MUST record diagnostic (debug) information whenever an update check or data-area reload happens, including what triggered it (resume, pull, or initial load), so request reduction can be observed.
- **FR-014**: Signing out or switching users MUST clear all change-tracking state, so the next user starts from a fresh baseline.

### Key Entities

- **Data area (module)**: One of the synchronized groups of user data: accounts, portfolio, categories, transactions, budgets, recurring items, and cash-flow forecast. Each has a server-side "last changed" time.
- **Known-changes baseline**: This device's record of the latest change time it already reflects for each data area. It is used to decide whether a server change is new to this device.
- **Refresh trigger**: The reason an update check runs: initial load, app resume, or user pull-to-refresh. Navigation is no longer a trigger.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In a session where the user only navigates between screens and tabs, without backgrounding the app, zero automatic update checks occur. Previously this could reach up to about 120 per hour of active use.
- **SC-002**: After saving a change on one device and resuming the app, 0 re-downloads of the changed data area are caused by that save alone, measured over 10 representative save actions across different data areas.
- **SC-003**: A change made on device B appears on device A within one resume or one pull-to-refresh, in 100% of test cases.
- **SC-004**: A pull-to-refresh on a supported screen completes and shows the latest data within 3 seconds on a normal mobile connection.
- **SC-005**: When offline, 100% of pull-to-refresh attempts end with the existing data still shown and an error message displayed, with no blank or broken screen.
- **SC-006**: No regression in totals, balances, or calculations shown on any screen after the change, verified by the existing automated tests passing and a manual spot check of the main screens.

## Assumptions

- The existing automatic-check cooldown (currently 30 seconds) is kept for resume-triggered checks. Only pull-to-refresh bypasses it.
- Pull-to-refresh scope is a default chosen to avoid an extra clarification round. A pull always refreshes the current screen's data and also applies any other changes detected in the same check.
- Pull-to-refresh is limited to the main list screens. Forms, Statistics, Settings, and other non-list screens are out of scope.
- The server-side change-tracking mechanism (per-area "last changed" times maintained by the backend) stays as it is. No schema change is expected.
- Realtime push updates, offline caching, and a "last updated" stale-data indicator are out of scope.
- The user is signed in for all sync behavior. Signed-out states are unaffected.
- Error messages reuse the app's existing notification style and Thai-language UI conventions.
- No Supabase usage baseline exists. Request reduction is verified through the diagnostic information in FR-013 rather than billing data.
