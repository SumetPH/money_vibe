# Contract: `AppRefreshIndicator` (shared UI widget)

**File**: `lib/widgets/app_refresh_indicator.dart` | **Documented in**: `docs/design.md` → "Shared widgets และ tokens"

```dart
class AppRefreshIndicator extends StatelessWidget {
  const AppRefreshIndicator({
    super.key,
    required this.onRefresh,   // Future<void> Function()
    required this.child,       // a scrollable (or contains one) using AlwaysScrollableScrollPhysics
  });
}
```

## Behavior

- Wraps `RefreshIndicator.adaptive`. The indicator color is `AppColors.accentFor(isDarkMode, themeColor)` and the background is `AppColors.surfaceFor(isDarkMode)`, read from `SettingsProvider`.
- The spinner stays visible until the `onRefresh` future completes, whether it succeeds or fails.
- If `onRefresh` throws, the widget shows a SnackBar with `รีเฟรชข้อมูลไม่สำเร็จ ลองใหม่อีกครั้ง` through `ScaffoldMessenger`, completes normally, and leaves the shown data untouched. Screens therefore pass `SyncProvider.refresh` directly and need no try/catch.
- Screens MUST NOT use a raw `RefreshIndicator(` / `RefreshIndicator.adaptive(`. `tool/check_design.sh` enforces this with a new rule.

## Screen usage

| Screen | Wraps | `onRefresh` |
|--------|-------|-------------|
| `AccountListScreen` | The `CustomScrollView` (line ~161) | `sync.refresh(forceModules: {SyncModule.accounts})` |
| `TransactionListScreen` | The body `CustomScrollView` (line ~182) | `sync.refresh(forceModules: {SyncModule.transactions})` |
| `BudgetListScreen` | The list area containing the `ReorderableListView` variants | `sync.refresh(forceModules: {SyncModule.budgets})` |

Each wrapped scrollable gets `physics: const AlwaysScrollableScrollPhysics()` (or `.applyTo` its existing physics) so that empty or short lists can still be pulled.
