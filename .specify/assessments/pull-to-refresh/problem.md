# Problem Definition: Unnecessary background data refreshes load the backend

- **Slug**: pull-to-refresh
- **Created**: 2026-10-30
- **Inputs used**: intake.md, research.md

## Problem Statement

While someone uses Money Vibe, the app re-fetches data from Supabase by itself. It does this on resume, on every route change and on every tab switch, and it re-fetches modules the user just changed on the same device. That creates backend requests the owner considers unnecessary. Data freshness still matters in a finance app, so any reduction must not leave users looking at stale balances without knowing it.

The original request ("replace auto reload with pull-to-refresh") is one candidate answer to this problem. It is not the problem itself.

## Affected Users & Stakeholders

- **Users**
  - **App user (currently the owner, single-user personal finance)**: has no visible control over when data refreshes. They depend on automatic checks to see up-to-date balances and transactions, including changes made on another device. — [research: Users & Demand; multi-device use is NEEDS CLARIFICATION]
- **Stakeholders**
  - **Project owner / developer (SumetPH)**: pays for and operates the Supabase backend, wants fewer requests, and maintains the sync system. They have already revised it several times, so redesigning it costs maintenance effort. — [intake: trigger; research: Prior Art]

## Goals

- Reduce backend requests that do not deliver new information to the user. This includes re-fetching data the app already has, such as changes the user just made on the same device. — [research: self-write redundant reload]
- Keep users confident that the balances and transactions on screen are current, or make it clear when they might not be. — [research: Evidence Against, freshness risk]
- Let users get the latest data on demand when they suspect it is stale. — [intake: the stated desire for user-initiated refresh]

## Non-Goals

- Changing the full data load at app start or login, or the reload after import/reset in Data Management. These are separate flows from the "auto reload" being discussed. — [research: Prior Art]
- Adding offline support or a local cache. AGENTS.md forbids SQLite, and Supabase stays the only data source. — [research: Data & Constraints]
- Real-time push or live collaboration features.
- Changing business logic, calculations, or the data schema of financial modules.

## Success Metrics

- **Supabase requests per active session**: target a measurable reduction. (baseline: unknown, [NEEDS CLARIFICATION: needs instrumentation or Supabase logs])
- **Redundant module reloads**: reloads triggered only by the device's own writes. Target near zero. (baseline: unknown; the code suggests it happens after most writes, once the 30 s cooldown has passed)
- **`sync_logs` checks per hour of active use**: (baseline: up to ~120/h at the 30 s cooldown, theoretical upper bound)
- **Freshness, qualitative**: the user does not report seeing stale balances after editing on another device. (baseline: no reports today, but there is no feedback channel)

## Cost of Inaction

- Background traffic stays at its current level. That is one small `sync_logs` query per ≤30 s of active navigation, plus module reloads when data changed, including redundant reloads of the user's own writes. — [research: Data & Constraints]
- The research suggests the absolute cost is probably low for a single-user app, but no usage or billing data confirms it. — [research: Gaps]
- Users still cannot force a refresh explicitly. Today they have to switch tabs or routes, or background the app, and wait out the cooldown. — [research: Market & Context]

## Open Questions

- [NEEDS CLARIFICATION: What are the actual Supabase request counts or costs per session, and which requests dominate: `sync_logs` checks or module table reloads?]
- [NEEDS CLARIFICATION: How often do redundant self-write reloads fire in a normal session?]
- [NEEDS CLARIFICATION: Does the owner, or any user, use the app on more than one device or share an account? This decides how much automatic freshness matters.]
- [NEEDS CLARIFICATION: Is any automatic refresh acceptable to keep (e.g. on app resume), or must all refreshes be user-initiated?]
- [NEEDS CLARIFICATION: Which screens does the user expect to be able to refresh manually?]
- [NEEDS CLARIFICATION: Is there a concrete backend limit or cost threshold (Supabase plan quota) motivating this, or is it general efficiency?]
