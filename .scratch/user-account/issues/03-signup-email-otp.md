# 03: สมัครด้วยรหัสผ่านต้องยืนยันอีเมลด้วย OTP และกันอีเมลซ้ำ

**What to build:** ผู้ใช้ใหม่ที่สมัครด้วยรหัสผ่านต้องได้รับรหัส OTP ทางอีเมล กรอกในแอปแล้วจึงเข้าสู่ระบบ ถ้าไม่ได้รหัสก็ขอใหม่ได้ ผู้ใช้ที่สมัครไว้แต่ยังไม่ยืนยันอีเมลแล้วมา login จะถูกพาไปยืนยันอีเมล การสมัครด้วยอีเมลที่มีบัญชีผู้ใช้อยู่แล้วจะถูกปฏิเสธด้วยข้อความกลาง ๆ ที่ไม่บอกช่องทาง (ตาม ADR 0002 ที่ต้องพิสูจน์ความเป็นเจ้าของอีเมลก่อนเปิดการเชื่อมช่องทางอัตโนมัติ)

**Blocked by:** 01

**Status:** ready-for-human

- [ ] ฝั่ง dashboard: เปิด Confirm email และให้ template "Confirm signup" แสดง `{{ .Token }}` (ผู้ใช้ทำเอง ให้แจ้งก่อนทดสอบ)
- [x] หลังสมัครแอปไม่ signOut แล้ว แต่พาไปขั้นตอนกรอก OTP ที่แยกเป็นไฟล์ใน module auth และใช้ hint oneTimeCode
- [x] AuthProvider มี `verifySignUpCode` (ใช้ `verifyOTP` type signup) และ `resendSignUpCode` (ใช้ `resend` type signup) ยืนยันสำเร็จแล้วถือว่าเข้าสู่ระบบ
- [x] OTP ผิดหรือหมดอายุขึ้นข้อความภาษาไทย และขอรหัสใหม่ได้ (เคารพ rate limit)
- [x] login เจอ error "Email not confirmed" แล้วพาไปขั้นตอนยืนยันอีเมลของอีเมลนั้นได้
- [x] สมัครด้วยอีเมลซ้ำ ไม่ว่าจะได้ user ที่ `identities` ว่าง หรือได้ error "User already registered" ให้ขึ้นข้อความ "อีเมลนี้มีบัญชีผู้ใช้แล้ว ลองเข้าสู่ระบบด้วยรหัสผ่านหรือ Google"
- [ ] ทดสอบด้วยมือบน Supabase dev ว่า flow สมัครครบ และสมัครซ้ำได้ข้อความที่ถูกต้อง
- [x] `dart format .` และ `tool/check_design.sh` ผ่าน


## Comments

- เพิ่ม OTP signup, resend พร้อม cooldown, รับ email_not_confirmed จาก login และข้อความสมัครซ้ำกลาง ๆ ต้องเปิด Confirm email และ template Confirm signup ให้แสดง {{ .Token }} ก่อนทดสอบ ยังไม่ได้สมัครบัญชี dev จริง
- ตรวจอัตโนมัติ: dart format ., tool/check_design.sh และ flutter analyze --no-pub ผ่าน; flutter test --no-pub ผ่านทั้งหมด 50 tests ไม่เพิ่ม unit test ใหม่และไม่ได้ทดสอบผ่าน browser
