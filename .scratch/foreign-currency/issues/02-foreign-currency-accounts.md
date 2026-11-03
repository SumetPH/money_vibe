# 02: บัญชีสกุลต่างประเทศพร้อม rate อัตโนมัติ

**What to build:** ผู้ใช้สร้างบัญชี (เช่น กระเป๋าเงินสด) สกุล JPY, EUR, GBP, CNY, KRW, SGD ได้ บัญชีที่ไม่ใช่ THB และเปิดอัปเดต rate อัตโนมัติจะได้ rate ล่าสุดเทียบ THB และ net worth แปลงบัญชีเหล่านี้เป็น THB ถูกต้อง ดู spec ที่ `.scratch/foreign-currency/spec.md`

**Blocked by:** 01

**Status:** resolved

- [x] registry มีสกุล THB, USD, JPY, EUR, GBP, CNY, KRW, SGD โดย JPY/KRW ไม่มีทศนิยม
- [x] ตัวเลือกสกุลตอนสร้างหรือแก้บัญชีแสดงทุกสกุลใน registry
- [x] ดึง rate เทียบ THB ได้ทุกสกุล และดึงครั้งเดียวต่อสกุลแม้มีหลายบัญชี
- [x] ทุกบัญชีที่ไม่ใช่ THB และเปิด auto-update ได้ rate ใหม่ ถ้าดึงไม่สำเร็จให้ใช้ rate เดิมต่อ
- [x] ยอดบัญชีและ net worth แสดงถูกต้องตามจำนวนทศนิยมของแต่ละสกุล
- [x] `dart format .` และ `tool/check_design.sh` ผ่าน


## Comments

- เพิ่ม 6 สกุลใน registry, `ExchangeRateService.fetchRateToThb`, `AccountProvider` refresh ทุกสกุลต่างประเทศ (ครั้งเดียวต่อสกุล) ตอนโหลด และหลังสร้างบัญชี/เปลี่ยนสกุล/เปิด auto-update; ยอดคงเหลือในฟอร์มรายการแสดงตามสกุลของบัญชี; ฟอร์มบัญชีแสดงส่วน "อัตราแลกเปลี่ยน" สำหรับทุกสกุลต่างประเทศ
