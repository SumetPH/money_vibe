# Implementation Plan: Portfolio Investment Plan

## Overview

เพิ่ม tab `แผนการลงทุน` ในหน้า portfolio account เพื่อให้ผู้ใช้เช็ค DCA รายเดือน, ตั้ง target allocation ต่อหุ้น, เห็นว่าพอร์ตขาด/เกินเป้ากี่เปอร์เซ็นต์และกี่หน่วยเงิน, และลองกรอกเงินซื้อเพิ่มเพื่อดู recommendation ว่าควรเติมหุ้นตัวไหนเท่าไหร่ ฟีเจอร์นี้ต้องเก็บข้อมูลใน Supabase แยกจาก `portfolio_holdings` เพื่อไม่ให้ price refresh หรือ stale holding writes ไปทับข้อมูลแผนลงทุน

## Scope

### In Scope

- เพิ่มข้อมูลแผนลงทุนราย portfolio ใน Supabase
- เพิ่ม DCA checklist เฉพาะเดือนปัจจุบัน โดยใช้ local month key รูปแบบ `YYYY-MM`
- เพิ่ม target allocation ต่อ ticker/holding พร้อมเปิดปิดได้
- เพิ่ม pure calculation สำหรับ rebalance rows และ buy amount recommendation
- เพิ่ม tab `แผนการลงทุน` ใน `PortfolioDetailScreen`
- รองรับทั้ง US และ Thai portfolio ผ่าน `account.isPortfolio`
- ใช้ค่าเงินของ portfolio account สำหรับข้อความและจำนวนเงินที่แสดง
- รัน `rtk dart format .` และ `rtk flutter analyze` หลัง implementation

### Out of Scope

- ไม่สร้าง transaction หรือคำสั่งซื้ออัตโนมัติ
- ไม่เชื่อม broker หรือส่ง order จริง
- ไม่เพิ่ม unit test หรือ browser test เว้นแต่ผู้ใช้ขอ
- ไม่ทำประวัติ DCA checklist ย้อนหลังหลายเดือนใน UI รอบแรก
- ไม่ rename field/column กลุ่ม `*_usd`
- ไม่แก้ระบบ price refresh นอกจากต้องไม่ให้ชนกับ investment plan state

## MVP Decisions

- Allocation calculation รอบแรกใช้ `sum(holding.valueUsd)` เป็นฐาน ไม่รวม `account.cashBalance`
- DCA checklist แสดงและแก้ได้เฉพาะเดือนปัจจุบัน
- Buy recommendation เติมหุ้นที่ขาดจากเป้ามากสุดให้ถึงเป้าก่อน แล้วค่อยตัวถัดไป เพื่อให้เหมาะกับ DCA ก้อนเล็กรายเดือน
- Target ที่อ้างถึง ticker ที่ยังไม่มี holding จะเก็บใน data model ได้ แต่ UI รอบแรกให้เน้น holdings ปัจจุบันก่อน
- Sync log ใช้ module `portfolio` ใน MVP เพื่อลดการแตะ `SyncProvider`; ถ้าภายหลังต้องแยก timing ค่อยเพิ่ม module `investment_plan`

## Architecture Decisions

- สร้าง model ใหม่ เช่น `InvestmentPlanMonthStatus`, `PortfolioAllocationTarget`, `AllocationRecommendation` แยกจาก `StockHolding`
- เพิ่ม repository interface ใหม่ใน `DatabaseRepository` แล้ว implement ผ่าน `SupabaseInvestmentPlanAdapter`
- ให้ `AccountProvider` โหลด investment plan พร้อมข้อมูล account/holding เพื่อให้หน้า portfolio อ่านจาก provider เดิมได้
- แยก calculation helper เป็น pure Dart function เพื่อไม่ให้ logic ไปกองใน `build()`
- UI เป็น widget/screen แยก เช่น `portfolio_investment_plan_screen.dart` แล้วให้ `PortfolioDetailScreen` เป็นคนส่ง account, holdings, plan state เข้าไป
- ใช้ surface/list-first style ตาม portfolio screens เดิม ไม่ทำ card ซ้อนหรือ layout marketing

## Dependency Graph

Database migration
  -> Dart models and repository interface
  -> Supabase adapter delegation
  -> AccountProvider state and methods
  -> Calculation helper
  -> Portfolio tab wiring
  -> Investment plan UI
  -> Verification and cleanup

## Task List

### Phase 1: Data Foundation

- [ ] Task 1: Add investment plan schema and Supabase contract
- [ ] Task 2: Add Dart models and pure allocation calculations

### Checkpoint: Foundation

- [ ] Schema has RLS and `init_schema.sql` includes the migration
- [ ] Calculation code has no UI or repository side effects
- [ ] No existing holding refresh path writes investment plan state

### Phase 2: Persistence and State

- [ ] Task 3: Add repository adapter for investment plans
- [ ] Task 4: Load and mutate investment plan data through `AccountProvider`

### Checkpoint: Data Flow

- [ ] Account provider can expose current month DCA status by portfolio
- [ ] Account provider can expose/update allocation targets by portfolio
- [ ] Failed writes do not leave permanent incorrect optimistic state

### Phase 3: UI Integration

- [ ] Task 5: Add the `แผนการลงทุน` tab shell to portfolio detail
- [ ] Task 6: Build DCA checklist and target allocation editor
- [ ] Task 7: Build rebalance table and buy amount recommendation UI

### Checkpoint: User Flow

- [ ] User can enter the new tab from a portfolio account
- [ ] User can toggle DCA current month and see persisted state after reload
- [ ] User can set target allocation and see warning when total target is not 100%
- [ ] User can enter buy amount and see recommendations without changing holdings/transactions

### Phase 4: Final Verification

- [ ] Task 8: Format, analyze, and focused manual review

### Checkpoint: Complete

- [ ] `rtk dart format .` has run
- [ ] `rtk flutter analyze` has run, or any environment permission issue is recorded
- [ ] Manual code review confirms the feature does not use SQLite, transaction `tags`, or full holding refresh writes

## Risks and Mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Plan state gets mixed into `portfolio_holdings` and is overwritten by refresh | High | Store checklist/targets in separate tables and never update them from price refresh paths |
| Target percentage math becomes hard to trust | High | Keep allocation calculation in a pure helper with explicit inputs and outputs |
| UI becomes too dense on mobile | Medium | Use compact list rows, surface sections, and horizontal-safe numeric layout |
| Thai portfolio values are mislabeled as USD | Medium | Use `account.currencyCodeLabel` for display and keep `*_usd` names internal only |
| Optimistic provider update diverges from Supabase on error | Medium | Snapshot old state before mutation and restore on catch |
| Sync log granularity is too broad | Low | Use `portfolio` for MVP, document that a future `investment_plan` module can split sync timing |
| Flutter analyze may hit SDK cache permissions | Low | Run required command and report exact `engine.stamp` permission failure if it occurs |

## Open Questions for Review

- ควรเปลี่ยน MVP ให้ allocation รวม cash balance ด้วยไหม
- DCA checklist ต้องดู/แก้ย้อนหลังในรอบแรกไหม
- Target ของ ticker ที่ไม่มี holding แล้วควรค้างใน UI หรือซ่อนก่อน
- ถ้าภายหลังมีเงินก้อนใหญ่ ควรเพิ่ม mode กระจายตาม gap แยกจาก DCA รายเดือนหรือไม่

## Implementation Notes

- ทำทีละ task และให้แต่ละ task อยู่ในสภาพที่ analyze ต่อได้
- หลีกเลี่ยงการแก้ไฟล์ portfolio ใหญ่แบบกว้างเกินจำเป็น โดยเฉพาะ `portfolio_detail_screen.dart`
- ไม่ทำ git commit
- ไม่เพิ่ม unit test/browser test
- หาก schema เปลี่ยน ต้องอัปเดตทั้ง `supabase/migrations` และ `supabase/init_schema.sql`
