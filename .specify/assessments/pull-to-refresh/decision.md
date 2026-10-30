# Decision: Fewer background refreshes, plus refresh on demand

- **Slug**: pull-to-refresh
- **Decided**: 2026-10-30
- **Verdict**: go
- **Artifacts reviewed**: intake.md, research.md, problem.md, concept.md, plus owner answers at decision time

## Owner Input at Decision Time

- **Multi-device use**: yes. The owner uses Money Vibe on more than one device, so automatic freshness on resume matters. This resolves the open question in problem.md.
- **Keep resume-triggered sync**: acceptable. The owner explicitly chose Option B, which resolves the open question about keeping automatic refresh.

## Scorecard

| Criterion | Rating | Justification |
|-----------|--------|---------------|
| Problem validity | adequate | Code evidence shows real request waste. Route and tab triggers fire on almost every navigation, and the device's own writes cause redundant reloads. The absolute backend cost is unmeasured and likely modest for a single-user app. |
| Evidence strength | adequate | The causes are concrete and cited from code (`sync_provider.dart`, `main.dart`, `main_tab_screen.dart`, migrations). Multi-device use is now confirmed by the owner. There are still no runtime request counts, so baselines are unknown. |
| Value vs. inaction | adequate | Inaction keeps the redundant reloads and leaves no explicit refresh control. The value is efficiency plus a UX improvement, not an urgent fix. |
| Feasibility / appetite | strong | Option B is small to medium (about 1–2 weeks). It reuses the existing `SyncProvider` and sync-log infrastructure and needs no schema change. |
| Strategic fit | strong | Fits the constitution: Supabase-only (I), Provider/repository architecture (III), and design-system compliance (IV), with pull-to-refresh documented in `docs/design.md`. No business logic change. |
| Risk posture | adequate | Risks are identified: attributing server-side side effects such as transfers that touch portfolio cash, nested-scroll conflicts on list screens, and gesture discoverability. Keeping the resume sync mitigates the main freshness risk. The self-write attribution approach still needs careful spec work. |

## Verdict & Rationale

**Go with Option B (Hybrid).** The problem is real and supported by concrete code evidence. The owner has confirmed the two facts that decide between the options: they use more than one device, and keeping sync on resume is acceptable. Together these rule out Option C, because pure pull-to-refresh would show stale balances across devices. They also favor B over A, because the owner wants on-demand control.

The appetite is small and fits existing architecture and constitution principles. The main weakness is that no baseline metrics exist, so the request-reduction goal is unquantified. This does not block specification, but the spec should include a way to observe the result, such as debug logging of sync checks and reloads.

## If go: Handoff to `/speckit-specify`

- **Problem**: The app re-fetches Supabase data automatically on resume, every route change, and every tab switch, and it re-fetches modules the user just changed on the same device. This creates unnecessary backend requests. Users across multiple devices must still see current balances.
- **Chosen approach (Option B, Hybrid)**:
  1. Stop reloading modules whose `sync_logs` change came from this device's own writes. Treat those writes as already known.
  2. Remove the automatic `checkAndSync` triggers on route changes and tab switches. Keep the trigger on app resume.
  3. Add pull-to-refresh to the main list screens (accounts, transactions, budgets, and portfolio detail if it fits). Pulling bypasses the cooldown and refreshes the latest data.
  4. Document the pull-to-refresh pattern or shared widget in `docs/design.md`.
- **In scope**: the three changes above to sync triggers, self-write handling, and list-screen pull-to-refresh; updates to `test/sync_provider_test.dart`.
- **Out of scope**:
  - The full load at startup or login, and the reload after import or reset.
  - Offline support or a local cache.
  - Realtime subscriptions.
  - Changes to the `sync_logs` table or its triggers.
  - Pull-to-refresh on forms, Statistics, or Settings.
  - Stale-data indicators in the UI.
  - Changes to calculations, validation, or schema.
- **Success metrics**:
  - Fewer `checkAndSync` calls per session, with route and tab triggers removed.
  - Near-zero reloads triggered only by the device's own writes.
  - Pull-to-refresh fetches the latest data on demand.
  - A change made on device A appears on device B after resume or a pull.
  - Baselines are unknown and should be observed through logging.
- **Carried-forward open questions**:
  - How to reliably attribute `sync_logs` bumps to this device's own writes, including trigger side effects that touch other modules (for example, transfers updating portfolio cash, and recurring occurrences).
  - Whether a pull refreshes only the current screen's module (forced) or runs the global changed-only check.
  - Which list screens can host pull-to-refresh without conflicting with nested scrolls or slivers.
  - What loading and error feedback to show when a pull fails offline.
  - Whether Supabase usage numbers are available to set a quantitative baseline.
