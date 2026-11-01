# 01: Prefactor: ให้ SyncProvider เก็บ Data Readiness และให้ Initial Load รับ loader แยกตาม module

**What to build:** `SyncProvider` ต้องรู้ว่าแต่ละ module อยู่ในสถานะไหน มีสี่ค่า: ยังไม่โหลด, กำลังโหลด, พร้อม, ล้มเหลว ทั้งนี้เพื่อให้ ticket ถัดไปใช้แยก skeleton, error และข้อมูลจริงออกจากกันได้ ฝั่งผู้ใช้ยังไม่เห็นอะไรเปลี่ยน เพราะ splash ยังรอให้ Initial Load เสร็จก่อนเหมือนเดิม รายละเอียดดูหัวข้อ "Data Readiness อยู่ใน `SyncProvider`" และ "Initial Load" ใน `../spec.md`

**Blocked by:** None (can start immediately)

**Status:** done

- [x] `initialize` รับ loader เป็น map จาก `SyncModule` ไปหา loader แทนการรับ closure เดียว และยังโหลดทุก module ขนานกันเหมือนเดิม
- [x] ถ้า loader ของ module หนึ่งล้มเหลว module อื่นต้องโหลดต่อได้ module ที่ล้มเหลวมีสถานะ "ล้มเหลว" ส่วนที่สำเร็จมีสถานะ "พร้อม" และบันทึก baseline timestamp ให้เฉพาะ module ที่สำเร็จ
- [x] `portfolio` ใช้สถานะเดียวกับ `accounts`
- [x] มี getter สำหรับดูสถานะรวมของ set ของ module: ถ้ามีตัวไหนล้มเหลวถือว่าล้มเหลว ถ้าทุกตัวพร้อมถือว่าพร้อม นอกจากนั้นถือว่ากำลังโหลด
- [x] เรียก `notifyListeners` ทุกครั้งที่สถานะเปลี่ยน
- [x] `reset()` ทำให้ทุก module กลับไปเป็น "ยังไม่โหลด"
- [x] จุดที่เรียก `initialize` อยู่แล้ว (ตอนเปิดแอป, หลัง login, import และ clear data) เปลี่ยนมาใช้ signature ใหม่ และยังรอให้โหลดเสร็จเหมือนเดิม
- [x] เคสเดิมใน `test/sync_provider_test.dart` แก้ให้ใช้ signature ใหม่แล้วผ่านทั้งหมด
- [x] `dart format .` และ `tool/check_design.sh` ผ่าน

## Comments

- ทำต่างจาก spec ไปหนึ่งจุด: `loaders` ส่งเข้ามาทาง constructor ของ `SyncProvider` ส่วน `initialize()` ไม่รับ argument แล้ว เหตุผลคือเดิมมีสามที่ (main, login, import/clear) ที่สร้าง list ของ reload ซ้ำกัน และ `reload()` กับ `init()` ของทุก provider ก็ทำงานเหมือนกันอยู่แล้ว (accounts ดึงอัตราแลกเปลี่ยนใหม่ด้วย) Manual Refresh จึงใช้ `loaders` ชุดนี้ได้เลย ไม่ต้องมี `manualRefreshers`
- ถ้า Background Sync refresh module ที่สถานะ "ล้มเหลว" ได้สำเร็จ module นั้นจะเปลี่ยนเป็น "พร้อม"
