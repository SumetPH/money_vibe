# 07: เชื่อมและยกเลิกการเชื่อม Google ในตั้งค่า

**What to build:** กลุ่ม "ช่องทางเข้าสู่ระบบ" มีแถว Google เพิ่ม
- **ยังไม่เชื่อม:** มีปุ่ม "เชื่อม Google" ใช้ได้บนมือถือและ web โดยอนุญาตเฉพาะ Google ที่อีเมลตรงกับอีเมลหลักของบัญชีผู้ใช้ (ADR 0002)
- **เชื่อมแล้ว:** แสดงอีเมล Google และปุ่ม "ยกเลิกการเชื่อม" ซึ่งแสดงเฉพาะตอนที่บัญชีผู้ใช้มี identity ตั้งแต่ 2 ตัว และต้องยืนยันก่อนกด หลังยกเลิกยัง login ด้วยรหัสผ่านได้

ซ่อนแถวนี้บน desktop และใน env ที่ไม่มี Client ID

**Blocked by:** 04, 05

**Status:** ready-for-human

- [ ] ฝั่ง dashboard: เปิด Allow manual linking (แจ้งผู้ใช้)
- [x] AuthProvider มี `linkedGoogleIdentity` และ `canUnlinkGoogle` อ่านจาก `user.identities` และฟัง `userUpdated` เพื่ออัปเดตค่า
- [x] `linkGoogle()`
  - มือถือ: ตรวจอีเมลจาก Google ก่อน แล้วเรียก `linkIdentityWithIdToken`
  - Web: ใช้ `linkIdentity` แบบ redirect แล้วตรวจอีเมลหลังกลับมา ถ้าไม่ตรงให้ unlink ทันทีและแจ้ง error
- [x] Error ที่ต้องแสดง
  - อีเมลไม่ตรง: "ต้องใช้บัญชี Google ที่อีเมลตรงกับบัญชีผู้ใช้"
  - Google ผูกกับบัญชีผู้ใช้อื่นแล้ว: "บัญชี Google นี้ถูกใช้กับบัญชีผู้ใช้อื่นแล้ว"
- [x] `unlinkGoogle()` ใช้ `unlinkIdentity` แล้ว `GoogleSignIn.signOut()` และต้องมี confirm dialog ก่อน
- [ ] ทดสอบด้วยมือแล้ว
  - เชื่อม Google ที่อีเมลตรง: สำเร็จ
  - เชื่อม Google ที่อีเมลไม่ตรง: ถูกปฏิเสธ
  - เชื่อม Google ที่ผูกบัญชีผู้ใช้อื่นอยู่แล้ว: ขึ้น error
  - ยกเลิกการเชื่อมแล้ว login ด้วยรหัสผ่านได้
  - ปุ่มยกเลิกการเชื่อมซ่อนตอนมี identity เดียว
  - ทำงานทั้งบนมือถือและ web
- [x] `dart format .` และ `tool/check_design.sh` ผ่าน


## Comments

- เพิ่ม link/unlink, ตรวจอีเมลบนมือถือก่อน link และ rollback Google ต่างอีเมลหลัง callback บนเว็บ, userUpdated refresh, ยืนยันก่อน unlink และ guard identities >= 2 ต้องเปิด Allow manual linking ใน Dashboard ก่อนทดสอบจริง
- ตรวจอัตโนมัติ: dart format ., tool/check_design.sh และ flutter analyze --no-pub ผ่าน; flutter test --no-pub ผ่านทั้งหมด 50 tests ไม่เพิ่ม unit test ใหม่และไม่ได้ทดสอบผ่าน browser
