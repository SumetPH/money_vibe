# 06: ตั้งรหัสผ่านสำหรับบัญชีผู้ใช้ที่มีแค่ Google

**What to build:** ผู้ใช้ที่มีแค่ช่องทาง Google กด "ตั้งรหัสผ่าน" ในตั้งค่า กรอกรหัสใหม่และยืนยันรหัสใหม่ ถ้า Supabase ขอให้ยืนยันตัวตนซ้ำ (Secure password change) แอปจะส่งรหัสทางอีเมลให้กรอกในขั้นตอนเดียวกัน ตั้งเสร็จแล้วเมนูเปลี่ยนเป็น "เปลี่ยนรหัสผ่าน" และ login ด้วยอีเมลและรหัสผ่านได้

**Blocked by:** 04, 05

**Status:** ready-for-human

- [x] AuthProvider มี `setPassword(newPassword, {nonce})` ถ้าได้ error ว่าต้อง reauthenticate ให้เรียก `reauthenticate()` แล้วให้ UI ขอรหัสมาเรียกซ้ำพร้อม nonce
- [ ] ฝั่ง dashboard: template "Reauthentication" แสดง `{{ .Token }}` (แจ้งผู้ใช้)
- [x] ฟอร์มตั้งรหัสผ่านรองรับ autofill (hints newPassword และ oneTimeCode สำหรับรหัสยืนยัน)
- [x] สำเร็จแล้วโหลด `hasPassword` ใหม่ และเมนูเปลี่ยนเป็น "เปลี่ยนรหัสผ่าน"
- [ ] ทดสอบด้วยมือแล้ว: สมัครด้วย Google → ตั้งรหัสผ่าน → logout → login ด้วยรหัสผ่านได้
- [ ] บันทึกผลการตรวจลงใน Comments ว่าหลังตั้งรหัสผ่าน identities มีกี่ตัว (มีผลกับปุ่มยกเลิกการเชื่อมใน ticket 07)
- [x] `dart format .` และ `tool/check_design.sh` ผ่าน


## Comments

- เพิ่ม setPassword พร้อม nonce, reauthenticate และขอรหัสใหม่ในฟอร์ม ใช้ has_password RPC ยืนยันสถานะหลังบันทึก ต้องตั้ง Reauthentication template ให้แสดง {{ .Token }} จำนวน identities หลังตั้งรหัสผ่าน: ยังไม่ได้ตรวจจริง เพราะไม่มีบัญชี Google ทดสอบ จึงไม่บันทึกตัวเลขสมมติ
- ตรวจอัตโนมัติ: dart format ., tool/check_design.sh และ flutter analyze --no-pub ผ่าน; flutter test --no-pub ผ่านทั้งหมด 50 tests ไม่เพิ่ม unit test ใหม่และไม่ได้ทดสอบผ่าน browser
