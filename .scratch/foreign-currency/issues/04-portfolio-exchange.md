# 04: เติมและถอนเงินพอร์ตหุ้น US ด้วย `exchange`

**What to build:** ผู้ใช้เติม THB เข้าพอร์ตหุ้น US หรือถอน USD ออกเป็น THB ด้วยรายการแลกเงินได้ เงินสด USD ในพอร์ต เงินเข้าพอร์ตสะสม และ net worth ต้องถูกต้องเหมือนตอนใช้ `transfer` ข้ามสกุลแบบเดิม ใน ticket นี้ `transfer` ข้ามสกุลแบบเดิมยังใช้ได้อยู่ ดู spec ที่ `.scratch/foreign-currency/spec.md`

**Blocked by:** 03

**Status:** resolved

- [x] ฟอร์มแลกเงินเลือกพอร์ตหุ้น US เป็นต้นทางหรือปลายทางได้
- [x] migration ใหม่แก้ trigger ที่ sync เงินสดในพอร์ตให้ทำงานกับ `exchange` ด้วย และยังตรวจว่ายอด USD ต้องเป็นบวก
- [x] การคำนวณเงินเข้าพอร์ตสะสมและ net worth นับ `exchange`
- [x] apply migration ด้วย `supabase db push`
- [x] `dart format .` และ `tool/check_design.sh` ผ่าน


## Comments

- migration `20261103130000_sync_exchange_portfolio_cash.sql` ให้ trigger รับทั้ง transfer และ exchange (ยังไม่ได้ `supabase db push`); ฟอร์มแลกเงินเลือกพอร์ตได้
- การคำนวณเงินเข้าพอร์ตและ net worth ใช้ `usesDestinationAccount` อยู่แล้ว จึงนับ exchange โดยอัตโนมัติ
- trigger เดิม sync เงินสดเฉพาะการเติมเข้าพอร์ต (THB → US) การถอนออกจากพอร์ตยังไม่ปรับ cash_balance อัตโนมัติเหมือนพฤติกรรมเดิม
