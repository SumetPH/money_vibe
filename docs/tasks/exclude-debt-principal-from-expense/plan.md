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
- `lib/providers/transaction_provider.dart`: เป็นจุดกลางของกฎรายจ่ายสำหรับ Budget, Statistics และ AI export โดยใช้ประเภทบัญชีปลายทางประกอบ
- Budget, Statistics และ AI export: คงพฤติกรรมเดิม โดยไม่นับซ้ำเฉพาะ `debtRepay` ที่ชำระเข้าบัตรเครดิต
- ไม่มีการเปลี่ยน database schema, Supabase repository, API หรือข้อมูล transaction เดิม

## Business Rules

| Transaction type | Overview header |
| --- | --- |
| `income`, `increaseBalance` | เงินเข้า (`+`) |
| `expense`, `debtRepay`, `decreaseBalance` | เงินออก (`-`) |
| `transfer`, `debtTransfer` | ไม่นับ |

ยอด `expense` ที่เกิดจากรูดบัตรและยอด `debtRepay` ที่ชำระบัตรอาจอยู่วันเดียวกันและถูกนับเป็นเงินออกทั้งคู่โดยตั้งใจ เพราะ header นี้เป็นยอด transaction บวก/ลบของวัน ไม่ใช่ยอดรายจ่ายจริงหรือ net cashflow

สำหรับ Budget, Statistics และ AI export ให้ใช้กฎรายจ่ายเดิมของแอป:

| Transaction type | รายจ่ายของโมดูลอื่น |
| --- | --- |
| `expense`, `debtTransfer` | นับ |
| `debtRepay` เข้าบัญชีทั่วไปหรือบัญชีหนี้ | นับ |
| `debtRepay` เข้าบัตรเครดิต | ไม่นับ เพื่อไม่ซ้ำกับรายการรูดบัตร |
| ประเภทอื่น | ไม่นับ |

## Decisions

- ใช้คำอธิบาย `เงินเข้า` / `เงินออก` สำหรับ header แทนการตีความว่าเป็น `รายรับ` / `รายจ่าย`
- การโอนระหว่างบัญชีตัวเองและการโอนหนี้เป็นการย้ายตำแหน่งของยอด จึงไม่รวมใน overview header
- Transaction overview ไม่ใช้กฎรายจ่ายของโมดูลอื่น เพราะต้องแสดงการเคลื่อนไหวเงินเข้า/ออกตามรายการ
- กฎรายจ่ายของ Budget, Statistics และ AI export ต้องดูประเภทบัญชีปลายทาง จึงไม่สามารถเป็น predicate ของ `TransactionType` เพียงอย่างเดียวได้
- คืนพฤติกรรมเดิมของโมดูลเหล่านี้ และยกเว้นเฉพาะการชำระเข้าบัตรเครดิตเพื่อไม่ให้นับซ้ำกับรายการรูดบัตร
- AI export ใช้คำว่า `Monthly Income and Expenses` และ `Net after actual expenses` เพราะไม่ใช่ cashflow

## Acceptance Criteria

1. Daily group header และ bottom summary ของ Transaction overview รวมยอดบวกจาก `income`/`increaseBalance` และยอดลบจาก `expense`/`debtRepay`/`decreaseBalance`
2. รายการรูดบัตรและรายการจ่ายบัตรในวันเดียวกันต่างรวมในยอดลบของ header
3. `transfer` และ `debtTransfer` ไม่เพิ่มยอดบวกหรือลบของ Transaction overview header
4. Transaction list แบบเจาะจงบัญชียังคงแสดงยอดติดลบที่ต้นทางและยอดบวกที่ปลายทางตาม logic เดิม
5. Budget, Statistics และ AI export นับ `expense`, `debtTransfer` และ `debtRepay` ที่ไม่ได้ชำระเข้าบัตรเครดิตตามพฤติกรรมเดิม
6. การคำนวณยอดบัญชีและ Credit Card Bill ไม่เปลี่ยนแปลง

## Implementation State

- เสร็จแล้ว: Transaction overview header รวม `expense`, `debtRepay` และ `decreaseBalance` เป็นยอดลบ โดยไม่รวม `transfer` และ `debtTransfer`
- เสร็จแล้ว: bottom summary ใช้ `เงินเข้ารวม` / `เงินออกรวม` ให้สอดคล้องกับยอดรวมของ header
- เสร็จแล้ว: คืนกฎรายจ่ายเดิมของ Budget, Statistics และ AI export ผ่าน `TransactionProvider.isActualExpense` ซึ่งใช้ประเภทบัญชีปลายทางเพื่อแยกการชำระบัตรเครดิต

## Deviations

- การรวมกฎรายจ่ายไว้ที่ `TransactionType.isActualExpense` ทำให้ `debtRepay` และ `debtTransfer` หายจาก Budget และโมดูลรายงานทั้งหมด จึงแก้กลับไปใช้กฎที่รับ transaction และรายการบัญชีเพื่อรักษาพฤติกรรมเดิม

## Verification

- ตรวจตัวอย่างวันเดียวที่มี income, expense, รูดบัตร, จ่ายบัตร, ค่างวด, transfer และ debtTransfer
- ตรวจ code path ของ Budget, Statistics และ AI export แล้วใช้กฎรายจ่ายร่วมเดียวกัน โดยยกเว้นเฉพาะ `debtRepay` ที่ปลายทางเป็นบัตรเครดิต
- ตรวจ final diff แล้ว Transaction overview, การคำนวณยอดบัญชี และ Credit Card Bill ไม่มีการเปลี่ยนแปลงเพิ่มเติม
- `dart format .`, `flutter analyze` และ `git diff --check` ผ่าน
- ไม่เพิ่ม unit test หรือ browser test ตามกติกาโปรเจกต์
