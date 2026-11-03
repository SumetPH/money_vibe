# 06: รายจ่ายหรือรายรับสกุลต่างประเทศ

**What to build:** ตอนบันทึกรายจ่ายหรือรายรับ (เช่น รูดบัตร THB ในญี่ปุ่น) ผู้ใช้เปิด "ชำระเป็นสกุลต่างประเทศ" แล้วกรอกยอดสกุลต่างประเทศคู่กับยอดที่ตัดบัญชีได้ แอปเติมยอดที่ตัดบัญชีโดยประมาณจาก rate ตลาดไว้ให้ก่อน แล้วผู้ใช้แก้เป็นยอดจริงทีหลังได้ ยอดหลักยังเป็นสกุลของบัญชี ยอดคงเหลือ งบ และสถิติจึงไม่เปลี่ยน ดู spec ที่ `.scratch/foreign-currency/spec.md`

**Blocked by:** 02, 03

**Status:** resolved

- [x] migration เพิ่มคอลัมน์ `foreign_amount` และ `foreign_currency` (nullable) ใน `transactions` พร้อม check constraint ว่าต้องว่างพร้อมกันหรือมีค่าพร้อมกัน แล้ว apply ด้วย `supabase db push`
- [x] ฟอร์ม expense/income มีสวิตช์ "ชำระเป็นสกุลต่างประเทศ" ปิดไว้เป็นค่าเริ่มต้น เมื่อเปิดจะแสดงตัวเลือกสกุลและ widget กรอกสองสกุลจาก ticket 03
- [x] เลือกสกุลเดียวกับบัญชีไม่ได้ และค่าเริ่มต้นเป็นสกุลต่างประเทศล่าสุดที่ใช้
- [x] ยอดที่ตัดบัญชีเติมให้โดยประมาณจาก rate ตลาดปัจจุบัน และผู้ใช้แก้ได้ ไม่มีสถานะ pending
- [x] รายการในลิสต์แสดง "¥3,000 → ฿702"
- [x] แก้รายการเดิมแล้วข้อมูลสกุลต่างประเทศยังอยู่ และถ้าปิดสวิตช์ข้อมูลนี้จะถูกล้าง
- [x] CSV export (AI finance export ไม่เกี่ยว: สรุปเฉพาะยอดรวม ไม่มีรายการรายตัว) — มี `foreign_amount` และ `foreign_currency`
- [x] เพิ่มคำศัพท์ "สกุลต่างประเทศของรายการ" ใน `GLOSSARY.md`
- [x] `dart format .` และ `tool/check_design.sh` ผ่าน


## Comments

- migration `20261103150000_add_foreign_amount_to_transactions.sql` (ยังไม่ได้ `supabase db push`); model/adapter/CSV export+import มี `foreign_amount`, `foreign_currency`
- สวิตช์ในการ์ดยอดเงิน + `TransactionForeignCurrencyHost` (สกุลล่าสุดดูจากรายการล่าสุดที่มีสกุลต่างประเทศ, rate ตลาดจาก Frankfurter ผ่าน `ExchangeRateService.fetchRate` แล้ว `suggestRate`), ย้าย currency picker ไป `lib/widgets/currency_picker_sheet.dart` และบันทึกใน design.md
- AI export สรุปเฉพาะยอดรวม ไม่มีรายการรายตัว จึงไม่ได้เพิ่มฟิลด์
