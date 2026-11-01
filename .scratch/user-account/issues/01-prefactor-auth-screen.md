# 01: Prefactor: แยก auth screen

**What to build:** แยกฟอร์มเข้าสู่ระบบและฟอร์มสมัครออกจากหน้า auth เป็น widget ของ module auth ตามกติกาโครงสร้างไฟล์ใน AGENTS.md เพื่อเตรียมที่ให้ ticket ต่อ ๆ ไปเพิ่ม autofill, ขั้นตอน OTP และปุ่ม Google ได้ โดยหน้า auth ไม่เกินเพดานความยาว ผู้ใช้ต้องไม่เห็นความเปลี่ยนแปลงใด ๆ

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

- [ ] ฟอร์มเข้าสู่ระบบและฟอร์มสมัครแยกเป็น widget public ที่มี prefix ของ feature โดยรับข้อมูลและ callback จากหน้า screen
- [ ] หน้า screen ยังถือ State, การเชื่อม Provider และ navigation ตามเดิม
- [ ] หน้า auth ยาวไม่เกิน ~400 บรรทัด
- [ ] พฤติกรรมเดิมทำงานเหมือนเดิมทั้งหมด ได้แก่ login, สมัคร, ลืมรหัสผ่าน, validation และข้อความ error
- [ ] `dart format .` และ `tool/check_design.sh` ผ่าน
