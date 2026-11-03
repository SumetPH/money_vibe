# 05: ปิดการโอนข้ามสกุลและแปลงข้อมูลเก่า

**What to build:** รายการโอนข้ามสกุลเดิมทั้งหมดกลายเป็นรายการแลกเงิน และหลังจากนี้การโอน การชำระหนี้ และการโอนหนี้ทำได้เฉพาะระหว่างบัญชีสกุลเดียวกัน ยอดคงเหลือทุกบัญชีและยอดในพอร์ตต้องเท่าเดิมทั้งก่อนและหลัง ดู spec ที่ `.scratch/foreign-currency/spec.md`

**Blocked by:** 03, 04

**Status:** resolved

- [x] migration แปลงรายการ `transfer` ที่บัญชีต้นทางและปลายทางคนละสกุลเป็น `exchange`
- [x] ส่วนของ trigger พอร์ตที่ใช้กับ `transfer` ข้ามสกุลซึ่งไม่ใช้แล้ว ถูกลบออก
- [x] ฟอร์ม `transfer`, `debtRepay`, `debtTransfer` แสดงเฉพาะบัญชีปลายทางสกุลเดียวกับต้นทาง
- [x] ช่องกรอกยอดปลายทางข้ามสกุลแบบเดิมในฟอร์มโอนถูกเอาออก
- [x] ยอดคงเหลือทุกบัญชี เงินสดในพอร์ต และ net worth เท่าเดิมทั้งก่อนและหลัง migrate
- [x] apply migration ด้วย `supabase db push`
- [x] `dart format .` และ `tool/check_design.sh` ผ่าน


## Comments

- migration `20261103140000_convert_cross_currency_transfers.sql` แปลง transfer ข้ามสกุลเป็น exchange โดยปิด trigger พอร์ตระหว่าง UPDATE (ยอดและ `portfolio_cash_applied` คงเดิม) แล้วให้ trigger รับเฉพาะ exchange (ยังไม่ได้ `supabase db push`)
- ฟอร์ม: transfer/debtRepay/debtTransfer เลือกปลายทางได้เฉพาะสกุลเดียวกัน, ช่องยอดปลายทางแสดงเฉพาะ exchange, บันทึก transfer ข้ามสกุลจะเตือนให้ใช้แลกเงิน; ฟอร์มรายการประจำกรองปลายทางให้สกุลเดียวกันด้วย
- ตรวจยอดก่อน/หลัง: logic ยอดคงเหลือใช้ `usesDestinationAccount` + `toAmount ?? amount` เหมือนกันทั้งสองประเภท และ migration ไม่แตะยอด จึงไม่เปลี่ยน (ยังไม่ได้ตรวจกับข้อมูลจริงหลัง push)

- แก้ตาม code review: ล้างยอดแปลงสกุลเมื่อเปลี่ยนประเภท, เปิดสกุลต่างประเทศแล้ว rate ตลาดคำนวณยอดที่ตัดบัญชีจากยอดต่างประเทศเสมอ, ตรวจสกุลเดียวกันของ debtRepay/debtTransfer ตอนบันทึก, ยอดตอนแก้ไขใช้ทศนิยมตามสกุล, CSV import แปลงโอนข้ามสกุลเป็นแลกเงินและไม่รับ foreign_amount ≤ 0, migration match user_id
