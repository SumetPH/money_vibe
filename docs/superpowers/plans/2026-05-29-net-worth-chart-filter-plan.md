# Net Worth Chart Filter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a period filter dropdown to the Net Worth Trend chart on the Statistics screen so users can view 1 month, 3 months, 6 months, 1 year, this year, or all historical data.

**Architecture:** Filter is applied client-side by slicing the already-computed monthly `_NetWorthData` list. State lives inside `_NetWorthLineChartState` via `setState`. No backend or provider changes.

**Tech Stack:** Flutter, `fl_chart`, Dart

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `lib/screens/statistics/statistics_screen.dart` | Modify | Add enum, filter state, helper, dropdown UI, and wire into chart. |

---

## Tasks

### Task 1: Define `_NetWorthPeriodFilter` enum

**Files:**
- Modify: `lib/screens/statistics/statistics_screen.dart`

- [ ] **Step 1: Add the enum inside `statistics_screen.dart` after the `_NetWorthData` class (or near `_NetWorthLineChart`)**

```dart
enum _NetWorthPeriodFilter {
  oneMonth('1 เดือนล่าสุด'),
  threeMonths('3 เดือนล่าสุด'),
  sixMonths('6 เดือนล่าสุด'),
  oneYear('1 ปีล่าสุด'),
  thisYear('ปีนี้'),
  all('ทั้งหมด');

  final String label;
  const _NetWorthPeriodFilter(this.label);
}
```

- [ ] **Step 2: Verify no analysis errors**

Run: `flutter analyze lib/screens/statistics/statistics_screen.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/screens/statistics/statistics_screen.dart
git commit -m "feat: add NetWorthPeriodFilter enum"
```

---

### Task 2: Add filter state and helper to `_NetWorthLineChartState`

**Files:**
- Modify: `lib/screens/statistics/statistics_screen.dart`

- [ ] **Step 1: Add `_selectedFilter` field inside `_NetWorthLineChartState`**

Inside `class _NetWorthLineChartState extends State<_NetWorthLineChart>` add:

```dart
_NetWorthPeriodFilter _selectedFilter = _NetWorthPeriodFilter.all;
```

- [ ] **Step 2: Add `_filterNetWorthData` helper method inside `_NetWorthLineChartState`**

```dart
List<_NetWorthData> _filterNetWorthData(
  List<_NetWorthData> data,
  _NetWorthPeriodFilter filter,
) {
  if (data.isEmpty || filter == _NetWorthPeriodFilter.all) return data;

  final now = DateTime.now();
  DateTime cutoff;

  switch (filter) {
    case _NetWorthPeriodFilter.oneMonth:
      cutoff = DateTime(now.year, now.month - 1, now.day);
      break;
    case _NetWorthPeriodFilter.threeMonths:
      cutoff = DateTime(now.year, now.month - 3, now.day);
      break;
    case _NetWorthPeriodFilter.sixMonths:
      cutoff = DateTime(now.year, now.month - 6, now.day);
      break;
    case _NetWorthPeriodFilter.oneYear:
      cutoff = DateTime(now.year - 1, now.month, now.day);
      break;
    case _NetWorthPeriodFilter.thisYear:
      cutoff = DateTime(now.year, 1, 1);
      break;
    case _NetWorthPeriodFilter.all:
      return data;
  }

  return data.where((d) => d.date.isAfter(cutoff) || d.date.isAtSameMomentAs(cutoff)).toList();
}
```

- [ ] **Step 3: Verify no analysis errors**

Run: `flutter analyze lib/screens/statistics/statistics_screen.dart`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add lib/screens/statistics/statistics_screen.dart
git commit -m "feat: add net worth filter state and helper"
```

---

### Task 3: Wire filtered data into the chart

**Files:**
- Modify: `lib/screens/statistics/statistics_screen.dart`

- [ ] **Step 1: Locate the line where `netWorthData` is first computed in `_NetWorthLineChartState.build`**

The existing code is:
```dart
final netWorthData = _calculateNetWorth(
  txProvider.transactions,
  accountProvider.visibleAccounts,
  accountProvider,
  includeExcluded: _includeExcluded,
);
```

- [ ] **Step 2: Immediately after that line, add the filter call**

```dart
final filteredNetWorthData = _filterNetWorthData(netWorthData, _selectedFilter);
```

- [ ] **Step 3: Replace all references from `netWorthData` to `filteredNetWorthData` inside the chart widget** (the chart `Container` starting around line 1368). Specifically:

   - In the subtitle Text: `'ตั้งแต่ ${_formatDate(filteredNetWorthData.first.date)} - ${_formatDate(filteredNetWorthData.last.date)}'`
   - In `LineChartData` parameters that use `netWorthData` (e.g., `horizontalInterval`, `bottomInterval`, `Spots`, `minX`, `maxX`): change to `filteredNetWorthData`

- [ ] **Step 4: Keep Summary Card using the original `netWorthData`** — the summary card (current net worth, change, change %) must **not** change.

- [ ] **Step 5: Verify no analysis errors**

Run: `flutter analyze lib/screens/statistics/statistics_screen.dart`
Expected: No errors

- [ ] **Step 6: Commit**

```bash
git add lib/screens/statistics/statistics_screen.dart
git commit -m "feat: wire filtered net worth data into chart"
```

---

### Task 4: Add Dropdown UI inside the chart card header

**Files:**
- Modify: `lib/screens/statistics/statistics_screen.dart`

- [ ] **Step 1: Locate the chart header inside the chart `Container`**

Around line 1384 there is:
```dart
Text(
  'แนวโน้มทรัพย์สินสุทธิ',
  style: TextStyle(...),
),
```

- [ ] **Step 2: Wrap the title and subtitle in a `Row` with `mainAxisAlignment: MainAxisAlignment.spaceBetween` and add the dropdown**

Replace the existing `Column` header (Text "แนวโน้มทรัพย์สินสุทธิ" + subtitle Text) with:

```dart
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'แนวโน้มทรัพย์สินสุทธิ',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            filteredNetWorthData.isEmpty
                ? ''
                : 'ตั้งแต่ ${_formatDate(filteredNetWorthData.first.date)} - ${_formatDate(filteredNetWorthData.last.date)}',
            style: TextStyle(fontSize: 12, color: secondaryTextColor),
          ),
        ],
      ),
    ),
    DropdownButtonHideUnderline(
      child: DropdownButton<_NetWorthPeriodFilter>(
        value: _selectedFilter,
        icon: Icon(Icons.keyboard_arrow_down, color: secondaryTextColor, size: 18),
        style: TextStyle(fontSize: 13, color: textColor),
        dropdownColor: isDarkMode ? AppColors.darkSurface : Colors.white,
        items: _NetWorthPeriodFilter.values.map((f) {
          return DropdownMenuItem<_NetWorthPeriodFilter>(
            value: f,
            child: Text(f.label, style: TextStyle(fontSize: 13, color: textColor)),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() => _selectedFilter = value);
          }
        },
      ),
    ),
  ],
),
```

- [ ] **Step 3: Verify no analysis errors**

Run: `flutter analyze lib/screens/statistics/statistics_screen.dart`
Expected: No errors

- [ ] **Step 4: Format code**

Run: `dart format lib/screens/statistics/statistics_screen.dart`

- [ ] **Step 5: Commit**

```bash
git add lib/screens/statistics/statistics_screen.dart
git commit -m "feat: add period filter dropdown to net worth chart"
```

---

### Task 5: Edge-case handling and final verification

**Files:**
- Modify: `lib/screens/statistics/statistics_screen.dart`

- [ ] **Step 1: Ensure empty-state guard still works with filtered data**

The existing empty-state check uses `netWorthData.isEmpty`. Since filtering only *reduces* data, if the original list is non-empty but the filtered list is empty, the chart body will attempt to access `filteredNetWorthData.first/last`.

Locate the `if (filteredNetWorthData.isEmpty)` check inside the chart `Container` (around where `LineChart` is built). If it does not already exist, add one before building the chart:

```dart
if (filteredNetWorthData.isEmpty) {
  return Expanded(
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.show_chart, size: 48, color: secondaryTextColor),
          const SizedBox(height: 8),
          Text(
            'ยังไม่มีข้อมูลในช่วงเวลาที่เลือก',
            style: TextStyle(fontSize: 14, color: secondaryTextColor),
          ),
        ],
      ),
    ),
  );
}
```

- [ ] **Step 2: Run full analysis and format**

```bash
flutter analyze
dart format .
```

Expected: `flutter analyze` returns zero issues.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/statistics/statistics_screen.dart
git commit -m "fix: handle empty filtered net worth chart state"
```

---

## Self-Review

**Spec coverage:**
- ✅ Filter options (1, 3, 6 months, 1 year, this year, all) — Task 1 + 2
- ✅ Filter logic applied after full calculation — Task 2
- ✅ Summary Card stays unfiltered — Task 3 explicitly keeps original `netWorthData`
- ✅ Dropdown UI in chart header — Task 4
- ✅ Dark mode support — Task 4 uses `isDarkMode`, `textColor`, `secondaryTextColor`, `AppColors.darkSurface`
- ✅ Edge cases (empty filtered list) — Task 5
- ✅ Local widget state (`setState`) — Task 2

**Placeholder scan:**
- No TBD/TODO/fill-in details found.

**Type consistency:**
- `_NetWorthPeriodFilter` used consistently across Tasks 1–4.
- `_filterNetWorthData` signature matches usage in Task 3.

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-05-29-net-worth-chart-filter-plan.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
