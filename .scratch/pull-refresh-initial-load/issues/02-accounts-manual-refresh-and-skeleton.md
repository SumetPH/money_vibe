# 02: Manual Refresh, skeleton และ error state บนหน้า Accounts (tracer bullet)

**What to build:** ทำ Manual Refresh, skeleton และ error state ให้ครบบนหน้าเดียวก่อน คือหน้า Accounts
- ผู้ใช้ดึงหน้า Accounts ลง (หรือกดปุ่ม refresh บนจอกว้าง) แล้ว accounts กับ transactions ต้องโหลดใหม่ พร้อมอัตราแลกเปลี่ยน USD ล่าสุด
- ถ้าข้อมูลยังไม่พร้อม หน้านี้แสดง skeleton
- ถ้า Initial Load ล้มเหลว เช่นเปิดแอปตอน offline หน้านี้แสดง error state พร้อมปุ่ม "ลองใหม่" แทนหน้าว่าง

รายละเอียดดูหัวข้อ "Manual Refresh" และ "UI" ใน `../spec.md`

**Blocked by:** 01

**Status:** ready-for-agent

Manual Refresh (`SyncProvider`)
- [ ] `refresh(modules)` force reload ทุก module ที่ส่งเข้ามา โดยไม่ดู `sync_logs` และไม่สน cooldown
- [ ] Manual Refresh ใช้ `loaders` ตัวเดียวกับ Initial Load (ดูหมายเหตุใน ticket 01) เพราะ loader ของ accounts ดึงอัตราแลกเปลี่ยน USD ใหม่อยู่แล้ว จึงไม่ต้องมี `manualRefreshers`
- [ ] ถ้า Background Sync กำลังทำงาน ให้รอรอบนั้นเสร็จก่อน ถ้า Initial Load กำลังทำงาน ให้รอรอบนั้นแล้ว reload เฉพาะ module ที่ยังไม่พร้อม
- [ ] อ่าน `sync_logs` ก่อน reload แล้วบันทึก timestamp เฉพาะ module ที่ reload สำเร็จ เพื่อให้ Background Sync รอบถัดไปไม่ reload ซ้ำ
- [ ] ถ้า module ที่พร้อมอยู่แล้ว refresh ล้มเหลว ให้คงสถานะ "พร้อม" ไว้และ throw ออกไป ถ้า module ที่ล้มเหลวอยู่ refresh สำเร็จ ให้เปลี่ยนเป็น "พร้อม"
- [ ] ถ้ามีการเรียก refresh ด้วย set เดียวกันซ้อนกัน ให้ใช้ Future ตัวเดียวกัน

UI หน้า Accounts
- [ ] `RefreshIndicator` ดึงได้ในทุก state ทั้งปกติ, skeleton และ error
- [ ] จอกว้าง (≥800px) มีปุ่ม refresh ใน app bar ที่ใช้ shared app bar button และแสดงสถานะ busy ระหว่าง refresh
- [ ] ถ้า Manual Refresh ล้มเหลว แสดง SnackBar และคงข้อมูลเดิมไว้
- [ ] มี shared widget ของ skeleton (แบบนิ่ง ไม่มี shimmer, ใช้ token สีของ theme ทั้ง light และ dark) และของ error state (ข้อความกับปุ่ม "ลองใหม่") ใน `lib/widgets/` พร้อมบันทึกใน `docs/design.md`
- [ ] หน้า Accounts แสดง skeleton จนกว่า accounts และ transactions จะพร้อมทั้งคู่ ระหว่างนั้นไม่แสดง empty state
- [ ] ถ้ามี module ล้มเหลว แสดง error state ปุ่ม "ลองใหม่" สั่ง Manual Refresh ของหน้านี้
- [ ] ปุ่มเพิ่ม, แก้ไข และ reorder ของหน้านี้ disabled ไว้จนกว่าข้อมูลจะพร้อม ส่วน navigation ยังใช้ได้ตามปกติ
- [ ] เก็บชุด module ของแต่ละหน้า (ตามตารางใน spec) ไว้ในที่เดียว เพื่อให้ ticket 03 ใช้ต่อได้
- [ ] ไฟล์ screen ยาวไม่เกินที่ `AGENTS.md` กำหนด
- [ ] `dart format .` และ `tool/check_design.sh` ผ่าน
