# 02: Autofill ฟอร์มเข้าสู่ระบบและสมัคร

**What to build:** password manager ของ Android, iOS และ Web เติมอีเมลและรหัสผ่านในหน้าเข้าสู่ระบบให้ได้ เสนอรหัสผ่านที่แข็งแรงในหน้าสมัคร และถามว่าจะบันทึกรหัสผ่านหลัง login หรือสมัครสำเร็จ

**Blocked by:** 01

**Status:** ready-for-human

- [x] ฟอร์มเข้าสู่ระบบอยู่ใน `AutofillGroup` ใช้ hints email และ password
- [x] ฟอร์มสมัครอยู่ใน `AutofillGroup` ใช้ hints email, newPassword และ username
- [x] เรียก `TextInput.finishAutofillContext()` เมื่อ login หรือสมัครสำเร็จ
- [ ] ทดสอบด้วยมือแล้วว่า password manager บันทึกและเติมรหัสได้บน Android, iOS และ Web
- [x] `dart format .` และ `tool/check_design.sh` ผ่าน


## Comments

- เพิ่ม AutofillGroup แบบ cancel เมื่อออกจากฟอร์ม และ hints email/password/newPassword/username พร้อม finishAutofillContext หลังสำเร็จ ยังไม่ได้ตรวจ password manager บน Android/iOS/Web จริง
- ตรวจอัตโนมัติ: dart format ., tool/check_design.sh และ flutter analyze --no-pub ผ่าน; flutter test --no-pub ผ่านทั้งหมด 50 tests ไม่เพิ่ม unit test ใหม่และไม่ได้ทดสอบผ่าน browser
