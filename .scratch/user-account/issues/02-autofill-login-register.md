# 02: Autofill ฟอร์มเข้าสู่ระบบและสมัคร

**What to build:** password manager ของ Android, iOS และ Web เติมอีเมลและรหัสผ่านในหน้าเข้าสู่ระบบให้ได้ เสนอรหัสผ่านที่แข็งแรงในหน้าสมัคร และถามว่าจะบันทึกรหัสผ่านหลัง login หรือสมัครสำเร็จ

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] ฟอร์มเข้าสู่ระบบอยู่ใน `AutofillGroup` ใช้ hints email และ password
- [ ] ฟอร์มสมัครอยู่ใน `AutofillGroup` ใช้ hints email, newPassword และ username
- [ ] เรียก `TextInput.finishAutofillContext()` เมื่อ login หรือสมัครสำเร็จ
- [ ] ทดสอบด้วยมือแล้วว่า password manager บันทึกและเติมรหัสได้บน Android, iOS และ Web
- [ ] `dart format .` และ `tool/check_design.sh` ผ่าน
