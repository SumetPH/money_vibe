# Recurring upcoming flat list

Status: ready-for-agent

## Problem Statement

ผู้ใช้ที่เปิดรายละเอียด **Recurring transaction** พบว่าแท็บ “รายการที่จะเกิดขึ้น” แบ่ง **Occurrence** เป็น section ตามเดือน แม้วันที่ของแต่ละรายการจะแสดงอยู่แล้ว ทำให้รายการที่ต้องการดูต่อเนื่องมีส่วนหัวซ้ำเกินจำเป็น

## Solution

แสดง Occurrence ในแท็บ “รายการที่จะเกิดขึ้น” เป็นรายการต่อเนื่องตามลำดับวันเดิม โดยคงวันที่ สถานะ ยอดเงิน และการกระทำของแต่ละแถวไว้ แต่ไม่แสดงหัวข้อหรือตัวคั่นเดือน

## User Stories

1. As a user, I want to view upcoming Occurrences as one continuous list, so that I can scan my scheduled transactions without repeated month sections.
2. As a user, I want each upcoming Occurrence to keep its displayed date, so that I can identify when it is due after month sections are removed.
3. As a user, I want upcoming Occurrences to remain in chronological order across month boundaries, so that the schedule remains predictable.
4. As a user, I want the pending, completed, and skipped states of an upcoming Occurrence to remain unchanged, so that I can act on the correct schedule item.
5. As a user, I want the past-occurrence list to remain unchanged, so that this presentation change affects only upcoming scheduling.
6. As a user, I want an empty upcoming list to retain its existing empty state, so that the absence of future scheduled items remains clear.

## Implementation Decisions

- Modify only the presentation of the current-and-upcoming Occurrence list in the recurring-detail flow.
- Remove the conditional month section header from that list; retain the existing list, chronological data source, row widget, row date, occurrence status, and interactions.
- Do not change the glossary meaning of Recurring transaction, Occurrence, Current-month occurrence, or Past occurrence.
- Do not change persistence, schema, API contracts, occurrence generation, transaction creation, skip, undo, edit, or the past-occurrence tab.

## Testing Decisions

- The verification seam is the existing recurring-detail “รายการที่จะเกิดขึ้น” UI, because it is the highest existing seam that exposes the requested behavior.
- A good check observes external behavior only: occurrences remain chronologically ordered, each row still supplies its date and existing action/state, and no month header appears, including when the list crosses months.
- No new automated test is added. The repository rules prohibit adding unit tests unless explicitly requested, and browser testing is out of scope.

## Out of Scope

- Changes to the past-occurrence tab.
- Changes to the recurring-list screen.
- New grouping modes, filters, sorting controls, or month summaries.
- Data-model, Supabase schema, migration, or API changes.

## Further Notes

- This spec uses the glossary terms **Recurring transaction** and **Occurrence**.
- The agreed scope is a flat upcoming list only; month information remains available through the date shown in each row.
