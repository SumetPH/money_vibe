# 02: บัญชีสกุลต่างประเทศพร้อม rate อัตโนมัติ

**What to build:** ผู้ใช้สร้างบัญชี (เช่น กระเป๋าเงินสด) สกุล JPY, EUR, GBP, CNY, KRW, SGD ได้ บัญชีที่ไม่ใช่ THB และเปิดอัปเดต rate อัตโนมัติจะได้ rate ล่าสุดเทียบ THB และ net worth แปลงบัญชีเหล่านี้เป็น THB ถูกต้อง ดู spec ที่ `.scratch/foreign-currency/spec.md`

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] registry มีสกุล THB, USD, JPY, EUR, GBP, CNY, KRW, SGD โดย JPY/KRW ไม่มีทศนิยม
- [ ] ตัวเลือกสกุลตอนสร้างหรือแก้บัญชีแสดงทุกสกุลใน registry
- [ ] ดึง rate เทียบ THB ได้ทุกสกุล และดึงครั้งเดียวต่อสกุลแม้มีหลายบัญชี
- [ ] ทุกบัญชีที่ไม่ใช่ THB และเปิด auto-update ได้ rate ใหม่ ถ้าดึงไม่สำเร็จให้ใช้ rate เดิมต่อ
- [ ] ยอดบัญชีและ net worth แสดงถูกต้องตามจำนวนทศนิยมของแต่ละสกุล
- [ ] `dart format .` และ `tool/check_design.sh` ผ่าน
