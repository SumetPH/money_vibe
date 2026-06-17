# Implementation Plan: Trade Tax Log MVP

## Overview

ปรับระบบบันทึกการขายหุ้นให้ใช้เป็น tax evidence log แบบคร่าว ๆ ได้จริง โดยยึด broker เป็นแหล่งข้อมูลหลักเมื่อมีตัวเลขจริง และใช้ average cost จากแอปเป็นค่าประมาณเมื่อ broker ไม่ได้สรุป realized P/L ให้ตรง ๆ งานรอบนี้โฟกัสเฉพาะ trade log, realized P/L, fee breakdown, และการแสดงผลใน Trade Tracker ยังไม่รวม cash movement/remittance ledger เต็มรูปแบบ

## Architecture Decisions

- ใช้ `StockHolding.costBasisUsd` เป็น average cost ต่อหุ้นสำหรับการคำนวณ estimated realized P/L
- ไม่ทำ FIFO/tax lot matching เองในแอป เพื่อหลีกเลี่ยงตัวเลขไม่ตรง broker โดยเฉพาะ fractional shares, FX, fee rounding, และ corporate actions
- เก็บ P/L source ชัดเจนเป็น `estimated`, `manual`, หรือ `broker` เพื่อให้รายงานภาษีรู้ว่าตัวเลขมาจากไหน
- ใช้ net proceeds หรือ `cashReceivedUsd` เป็นฐานคำนวณ realized P/L เพราะสะท้อนเงินสุทธิหลังหัก fee
- เพิ่ม database migration แบบ backward-compatible: column ใหม่ nullable หรือมี default เพื่อให้ข้อมูลเก่าใช้งานต่อได้

## Task List

### Phase 1: Data Foundation

## Task 1: Extend StockTrade Model for Broker Evidence

**Description:** เพิ่ม field ใน `StockTrade` เพื่อเก็บ gross proceeds, fee breakdown, cost method, P/L source, broker/manual override, settlement date, และ note/reference โดยยังรองรับข้อมูลเก่าที่มีเฉพาะ `cashReceivedUsd`, `costBasisUsd`, และ `realizedPnlUsd`

**Acceptance criteria:**
- [ ] `StockTrade.fromMap` อ่านข้อมูลเก่าได้แม้ไม่มี column ใหม่
- [ ] `StockTrade.toMap` ส่ง field ใหม่ครบ
- [ ] `realizedPnlUsd` ใช้ priority: broker/manual override เมื่อมี, ไม่เช่นนั้นใช้ estimated จาก average cost
- [ ] มี enum หรือ constant สำหรับ `costMethod` และ `pnlSource` โดยไม่ใช้ string กระจัดกระจาย

**Verification:**
- [ ] Tests pass: `rtk flutter test test/stock_trade_test.dart`
- [ ] Manual check: สร้าง `StockTrade` จาก map เก่าแล้วไม่ throw

**Dependencies:** None

**Files likely touched:**
- `lib/models/stock_trade.dart`
- `test/stock_trade_test.dart`

**Estimated scope:** Small: 2 files

## Task 2: Add Supabase Migration for Stock Trade Tax Fields

**Description:** เพิ่ม migration สำหรับ column ใหม่ใน `stock_trades` ให้รองรับ fee breakdown และ P/L source โดยไม่กระทบข้อมูลเดิม

**Acceptance criteria:**
- [ ] เพิ่ม column ใหม่ด้วย `alter table stock_trades`
- [ ] column ที่จำเป็นมี default ที่ปลอดภัย เช่น `cost_method = 'average'`, `pnl_source = 'estimated'`
- [ ] column ที่ broker อาจไม่มีเป็น nullable เช่น `broker_realized_pnl_usd`, `settled_at`, `broker_order_ref`
- [ ] ไม่มีการ drop/rename column เดิม

**Verification:**
- [ ] Manual check: migration SQL อ่านแล้ว backward-compatible
- [ ] App compile ผ่านหลัง adapter map field ใหม่

**Dependencies:** Task 1

**Files likely touched:**
- `supabase/migrations/YYYYMMDDHHMMSS_add_stock_trade_tax_fields.sql`

**Estimated scope:** XS: 1 file

## Task 3: Update Supabase Adapter and CSV Mapping

**Description:** ปรับ repository adapter และ CSV import/export ให้รองรับ field ใหม่ โดย export ให้ครบและ import file เก่าได้

**Acceptance criteria:**
- [ ] `SupabaseStockTradeAdapter` insert/update/select field ใหม่ครบ
- [ ] CSV export มี column ใหม่สำหรับ gross, fees, source, settlement, note/reference
- [ ] CSV import รองรับทั้ง schema เก่าและใหม่
- [ ] ไม่มี regression กับ import/export holding เดิม

**Verification:**
- [ ] Tests pass: `rtk flutter test test/stock_trade_test.dart`
- [ ] Manual check: export CSV แล้วเห็น column ใหม่

**Dependencies:** Task 1, Task 2

**Files likely touched:**
- `lib/repositories/supabase_adapters/stock_trade_adapter.dart`
- `lib/services/csv_service.dart`
- `test/stock_trade_test.dart`

**Estimated scope:** Medium: 3 files

### Checkpoint: Data Foundation

- [ ] `rtk dart format .`
- [ ] `rtk flutter analyze`
- [ ] `rtk flutter test test/stock_trade_test.dart`
- [ ] ข้อมูล trade เก่ายัง load ได้

### Phase 2: Sell Flow

## Task 4: Expand Holding Sell Form with Broker Fee Inputs

**Description:** ปรับหน้าขายหุ้นให้กรอกข้อมูลจาก broker ได้ตรงกับ screenshot เช่น gross proceeds, commission, VAT, market fee, TAF fee, net received และแสดง preview estimated P/L จาก average cost

**Acceptance criteria:**
- [ ] ผู้ใช้กรอก `sharesSold`, `sellPriceUsd`, และ fee breakdown ได้
- [ ] `grossProceedsUsd` auto-calc จาก shares x sell price แต่ยังแสดงให้เทียบกับ broker ได้
- [ ] `cashReceivedUsd` auto-calc จาก gross - total fees และแก้เองได้
- [ ] แสดง estimated cost basis และ estimated realized P/L ก่อนบันทึก
- [ ] UI รองรับ dark mode และใช้ `AppColors` ตามมาตรฐานโปรเจกต์

**Verification:**
- [ ] Tests pass: `rtk flutter test test/holding_sell_form_screen_test.dart`
- [ ] Manual check: ใส่ตัวเลข 2.3961600 หุ้น, 57.99 USD, gross 138.97, fee รวม 0.24, net 138.73 ได้

**Dependencies:** Task 1

**Files likely touched:**
- `lib/screens/account/holding_sell_form_screen.dart`
- `test/holding_sell_form_screen_test.dart`

**Estimated scope:** Medium: 2 files

## Task 5: Update AccountProvider Sell Logic for Average Cost P/L

**Description:** ปรับ `sellHolding` ให้สร้าง `StockTrade` พร้อม gross/net/fees/source และคำนวณ estimated realized P/L จาก average cost ต่อหุ้นของ holding

**Acceptance criteria:**
- [ ] Partial sell ลดจำนวนหุ้นตามเดิม
- [ ] Full sell ลบ holding ตามเดิม
- [ ] Portfolio cash balance เพิ่มด้วย `cashReceivedUsd` หรือ net proceeds
- [ ] `estimatedRealizedPnlUsd = cashReceivedUsd - (sharesSold * holding.costBasisUsd)`
- [ ] `pnlSource` default เป็น `estimated` และ `costMethod` เป็น `average`
- [ ] rollback behavior เดิมยังทำงานเมื่อ insert/update remote fail

**Verification:**
- [ ] Tests pass: `rtk flutter test test/account_provider_stock_trade_test.dart`
- [ ] Manual check: ขายหุ้นมี fee แล้ว realized P/L ลดลงตาม net proceeds

**Dependencies:** Task 1, Task 4

**Files likely touched:**
- `lib/providers/account_provider.dart`
- `test/account_provider_stock_trade_test.dart`

**Estimated scope:** Small: 2 files

## Task 6: Allow Manual/Broker P/L Override in Trade Form

**Description:** ปรับหน้าเพิ่ม/แก้ Trade ให้บันทึก source ของ realized P/L ได้ เช่น estimated จาก AVG, manual ที่ผู้ใช้กรอกเอง, หรือ broker reported เมื่อ broker มีตัวเลขให้

**Acceptance criteria:**
- [ ] ผู้ใช้เลือก P/L source ได้
- [ ] ถ้า source เป็น `manual` หรือ `broker` ต้องกรอก override P/L ได้
- [ ] ถ้า source เป็น `estimated` ระบบคำนวณจาก average cost/net proceeds
- [ ] หน้าแก้ไข trade เก่ารองรับ field ใหม่

**Verification:**
- [ ] Tests pass: `rtk flutter test test/stock_trade_test.dart`
- [ ] Manual check: แก้ trade เป็น broker reported แล้วค่า P/L ใน list เปลี่ยนตาม

**Dependencies:** Task 1, Task 3

**Files likely touched:**
- `lib/screens/trade/stock_trade_form_screen.dart`
- `test/stock_trade_test.dart`

**Estimated scope:** Medium: 2 files

### Checkpoint: Sell Flow

- [ ] `rtk dart format .`
- [ ] `rtk flutter analyze`
- [ ] `rtk flutter test test/stock_trade_test.dart test/account_provider_stock_trade_test.dart test/holding_sell_form_screen_test.dart`
- [ ] Manual end-to-end: ขายหุ้นจาก holding แล้ว trade ใหม่แสดง net/fee/P/L ถูกต้อง

### Phase 3: Reporting and Review UI

## Task 7: Show P/L Source and Fee Details in Trade Tracker

**Description:** ปรับ Trade Tracker ให้แสดงว่ากำไรขาดทุนเป็น estimated AVG, manual, หรือ broker reported และเพิ่มรายละเอียด gross proceeds, total fees, net received, average cost, settlement/reference ใน trade detail

**Acceptance criteria:**
- [ ] รายการ trade แสดง badge/source สั้น ๆ เช่น `AVG`, `Manual`, `Broker`
- [ ] Trade detail แสดง gross proceeds, fee total, net received, average cost, realized P/L
- [ ] Summary รายเดือน/รายปีใช้ `realizedPnlUsd` หลัง override แล้ว
- [ ] UI ยังคงเป็น list-first/surface-first และรองรับ dark mode

**Verification:**
- [ ] Manual check: trade ที่ source ต่างกันแสดง badge ถูกต้อง
- [ ] Manual check: yearly summary รวม P/L ถูกหลัง override

**Dependencies:** Task 1, Task 6

**Files likely touched:**
- `lib/screens/trade/trade_tracker_screen.dart`

**Estimated scope:** Medium: 1 file

## Task 8: Add Tax Estimate Summary Copy and Export Labels

**Description:** เพิ่มข้อความ/label ให้ชัดว่า trade report เป็นประมาณการเพื่อช่วยเตรียมข้อมูลภาษี ไม่ใช่เอกสารภาษีทางการ และปรับชื่อ column/export ให้ผู้ใช้เข้าใจง่าย

**Acceptance criteria:**
- [ ] มีข้อความบอกว่า estimated P/L ใช้ average cost และควร reconcile กับ broker statement
- [ ] CSV column แยก `realized_pnl_source` และ `cost_method`
- [ ] ไม่มีข้อความยาวแบบคำอธิบายวิธีใช้ในหน้าหลักจนรก

**Verification:**
- [ ] Manual check: Trade Tracker และ CSV สื่อสาร source ของตัวเลขชัดเจน

**Dependencies:** Task 3, Task 7

**Files likely touched:**
- `lib/screens/trade/trade_tracker_screen.dart`
- `lib/services/csv_service.dart`

**Estimated scope:** Small: 2 files

### Checkpoint: Complete MVP

- [ ] `rtk dart format .`
- [ ] `rtk flutter analyze`
- [ ] `rtk flutter test test/stock_trade_test.dart test/account_provider_stock_trade_test.dart test/holding_sell_form_screen_test.dart`
- [ ] Manual flow: sell holding -> trade log -> yearly summary -> CSV export
- [ ] Review tax wording for "estimate" vs "broker/manual" clarity

## Deferred Work

- Cash movement ledger: deposit to broker, withdrawal, transfer between broker, FX conversion
- Remittance to Thailand ledger: map returned funds to principal/income buckets
- Income buckets by tax year: principal, realized capital gain, dividend, interest, withholding tax
- Attachments/screenshots for broker evidence
- Multi-currency realized P/L and THB conversion policy
- Dividend and foreign withholding tax tracking

## Risks and Mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Estimated AVG P/L ไม่ตรง broker | High | แสดง `pnlSource` ชัดเจน และให้ broker/manual override ได้ |
| ข้อมูลเก่าพังหลัง migration | High | ใช้ nullable/default column และ update `fromMap` ให้ fallback |
| Fee rounding จาก broker ไม่ตรงสูตร | Medium | ให้ผู้ใช้แก้ `cashReceivedUsd` และ gross/net ได้ |
| CSV import เก่าใช้ไม่ได้ | Medium | import ด้วย index/column fallback และ default source เป็น estimated |
| UI ฟอร์มขายรกเกินไป | Medium | ใช้ section บน surface + auto-calc ค่า default ลดจำนวนช่องที่ต้องกรอกเอง |

## Open Questions

- จะเก็บ `brokerOrderRef` เป็น text อย่างเดียวก่อน หรือรองรับ attachment/screenshot ตั้งแต่ MVP?
- สำหรับ currency อื่นนอกจาก USD จะขยายตอนนี้หรือคง scope เป็น USD ก่อนตามระบบปัจจุบัน?
- Broker reported P/L ถ้ามี ควรเก็บเป็น USD เท่านั้นก่อน หรือเก็บ original currency ด้วย?
- ต้องการให้ Trade Tracker มี tab "ภาษี" แยกทันที หรือใช้รายปีเดิมไปก่อนใน MVP?
