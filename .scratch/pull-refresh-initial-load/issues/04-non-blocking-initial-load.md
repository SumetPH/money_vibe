# 04: ปล่อย splash เร็ว ให้ Initial Load ไม่บล็อกตอนเปิดแอปและหลัง login

**What to build:** หลังเปิดแอปหรือ login ให้ผู้ใช้เห็นหน้าจอได้ทันที แต่ละหน้าแสดง skeleton จนกว่าข้อมูลของหน้านั้นจะครบ แต่ import และ clear data ยังต้องรอโหลดเสร็จเหมือนเดิม รายละเอียดดูหัวข้อ "Initial Load" และ "Further Notes" ใน `../spec.md`

**Blocked by:** 03

**Status:** done

- [x] ตอนเปิดแอป รอแค่ settings, auth และ debug bootstrap จากนั้นรัน app และปล่อย splash ทันที Initial Load ไปทำงานต่อเบื้องหลัง
- [x] ถ้า Initial Load ล้มเหลว แอปยังทำงานต่อได้ และหน้าที่เกี่ยวข้องแสดง error state
- [x] หลัง login ให้สั่ง Initial Load โดยไม่ await แล้วพาไปหน้าหลักทันที
- [x] import และ clear data ยัง await Initial Load จนเสร็จ
- [x] Background Sync ยังไม่เริ่มทำงานจนกว่า Initial Load จะตั้ง baseline เสร็จ เหมือนเดิม
- [x] ตรวจว่า recurring notification และ reinstall reminder ต้องใช้ข้อมูลจาก provider หรือไม่ ถ้าต้องใช้ ให้รันหลัง Initial Load ของ module ที่เกี่ยวข้องเสร็จ
- [ ] ลองเปิดแอปทั้งตอน online และ offline: ไม่มีหน้าไหนแสดง empty state ก่อนข้อมูลมาถึง
- [ ] logout แล้ว login ด้วยบัญชีอื่น: สถานะทั้งหมดเริ่มใหม่ และไม่มีข้อมูลของบัญชีก่อนหน้าค้างอยู่
- [x] `dart format .` และ `tool/check_design.sh` ผ่าน

## Comments

- recurring notification และ reinstall reminder ไม่ได้ใช้ข้อมูลจาก provider (recurring provider reschedule notification ตอนที่ตัวเอง init อยู่แล้ว) จึงไม่ต้องย้ายลำดับ
- ยังไม่ได้รันแอปจริงเพื่อทดสอบเคส online/offline และการสลับบัญชี ข้อนี้ต้องให้คนตรวจด้วยมือ
