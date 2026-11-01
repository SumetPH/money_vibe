# 08: คู่มือ setup ระบบบัญชีผู้ใช้

**What to build:** นักพัฒนาเปิด env ใหม่ (dev หรือ prod) ให้ใช้ระบบบัญชีผู้ใช้ได้ครบด้วยการทำตามคู่มือทีละขั้น โดยไม่ต้องเดาเอง

**Blocked by:** 03, 04, 06, 07

**Status:** ready-for-agent

- [ ] คู่มือ Google Auth ใหม่ใน `docs/setup` ครอบคลุมเรื่องต่อไปนี้
  - การสร้าง OAuth client แบบ Web, Android (SHA-1 ของ debug และ release ต่อ flavor) และ iOS แยกกันสำหรับ dev และ prod
  - การใส่ Client ID และ Secret ใน Supabase Google provider และเรื่อง nonce ของ iOS
  - การเปิด Allow manual linking
  - การเพิ่ม Redirect URLs สำหรับ web
  - การใส่ key ใน config และ URL scheme ของ iOS
- [ ] อัปเดต SUPABASE_SETUP.md ดังนี้
  - เปิด Confirm email
  - template "Confirm signup" และ "Reauthentication" แสดง `{{ .Token }}`
  - Secure password change
- [ ] README ลิงก์ไปคู่มือใหม่
- [ ] เนื้อหาตรงกับที่ implement จริงใน ticket 03–07
