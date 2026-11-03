# 01: Prefactor: รวมการจัดการสกุลเงินไว้ที่ registry เดียว

**What to build:** ทุกจุดที่แสดง จัดรูปแบบ หรือเลือกสกุลเงินของยอดเงิน ให้อ่าน symbol, label, ชื่อ และจำนวนทศนิยมจาก registry สกุลเงินตัวเดียว แทนการเช็ก `'USD'` แบบ hard-code เพื่อเตรียมให้ ticket ต่อไปเพิ่มสกุลใหม่ได้โดยไม่ต้องไล่แก้หลายที่ ผู้ใช้ต้องไม่เห็นความเปลี่ยนแปลงใด ๆ (ยังมีแค่ THB/USD) ดู spec ที่ `.scratch/foreign-currency/spec.md`

**Blocked by:** None (can start immediately)

**Status:** resolved

- [x] registry สกุลเงินเก็บ code, symbol, ชื่อ และจำนวนทศนิยมของแต่ละสกุล
- [x] จุดแสดงหรือจัดรูปแบบยอดเงินของบัญชีและรายการใช้ registry แทนการเช็ก `'USD'` ตรง ๆ
- [x] logic ที่ผูกกับ USD จริง (พอร์ต US, ภาษีหุ้น, ค่าธรรมเนียม USD) ยังเหมือนเดิม
- [x] หน้าตาและพฤติกรรมของบัญชี THB/USD เหมือนเดิมทุกอย่าง
- [x] `dart format .` และ `tool/check_design.sh` ผ่าน


## Comments

- เพิ่ม `CurrencyInfo` + `CurrencyUtils` (info, isBase, amountSuffix, formatAmount, formatWithSymbol) และ `Account.isForeignCurrency` / `toBaseAmount` แทนการเช็ก `'USD'` ในจุดแสดงผลและแปลงยอด; รายการโอนแสดงสัญลักษณ์ตามสกุลจริง (เดิม "฿ 100.00 USD" → "$ 100.00"); แก้ฟอร์มแก้ไขบัญชีสกุลต่างประเทศที่ไม่ใช่พอร์ตให้โหลด rate เดิมแทน 1
