# Net Worth Chart Filter — Design Spec

**Date:** 2026-05-29  
**Status:** Approved  
**Scope:** Add period filter dropdown to the Net Worth Trend chart on the Statistics screen.

---

## 1. Objective

Allow users to filter the Net Worth Trend line chart by predefined time periods so they can focus on recent performance without being overwhelmed by the full history.

---

## 2. Filter Options

| Label (TH) | Logic |
|---|---|
| 1 เดือนล่าสุด | `date >= now - 1 month` |
| 3 เดือนล่าสุด | `date >= now - 3 months` |
| 6 เดือนล่าสุด | `date >= now - 6 months` |
| 1 ปีล่าสุด | `date >= now - 12 months` |
| ปีนี้ | `date >= Jan 1 of current year` |
| ทั้งหมด | No filtering (default) |

**Default:** ทั้งหมด (matches current behavior)

---

## 3. Data Flow

1. `_calculateNetWorth()` computes the full `List<_NetWorthData>` (monthly aggregation) exactly as it does today.
2. After the full list is computed, a new `_filterNetWorthData()` helper slices the list based on the selected filter.
3. The filtered list is passed to the `LineChart` widget.
4. The **Summary Card** (current net worth, change, change %) continues to use the **full unfiltered data** because it represents the user's current financial snapshot, not a historical range.

---

## 4. UI/UX

### 4.1 Placement
- Inside the Net Worth Trend card header, aligned to the **right** of the title "แนวโน้มทรัพย์สินสุทธิ".
- Uses a compact `DropdownButton` or `DropdownButtonFormField`.
- Prefix icon: `Icons.calendar_today` or `Icons.filter_list`.

### 4.2 Styling
- Label color: `secondaryTextColor` (respects dark mode).
- Dropdown background: transparent or subtle.
- Follows existing `AppColors` palette and dark-mode conventions.

### 4.3 Interactions
- Selecting a new filter immediately re-renders the chart (synchronous, no loading state needed).
- The subtitle under the chart title ("ตั้งแต่ … - …") updates to reflect the filtered range.

---

## 5. State Management

**Chosen approach:** Local widget state (`_NetWorthLineChartState`) via an `enum` + `setState`.

**Rationale:**
- The filter is only consumed inside this widget.
- No need for persistence across app restarts at this stage.
- If persistence is requested later, it can be promoted to `SettingsProvider` without breaking the UI.

**State shape:**
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

---

## 6. Edge Cases

| Scenario | Handling |
|---|---|
| Filtered data has < 2 data points | Render the chart normally (1–2 dots). No special empty state. |
| No data points in selected range | Show existing empty state: icon + "ยังไม่มีข้อมูล". |
| User switches filter rapidly | Synchronous `setState` re-renders are fast enough for monthly data. |
| Dark mode active | All colors derived from `AppColors` dark variants. |

---

## 7. Testing Notes

- Verify each filter option shows the correct date range in the subtitle.
- Verify the Summary Card values do **not** change when the filter changes.
- Verify dark mode colors are consistent.
- Verify empty state appears when selecting a range with zero data.

---

## 8. Files to Touch

| File | Change |
|---|---|
| `lib/screens/statistics/statistics_screen.dart` | Add enum, state, filter helper, update `_NetWorthLineChart` build method and chart container header. |

---

## 9. Out of Scope

- Persisting the selected filter across app restarts.
- Changing chart granularity (daily / weekly) for short ranges.
- Backend / database changes.
