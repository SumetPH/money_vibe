# 03: รายการแลกเงิน (`exchange`) ระหว่างบัญชีทั่วไป

**What to build:** ผู้ใช้เลือก type "แลกเงิน" เพื่อบันทึกการแลกเงินระหว่างสองบัญชีที่ไม่ใช่พอร์ต และคนละสกุลกัน กรอกได้สองในสามช่อง (จ่าย / ได้ / rate) แล้วแอปคำนวณช่องที่สามให้ รายการกระทบแค่ยอดคงเหลือของสองบัญชี และไม่นับเป็นรายรับรายจ่าย ดู spec ที่ `.scratch/foreign-currency/spec.md`

**Blocked by:** 01

**Status:** resolved

- [x] มี type `exchange` label "แลกเงิน" ไม่มี category และมีไอคอนกับสีของตัวเองตาม `docs/design.md`
- [x] ฟอร์มแลกเงินแสดงเฉพาะบัญชีปลายทางที่สกุลต่างจากต้นทาง และยังไม่แสดงพอร์ตหุ้น
- [x] widget กรอกสองสกุลมี 3 ช่อง (ยอดฝั่ง A / ยอดฝั่ง B / rate) สองช่องที่แก้ล่าสุดเป็นค่าที่ผู้ใช้กำหนด ช่องที่สามคำนวณและปัดตามทศนิยมของสกุล widget นี้ต้องนำไปใช้ซ้ำใน ticket 06 ได้
- [x] rate แสดงเป็น "1 [สกุลต่างประเทศ] = x ฿" ถ้าไม่มีฝั่งไหนเป็น THB ใช้ "1 [ต้นทาง] = x [ปลายทาง]"
- [x] DB เก็บแค่ `amount` และ `to_amount` ไม่เก็บ rate
- [x] ยอดคงเหลือ: ต้นทาง −amount ปลายทาง +to_amount
- [x] ไม่นับในรายรับรายจ่าย งบประมาณ cash flow และสถิติรายรับรายจ่าย
- [x] รายการในลิสต์แสดงยอดทั้งสองฝั่งและ rate
- [x] CSV export (AI finance export ไม่เกี่ยว: สรุปเฉพาะยอดรวม ไม่มีรายการรายตัว) — รองรับ type `exchange`
- [x] เพิ่มคำว่า "แลกเงิน" ใน `GLOSSARY.md`
- [x] `dart format .` และ `tool/check_design.sh` ผ่าน


## Comments

- เพิ่ม `TransactionType.exchange` + migration `20261103120000_add_exchange_transaction_type.sql` (ยังไม่ได้ `supabase db push`), `ExchangeQuote`/utility ใน `lib/utils/exchange_rate_utils.dart`, `TransactionConversionController` (กติกาสองช่องล่าสุด), `TransactionConversionFields` (ยอดอีกสกุล + rate) ใช้ทั้ง exchange และ transfer ข้ามสกุลชั่วคราว; แยก `TransactionKeyboardHost`, `TransactionDeleteButton`, `transaction_form_accounts.dart` ออกจาก form (736 บรรทัด)
- CSV export ใช้ `type.name` จึงรองรับ exchange อยู่แล้ว; AI export ไม่ได้ list รายการรายตัว (สรุปเฉพาะรายรับ/รายจ่าย) จึงไม่ต้องแก้
- รายการประจำซ่อน exchange จากตัวเลือกประเภท
