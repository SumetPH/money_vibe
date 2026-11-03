# 01: Prefactor: รวมการจัดการสกุลเงินไว้ที่ registry เดียว

**What to build:** ทุกจุดที่แสดง จัดรูปแบบ หรือเลือกสกุลเงินของยอดเงิน ให้อ่าน symbol, label, ชื่อ และจำนวนทศนิยมจาก registry สกุลเงินตัวเดียว แทนการเช็ก `'USD'` แบบ hard-code เพื่อเตรียมให้ ticket ต่อไปเพิ่มสกุลใหม่ได้โดยไม่ต้องไล่แก้หลายที่ ผู้ใช้ต้องไม่เห็นความเปลี่ยนแปลงใด ๆ (ยังมีแค่ THB/USD) ดู spec ที่ `.scratch/foreign-currency/spec.md`

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

- [ ] registry สกุลเงินเก็บ code, symbol, ชื่อ และจำนวนทศนิยมของแต่ละสกุล
- [ ] จุดแสดงหรือจัดรูปแบบยอดเงินของบัญชีและรายการใช้ registry แทนการเช็ก `'USD'` ตรง ๆ
- [ ] logic ที่ผูกกับ USD จริง (พอร์ต US, ภาษีหุ้น, ค่าธรรมเนียม USD) ยังเหมือนเดิม
- [ ] หน้าตาและพฤติกรรมของบัญชี THB/USD เหมือนเดิมทุกอย่าง
- [ ] `dart format .` และ `tool/check_design.sh` ผ่าน
