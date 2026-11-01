# 05: กลุ่ม "ช่องทางเข้าสู่ระบบ" ในตั้งค่า และเปลี่ยนรหัสผ่าน

**What to build:** ในส่วนบัญชีผู้ใช้ของหน้าตั้งค่า เพิ่มกลุ่ม "ช่องทางเข้าสู่ระบบ" ที่มีแถวรหัสผ่าน ผู้ใช้ที่มีรหัสผ่านกด "เปลี่ยนรหัสผ่าน" ได้ โดยกรอกรหัสปัจจุบัน รหัสใหม่ และยืนยันรหัสใหม่ เปลี่ยนแล้วเครื่องอื่นยังไม่ถูก logout ผู้ใช้ที่ยังไม่มีรหัสผ่านจะเห็นเมนู "ตั้งรหัสผ่าน" แทน ส่วนการทำงานของเมนูนั้นอยู่ใน ticket 06

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

- [ ] migration ใหม่สร้าง `public.has_password()` แบบ `security definer` และ `stable` คืนว่า `encrypted_password` ของ `auth.uid()` ไม่เป็น null และไม่ว่าง โดย `GRANT EXECUTE` ให้ `authenticated` และ revoke จาก `anon`/`public` จากนั้น apply ด้วย `supabase db push`
- [ ] AuthProvider มี state `hasPassword` โหลดตอน init, ตอน signedIn และหลังเปลี่ยนรหัสสำเร็จ
- [ ] AuthProvider มี `changePassword(currentPassword, newPassword)` ตรวจรหัสเดิมด้วย `signInWithPassword` ก่อน แล้วจึง `updateUser`
- [ ] ฟอร์มเปลี่ยนรหัสผ่านใช้ pattern เดียวกับ settings sheets ที่มีอยู่ และใช้ `AutofillGroup` (hints password, newPassword) เรียก `finishAutofillContext()` เมื่อเปลี่ยนสำเร็จ
- [ ] กรณีรหัสเดิมผิด, รหัสใหม่ไม่ตรงกัน, รหัสสั้นไป, ซ้ำรหัสเดิม หรือเคยรั่วไหล ขึ้นข้อความภาษาไทย
- [ ] แถวรหัสผ่านแสดง "เปลี่ยนรหัสผ่าน" หรือ "ตั้งรหัสผ่าน" ตาม `hasPassword`
- [ ] ทดสอบด้วยมือแล้ว: เปลี่ยนรหัส, logout แล้ว login ด้วยรหัสใหม่ได้, และรหัสเดิมผิดถูกปฏิเสธ
- [ ] `dart format .` และ `tool/check_design.sh` ผ่าน
