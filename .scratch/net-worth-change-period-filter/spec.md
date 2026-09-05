# Net worth change period filter

Status: ready-for-agent

## Problem Statement

ผู้ใช้เลือกช่วงเวลาในกราฟแนวโน้มทรัพย์สินสุทธิ แต่ส่วนสรุปไม่แสดงยอดทรัพย์สินสุทธิต้นช่วงและปลายช่วง อีกทั้งยอดเปลี่ยนแปลงและเปอร์เซ็นต์ยังเปรียบเทียบกับจุดแรกของข้อมูลทั้งหมด ทำให้ตัวเลขสรุปไม่สอดคล้องกับช่วงเวลาที่กำลังดูในกราฟ

## Solution

สำหรับช่วงเวลาที่จำกัด แสดง **Period net worth** เป็นยอดต้นช่วงและปลายช่วงจากจุดแรกและจุดสุดท้ายที่มองเห็นในกราฟ พร้อมคำนวณ **Net worth change** และเปอร์เซ็นต์จากสองจุดเดียวกัน สำหรับ “ทั้งหมด” แสดง **Current net worth** เป็นค่าเดียวโดยมี zero baseline

## User Stories

1. As a user, I want to see the opening and closing Period net worth for the selected graph period, so that I know the actual values behind the trend.
2. As a user, I want the opening value to match the first visible graph point, so that the summary and graph share the same starting point.
3. As a user, I want the closing value to match the last visible graph point, so that the summary and graph share the same ending point.
4. As a user, I want Net worth change to follow the selected graph period, so that the summary describes the data I am viewing.
5. As a user, I want the summary to identify the selected period, so that I know what interval the change amount and percentage describe.
6. As a user, I want positive and negative changes to retain their existing signs and semantic colors, so that gains and losses remain easy to distinguish.
7. As a user, I want a period with one visible point to show a zero change and zero percent, so that the summary remains deterministic when no movement can be measured.
8. As a user, I want every existing period option to update the summary consistently, so that 3 months, 6 months, 1 year, this year, and all data behave predictably.
9. As a user, I want account inclusion settings to continue affecting both the graph and summary, so that the visible figures remain internally consistent.
10. As a user, I want the graph itself to retain its existing snapshots and date range, so that this change only corrects the related summary calculation.
11. As a user, I want the all-data view to show one Current net worth value from a zero baseline, so that it reads as my accumulated financial position without an unnecessary period comparison.

## Implementation Decisions

- Use the graph's already-filtered net-worth data as the source for Period net worth and Net worth change.
- Display the first visible net-worth point as the opening value and the last visible point as the closing value.
- Calculate the change amount as the last visible net-worth point minus the first visible net-worth point.
- Calculate the change percentage against the absolute value of the first visible point, retaining the existing zero-baseline behavior.
- Display the selected period label with the opening and closing values in the summary.
- When “ทั้งหมด” is selected, show only Current net worth, treat its baseline as zero, and hide the opening value, closing value, change amount, and percentage.
- Keep the existing period options, monthly snapshot generation, account inclusion switch, formatting, signs, and semantic colors.
- Do not introduce a new abstraction, persistence setting, repository method, schema, or API contract.

## Testing Decisions

- The verification seam is the existing Statistics screen UI because it is the highest existing seam exposing the selected period, graph, and summary together.
- A good check observes external behavior: selecting each period updates the opening value, closing value, change amount, percentage, and period label to match the first and last visible graph points.
- A good check for “ทั้งหมด” observes one Current net worth value with no opening-to-closing comparison or change amount.
- Verify that a period containing one visible point shows a change of zero and a percentage of `0.0%`.
- Verify that positive and negative changes retain their existing sign and semantic color behavior.
- No new automated test is added. Project rules prohibit adding unit tests unless explicitly requested, and browser testing is out of scope.

## Out of Scope

- Changing the underlying net-worth snapshot calculation.
- Adding custom start or end dates or additional period options.
- Changing how monthly net-worth snapshots are generated.
- Adding historical portfolio valuation or historical currency exchange rates.
- Changing account-selection or excluded-account behavior.
- Database, Supabase schema, migration, repository, provider, or API changes.
- Refactoring the Statistics screen or extracting new calculation modules.

## Further Notes

- The default “ทั้งหมด” period uses a zero baseline and shows Current net worth only.
- **Current net worth**, **Period net worth**, and **Net worth change** use the canonical meanings recorded in the project glossary.
