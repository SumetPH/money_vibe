# Spec: Portfolio Investment Plan

## Assumptions

1. ฟีเจอร์นี้อยู่ในหน้า portfolio account เดิม (`PortfolioDetailScreen`) และเข้าผ่าน tab หรือเมนูชื่อ `แผนการลงทุน`
2. ใช้ได้กับ portfolio ทุกประเภทที่ `account.isPortfolio == true` ทั้ง US และ Thai portfolio
3. ค่าเงินที่แสดงใช้สกุลเงินของพอร์ต (`account.currencyCodeLabel`) โดยยังคงใช้ field ชื่อ `Usd` เดิมภายใน holding เพื่อความเข้ากันได้กับโค้ดปัจจุบัน
4. Checklist DCA เป็นสถานะรายเดือนต่อ portfolio ไม่ใช่ global ทั้งแอป
5. แผน balance เป็นข้อมูลตั้งเป้าหมาย ไม่แก้จำนวนหุ้นหรือ transaction จริงจนกว่าผู้ใช้จะไปซื้อ/บันทึกเอง
6. รอบแรกยังไม่ต้องสร้างคำสั่งซื้ออัตโนมัติ, ไม่เชื่อม broker, และไม่สร้าง transaction ให้อัตโนมัติ

## Objective

เพิ่มพื้นที่วางแผนลงทุนในหน้า portfolio account เพื่อให้ผู้ใช้ตอบได้เร็วว่าเดือนนี้ DCA แล้วหรือยัง และถ้าต้องเติมเงินอีกจำนวนหนึ่งควรเติมหุ้นตัวไหนเพื่อให้พอร์ตเข้าใกล้สัดส่วนเป้าหมายมากที่สุด

Success ของฟีเจอร์คือ:

- ผู้ใช้เปิดหน้า portfolio แล้วเข้า `แผนการลงทุน` ได้จากจุดเดียวกับข้อมูลพอร์ตปัจจุบัน
- ผู้ใช้ติ๊กสถานะ DCA ของเดือนปัจจุบันได้ และสถานะยังอยู่หลังปิด/เปิดแอป
- ผู้ใช้กำหนดหุ้นในแผนพร้อม target allocation เป็นเปอร์เซ็นต์ได้
- ระบบแสดง target value, current value, diff percent, diff amount ของแต่ละหุ้นเทียบกับพอร์ตปัจจุบัน
- ผู้ใช้กรอกเงินเพิ่ม เช่น `500 USD` หรือ `500 THB` แล้วเห็นคำแนะนำว่าควรเติมตัวไหนเท่าไหร่

## Tech Stack

- Flutter/Dart
- Provider สำหรับ state management
- Supabase เป็น backend หลัก
- GoRouter ใช้เฉพาะ top-level navigation เดิม ส่วน portfolio detail ใช้ `Navigator`/widget flow เดิมตามไฟล์ปัจจุบัน
- Theme token ใช้ `lib/theme/app_colors.dart` และ `lib/theme/app_radii.dart`

## Commands

หลังมีการแก้โค้ด ต้องรัน:

```bash
rtk dart format .
rtk flutter analyze
```

หมายเหตุ: repo นี้อาจเจอข้อจำกัด sandbox ที่ Flutter พยายามเขียน `flutter/bin/cache/engine.stamp` นอก workspace ให้รายงานตามจริงถ้าเกิดขึ้น

## Project Structure

ตำแหน่งที่คาดว่าจะเพิ่ม/แก้:

```text
lib/models/
  investment_plan.dart                 # model สำหรับ DCA checklist และ target allocation

lib/repositories/
  database_repository.dart             # เพิ่ม interface อ่าน/เขียน investment plan
  supabase_repository.dart             # delegate ไป adapter ใหม่
  supabase_adapters/
    investment_plan_adapter.dart       # Supabase CRUD สำหรับ plan/checklist

lib/providers/
  account_provider.dart                # โหลดและ expose plan ตาม portfolioId

lib/screens/account/
  portfolio_detail_screen.dart         # เพิ่ม tab/เมนู แผนการลงทุน
  portfolio_investment_plan_screen.dart หรือ widget แยก # UI หลักของฟีเจอร์

supabase/migrations/
  YYYYMMDDHHMMSS_create_portfolio_investment_plans.sql

supabase/init_schema.sql               # include migration ใหม่

docs/features/
  portfolio_investment_plan_spec.md
```

## UX Specification

### Navigation

- เพิ่ม tab ที่สามใน `PortfolioDetailScreen`: `แผนการลงทุน`
- Tab เดิมยังอยู่: `พอร์ต`, `หุ้นทั้งหมด`
- ถ้าไม่มี holding ให้แสดง empty state แบบ list-first พร้อมปุ่มไปเพิ่มหุ้น ไม่ต้องมี card ใหญ่ซ้อนหลายชั้น

### DCA Checklist

- แสดง section แรกของหน้า `แผนการลงทุน`
- ใช้เดือนปัจจุบันจาก local time ของเครื่องผู้ใช้ เช่น `กรกฎาคม 2026`
- แสดง row:
  - label: `DCA เดือนนี้`
  - state: toggle/checkbox เปิด-ปิดได้
  - optional note สั้น ๆ: `ติ๊กเมื่อซื้อครบตามแผนแล้ว`
- เมื่อ toggle แล้วบันทึกทันที
- เก็บสถานะเป็นรายเดือนต่อพอร์ต โดย key หลักคือ `portfolio_id + month`
- เดือนใหม่ต้องเริ่มเป็นยังไม่ติ๊ก แต่ยังดูประวัติเดือนเก่าได้ในอนาคตถ้าต้องการต่อยอด

### Target Allocation

- แสดงรายการหุ้นจาก holdings ปัจจุบันเป็นค่าเริ่มต้น
- ผู้ใช้เลือกเปิด/ปิดว่าหุ้นตัวไหนอยู่ในแผน balance
- ผู้ใช้กำหนด target percent ต่อหุ้นได้ เช่น `AAPL 40%`, `VOO 60%`
- รวม target percent ควรเป็น `100%`
- ถ้ารวมไม่เท่ากับ 100%:
  - ยังแสดง preview ได้
  - แสดง warning ที่ไม่ block การแก้ไข
  - ไม่ควรบันทึกเป็น active plan ถ้ารวมไม่อยู่ในช่วงยอมรับได้ เช่น `99.99% - 100.01%`
- หุ้นที่มีอยู่จริงแต่ไม่ถูกเลือกในแผน:
  - แสดงในกลุ่ม `นอกแผน`
  - มูลค่าไม่นับรวมในฐานคำนวณ rebalance/recommendation ของแผน
  - ไม่ได้รับ recommendation เติมเงิน

### Rebalance Table

สำหรับหุ้นแต่ละตัวในแผน แสดง:

- ticker/name
- target percent
- current percent
- target value
- current value
- diff percent = `current percent - target percent`
- diff amount = `current value - target value`
- สถานะ:
  - `ขาด` เมื่อ diff amount ติดลบ
  - `เกิน` เมื่อ diff amount เป็นบวก
  - `พอดี` เมื่อใกล้ 0 ตาม tolerance

นิยาม portfolio value:

```text
portfolioValue = sum(holding.valueUsd) + account.cashBalance
```

สำหรับ target allocation รอบ MVP ให้คิดจาก `sum(holding.valueUsd)` เฉพาะหุ้นที่เปิดอยู่ในแผน และมีตัวเลือกในอนาคตว่าจะรวม cash หรือไม่

สูตรพื้นฐาน:

```text
currentValue = holding.valueUsd
plannedHoldingsValue = sum(enabledHolding.valueUsd)
currentPercent = currentValue / plannedHoldingsValue * 100
targetValue = plannedHoldingsValue * targetPercent / 100
diffAmount = currentValue - targetValue
diffPercent = currentPercent - targetPercent
```

### Buy Amount Recommendation

ผู้ใช้กรอกจำนวนเงินที่จะซื้อเพิ่ม เช่น `x`

ระบบคำนวณตามหลัก:

1. newTotal = currentTotal + x
2. targetValueAfterBuy ของแต่ละหุ้น = newTotal * targetPercent / 100
3. gap = targetValueAfterBuy - currentValue
4. แนะนำเติมเฉพาะหุ้นที่ gap > 0
5. เติมเงินให้หุ้นที่ขาดมากสุดก่อนตามลำดับ gap
6. ถ้า x น้อยกว่า gap รวม ให้เติมตัวแรกจนเงินหมด หรือจนตัวนั้นถึงเป้า แล้วค่อยตัวถัดไปถ้ามีเงินเหลือ
7. ถ้า x มากกว่า gap รวม ให้เติมจนทุกตัวถึงเป้าก่อน แล้วส่วนเกินกระจายตาม target percent

ผลลัพธ์ที่แสดง:

- `ควรซื้อเพิ่ม`
- amount ต่อ ticker
- percent โดยประมาณหลังซื้อ
- ข้อความเตือนว่าเป็นคำแนะนำเพื่อ balance เท่านั้น ไม่ได้บันทึก transaction หรือเปลี่ยนจำนวนหุ้นจริง

## Data Model

แนะนำแยกตารางใหม่ ไม่เพิ่ม field ลง `portfolio_holdings` เพื่อไม่ให้ plan state ปะปนกับข้อมูล holding จริงและลดความเสี่ยง stale write

### `portfolio_investment_plans`

```sql
CREATE TABLE public.portfolio_investment_plans (
  id text PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  portfolio_id text NOT NULL REFERENCES public.accounts(id) ON DELETE CASCADE,
  dca_month text NOT NULL,
  dca_completed boolean NOT NULL DEFAULT false,
  created_at timestamp without time zone DEFAULT now(),
  updated_at timestamp without time zone DEFAULT now(),
  UNIQUE (user_id, portfolio_id, dca_month)
);
```

`dca_month` ใช้รูปแบบ `YYYY-MM` จาก local time ของเครื่องผู้ใช้ก่อนบันทึก

### `portfolio_allocation_targets`

```sql
CREATE TABLE public.portfolio_allocation_targets (
  id text PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  portfolio_id text NOT NULL REFERENCES public.accounts(id) ON DELETE CASCADE,
  holding_id text REFERENCES public.portfolio_holdings(id) ON DELETE SET NULL,
  ticker text NOT NULL,
  target_percent numeric NOT NULL DEFAULT 0,
  is_enabled boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamp without time zone DEFAULT now(),
  updated_at timestamp without time zone DEFAULT now(),
  UNIQUE (user_id, portfolio_id, ticker)
);
```

เหตุผลที่เก็บ `ticker` คู่กับ `holding_id`:

- ใช้ `holding_id` เมื่อหุ้นยังอยู่ใน portfolio
- ยังจำ target ticker ได้ถ้า holding ถูกลบ หรือจะต่อยอดเป็น watch target ในอนาคต

RLS:

- ผู้ใช้จัดการเฉพาะ row ของตัวเองด้วย `auth.uid() = user_id`

Sync:

- ใช้ module `portfolio` เดิมหรือเพิ่ม module `investment_plan`
- ทางเลือก MVP: ใช้ `portfolio` เพื่อลดการเปลี่ยน SyncProvider
- ทางเลือกสะอาดกว่า: เพิ่ม `investment_plan` เพื่อแยก timestamp ของ plan ออกจาก holding/price refresh

## Code Style

ตัวอย่าง helper คำนวณควรเป็น pure function แยกจาก widget เพื่อให้อ่านง่าย:

```dart
class AllocationRecommendation {
  final String ticker;
  final double currentValue;
  final double targetPercent;
  final double targetValue;
  final double diffAmount;
  final double buyAmount;

  const AllocationRecommendation({
    required this.ticker,
    required this.currentValue,
    required this.targetPercent,
    required this.targetValue,
    required this.diffAmount,
    required this.buyAmount,
  });
}

List<AllocationRecommendation> buildAllocationRecommendations({
  required List<StockHolding> holdings,
  required Map<String, double> targetPercentByTicker,
  required double buyAmount,
}) {
  // คำนวณแบบไม่มี side effect เพื่อไม่ให้ UI เผลอแก้ holding จริง
  return const [];
}
```

Convention:

- ไฟล์ Dart ใช้ `snake_case.dart`
- class ใช้ `PascalCase`
- provider ลงท้ายด้วย `Provider`
- หลีกเลี่ยง `as dynamic`
- ถ้ามี helper คำนวณเยอะ ให้แยกเป็น model/helper ไม่ยัดไว้ใน `build()`

## Verification Strategy

ตามข้อกำหนดโปรเจกต์ งานนี้ไม่เพิ่ม unit test เว้นแต่ผู้ใช้ขอโดยตรง

หลัง implement ให้ตรวจ:

```bash
rtk dart format .
rtk flutter analyze
```

Manual verification:

- เปิด portfolio ที่มี holdings หลายตัว
- เข้า tab `แผนการลงทุน`
- toggle `DCA เดือนนี้` แล้วออก/เข้าใหม่ สถานะยังถูกต้อง
- ตั้ง target percent รวม 100% แล้วเห็น diff ถูกต้อง
- ตั้ง target percent ไม่ครบ 100% แล้วเห็น warning
- กรอก buy amount แล้ว recommendation ไม่เกินจำนวนเงินที่กรอก
- ทดสอบ dark mode ให้ text/surface/divider อ่านออก

## Boundaries

Always:

- ใช้ Supabase เท่านั้น
- ถ้าเพิ่ม schema ต้องเพิ่ม migration และอัปเดต `supabase/init_schema.sql`
- ใช้ local time สำหรับ `YYYY-MM`
- ให้ UI รองรับ light/dark mode
- คำนวณ recommendation โดยไม่แก้จำนวนหุ้น, cash balance, transaction หรือ holding จริง

Ask first:

- จะให้ recommendation รวม cash balance ใน allocation หรือไม่
- จะสร้าง transaction จากแผนซื้ออัตโนมัติหรือไม่
- จะเพิ่มประวัติ checklist ย้อนหลังหลายเดือนใน UI หรือไม่
- จะให้หุ้นที่ไม่มี holding แล้วแต่ยังอยู่ใน target แสดงต่อหรือถูกซ่อน

Never:

- ห้ามใช้ SQLite
- ห้ามใช้คอลัมน์ `tags` ของ transactions
- ห้ามเขียน API key/secret ลงโค้ด
- ห้ามใช้ browser test หรือ unit test เว้นแต่ผู้ใช้ขอโดยตรง
- ห้ามให้ price refresh เขียนทับ target allocation หรือ checklist

## Implementation Plan

1. เพิ่ม model และ pure calculation helper สำหรับ allocation/recommendation
2. เพิ่ม Supabase migration สำหรับ plan/checklist/target allocation และ update `init_schema.sql`
3. เพิ่ม repository interface + Supabase adapter สำหรับอ่าน/เขียน plan
4. ขยาย `AccountProvider` ให้โหลด plan พร้อม portfolio data และ expose methods สำหรับ toggle DCA/update targets
5. เพิ่ม tab `แผนการลงทุน` ใน `PortfolioDetailScreen`
6. สร้าง UI สำหรับ DCA checklist, target editor, rebalance table, buy amount recommendation
7. รัน `rtk dart format .` และ `rtk flutter analyze`

## Open Questions

1. ต้องการให้ allocation target คิดจากมูลค่าหุ้นอย่างเดียว หรือรวม cash balance ในพอร์ตด้วย?
2. DCA checklist ต้องมีแค่เดือนปัจจุบันพอไหม หรืออยากดู/แก้ประวัติย้อนหลังด้วย?
3. ถ้าผู้ใช้ขายหุ้นจน holding หาย แต่ยังมี target อยู่ ต้องการให้ target นั้นค้างไว้หรือซ่อนอัตโนมัติ?
4. ถ้าต้องการเปลี่ยนจากการเติมตัวที่ขาดที่สุดก่อนกลับไปเป็นการกระจายตาม gap ต้องเพิ่มตัวเลือก mode หรือไม่?
