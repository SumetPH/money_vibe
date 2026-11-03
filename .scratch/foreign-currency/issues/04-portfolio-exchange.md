# 04: เติมและถอนเงินพอร์ตหุ้น US ด้วย `exchange`

**What to build:** ผู้ใช้เติม THB เข้าพอร์ตหุ้น US หรือถอน USD ออกเป็น THB ด้วยรายการแลกเงินได้ เงินสด USD ในพอร์ต เงินเข้าพอร์ตสะสม และ net worth ต้องถูกต้องเหมือนตอนใช้ `transfer` ข้ามสกุลแบบเดิม ใน ticket นี้ `transfer` ข้ามสกุลแบบเดิมยังใช้ได้อยู่ ดู spec ที่ `.scratch/foreign-currency/spec.md`

**Blocked by:** 03

**Status:** ready-for-agent

- [ ] ฟอร์มแลกเงินเลือกพอร์ตหุ้น US เป็นต้นทางหรือปลายทางได้
- [ ] migration ใหม่แก้ trigger ที่ sync เงินสดในพอร์ตให้ทำงานกับ `exchange` ด้วย และยังตรวจว่ายอด USD ต้องเป็นบวก
- [ ] การคำนวณเงินเข้าพอร์ตสะสมและ net worth นับ `exchange`
- [ ] apply migration ด้วย `supabase db push`
- [ ] `dart format .` และ `tool/check_design.sh` ผ่าน
