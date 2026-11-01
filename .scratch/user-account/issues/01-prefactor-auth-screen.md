# 01: Prefactor: แยก auth screen

**What to build:** แยกฟอร์มเข้าสู่ระบบและฟอร์มสมัครออกจากหน้า auth เป็น widget ของ module auth ตามกติกาโครงสร้างไฟล์ใน AGENTS.md เพื่อเตรียมที่ให้ ticket ต่อ ๆ ไปเพิ่ม autofill, ขั้นตอน OTP และปุ่ม Google ได้ โดยหน้า auth ไม่เกินเพดานความยาว ผู้ใช้ต้องไม่เห็นความเปลี่ยนแปลงใด ๆ

**Blocked by:** None (can start immediately)

**Status:** resolved

- [x] ฟอร์มเข้าสู่ระบบและฟอร์มสมัครแยกเป็น widget public ที่มี prefix ของ feature โดยรับข้อมูลและ callback จากหน้า screen
- [x] หน้า screen ยังถือ State, การเชื่อม Provider และ navigation ตามเดิม
- [x] หน้า auth ยาวไม่เกิน ~400 บรรทัด
- [x] พฤติกรรมเดิมทำงานเหมือนเดิมทั้งหมด ได้แก่ login, สมัคร, ลืมรหัสผ่าน, validation และข้อความ error
- [x] `dart format .` และ `tool/check_design.sh` ผ่าน


## Comments

- แยก AuthCredentialsForm และ AuthForgotPasswordDialog ออกจาก screen โดย State/Provider/navigation ยังอยู่ใน AuthScreen; screen เหลือ 354 บรรทัด ตรวจด้วย analyzer และ design check แล้ว
- ตรวจอัตโนมัติ: dart format ., tool/check_design.sh และ flutter analyze --no-pub ผ่าน; flutter test --no-pub ผ่านทั้งหมด 50 tests ไม่เพิ่ม unit test ใหม่และไม่ได้ทดสอบผ่าน browser
