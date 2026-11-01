# 08: คู่มือ setup ระบบบัญชีผู้ใช้

**What to build:** นักพัฒนาเปิด env ใหม่ (dev หรือ prod) ให้ใช้ระบบบัญชีผู้ใช้ได้ครบด้วยการทำตามคู่มือทีละขั้น โดยไม่ต้องเดาเอง

**Blocked by:** 03, 04, 06, 07

**Status:** resolved

- [x] คู่มือ Google Auth ใหม่ใน `docs/setup` ครอบคลุมเรื่องต่อไปนี้
  - การสร้าง OAuth client แบบ Web, Android (SHA-1 ของ debug และ release ต่อ flavor) และ iOS แยกกันสำหรับ dev และ prod
  - การใส่ Client ID และ Secret ใน Supabase Google provider และเรื่อง nonce ของ iOS
  - การเปิด Allow manual linking
  - การเพิ่ม Redirect URLs สำหรับ web
  - การใส่ key ใน config และ URL scheme ของ iOS
- [x] อัปเดต SUPABASE_SETUP.md ดังนี้
  - เปิด Confirm email
  - template "Confirm signup" และ "Reauthentication" แสดง `{{ .Token }}`
  - Secure password change
- [x] README ลิงก์ไปคู่มือใหม่
- [x] เนื้อหาตรงกับที่ implement จริงใน ticket 03–07


## Comments

- สร้าง docs/setup/GOOGLE_AUTH_SETUP.md อัปเดต SUPABASE_SETUP.md และ README ให้ตรงกับ config, URL scheme, OTP และ implementation ปัจจุบัน พร้อม checklist ตรวจ flow จริง
- ตรวจอัตโนมัติ: dart format ., tool/check_design.sh และ flutter analyze --no-pub ผ่าน; flutter test --no-pub ผ่านทั้งหมด 50 tests ไม่เพิ่ม unit test ใหม่และไม่ได้ทดสอบผ่าน browser
