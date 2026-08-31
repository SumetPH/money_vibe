Status: Done

# Show Daily Transaction Inflows and Outflows

## Goal

แสดงยอดบวกและยอดลบใน header ของแต่ละวันบน Transaction overview เพื่อบอกการเคลื่อนไหวทั้งหมดของวันนั้น ไม่ใช่ยอดรายจ่ายจริงเชิงบัญชี

## User Behavior

- ใน Transaction overview (ไม่ได้เจาะจงบัญชี) header รายวันแสดงยอดเงินเข้าเป็นบวกและยอดเงินออกเป็นลบ
- ยอดเงินออกต้องรวมทั้งรายการ `expense`, การรูดบัตร และ `debtRepay` เช่น จ่ายบัตรหรือค่างวด
- ผู้ใช้ยังเห็นรายการโอนระหว่างบัญชีและโอนหนี้ใน list แต่รายการเหล่านี้ไม่เพิ่มยอดบวกหรือลบของ header ภาพรวม
- เมื่อเจาะจงบัญชี ให้คงยอดบวก/ลบตามผลต่อบัญชีนั้นที่มีอยู่เดิม

## Affected Areas

- `lib/screens/transaction/transaction_list_screen.dart`: เปลี่ยนเฉพาะการรวมยอดของ overview header และ bottom summary
- `lib/models/transaction.dart`: อาจเพิ่ม predicate สั้น ๆ สำหรับ transaction ที่นับเป็นยอดเงินออกของ overview
- `lib/providers/transaction_provider.dart`, Budget, Statistics และ AI export: คง `isActualExpense` เพื่อรายงานรายจ่ายจริง
- ไม่มีการเปลี่ยน database schema, Supabase repository, API หรือข้อมูล transaction เดิม

## Business Rules

| Transaction type | Overview header |
| --- | --- |
| `income`, `increaseBalance` | เงินเข้า (`+`) |
| `expense`, `debtRepay`, `decreaseBalance` | เงินออก (`-`) |
| `transfer`, `debtTransfer` | ไม่นับ |

ยอด `expense` ที่เกิดจากรูดบัตรและยอด `debtRepay` ที่ชำระบัตรอาจอยู่วันเดียวกันและถูกนับเป็นเงินออกทั้งคู่โดยตั้งใจ เพราะ header นี้เป็นยอด transaction บวก/ลบของวัน ไม่ใช่ยอดรายจ่ายจริงหรือ net cashflow

## Decisions

- ใช้คำอธิบาย `เงินเข้า` / `เงินออก` สำหรับ header แทนการตีความว่าเป็น `รายรับ` / `รายจ่าย`
- การโอนระหว่างบัญชีตัวเองและการโอนหนี้เป็นการย้ายตำแหน่งของยอด จึงไม่รวมใน overview header
- `isActualExpense` หมายถึงค่าใช้จ่ายใหม่เท่านั้น (`expense`) และต้องไม่ใช้คำนวณ Transaction overview header
- Budget, Statistics และ AI export ยังคงนับ `isActualExpense` เพื่อไม่ให้ยอดใช้จ่ายหรือหมวดหมู่ถูกนับซ้ำเมื่อชำระหนี้
- AI export ใช้คำว่า `Monthly Income and Expenses` และ `Net after actual expenses` เพราะไม่ใช่ cashflow

## Acceptance Criteria

1. Daily group header และ bottom summary ของ Transaction overview รวมยอดบวกจาก `income`/`increaseBalance` และยอดลบจาก `expense`/`debtRepay`/`decreaseBalance`
2. รายการรูดบัตรและรายการจ่ายบัตรในวันเดียวกันต่างรวมในยอดลบของ header
3. `transfer` และ `debtTransfer` ไม่เพิ่มยอดบวกหรือลบของ Transaction overview header
4. Transaction list แบบเจาะจงบัญชียังคงแสดงยอดติดลบที่ต้นทางและยอดบวกที่ปลายทางตาม logic เดิม
5. Budget, Statistics และ AI export ยังคงไม่นับ `debtRepay` หรือ `debtTransfer` เป็นรายจ่ายจริง
6. การคำนวณยอดบัญชีและ Credit Card Bill ไม่เปลี่ยนแปลง

## Implementation State

- เสร็จแล้ว: เพิ่ม `TransactionType.isActualExpense` และรวมกฎรายจ่ายจริงของ Budget, Statistics, TransactionProvider และ AI export ไว้ที่เดียว
- เสร็จแล้ว: Transaction overview header รวม `expense`, `debtRepay` และ `decreaseBalance` เป็นยอดลบ โดยไม่รวม `transfer` และ `debtTransfer`
- เสร็จแล้ว: bottom summary ใช้ `เงินเข้ารวม` / `เงินออกรวม` ให้สอดคล้องกับยอดรวมของ header

## Verification

- ตรวจตัวอย่างวันเดียวที่มี income, expense, รูดบัตร, จ่ายบัตร, ค่างวด, transfer และ debtTransfer
- ยืนยันว่า header รวมเฉพาะประเภทตามตาราง ขณะที่รายการใน list และยอดบัญชีคงเดิม
- Code review ผ่านหลังแก้คำเรียกของ bottom summary และ AI export
- `dart format .`, `flutter analyze` และ `git diff --check` ผ่าน
- ไม่เพิ่ม unit test หรือ browser test ตามกติกาโปรเจกต์
