# 04: เข้าสู่ระบบด้วย Google (Android, iOS, Web)

**What to build:** ผู้ใช้กด "ดำเนินการต่อด้วย Google" ได้ทั้งในแท็บเข้าสู่ระบบและแท็บสมัคร ถ้ายังไม่มีบัญชีผู้ใช้จะสร้างให้ ถ้าอีเมลตรงกับบัญชีผู้ใช้เดิมจะเข้าบัญชีผู้ใช้เดิมและเห็นข้อมูลเดิม คนที่ยังไม่มี username จะได้ username อัตโนมัติจากชื่อ Google หรือส่วนหน้า @ ของอีเมล บน web กลับมาที่แอปหลัง redirect การ logout และการลบบัญชีล้างการเลือกบัญชี Google ด้วย บน desktop หรือ env ที่ไม่มี Client ID จะไม่เห็นปุ่ม

**Blocked by:** 01, 03

**Status:** ready-for-human

- [x] เพิ่ม dependency `google_sign_in` และตรวจว่า `supabase_flutter` รองรับ `signInWithIdToken`/`linkIdentityWithIdToken` ถ้าไม่รองรับให้ upgrade
- [x] เพิ่ม key `GOOGLE_WEB_CLIENT_ID` และ `GOOGLE_IOS_CLIENT_ID` ใน config ของทุก env และไฟล์ example ไม่ hard-code
- [x] iOS ใส่ reversed client ID เป็น URL scheme ของแต่ละ flavor
- [x] AuthProvider มี `signInWithGoogle()`
  - มือถือ: ใช้ native แล้วเรียก `signInWithIdToken`
  - Web: ใช้ `signInWithOAuth` โดย `redirectTo` เป็น origin ปัจจุบัน
  - ผู้ใช้กดยกเลิก: คืนค่า false โดยไม่มี error
- [x] ตั้ง username จาก `full_name`/`name` ถ้าไม่มีใช้ส่วนหน้า @ ของอีเมล และตั้งเฉพาะเมื่อยังไม่มี username
- [x] `signOut()` และ `deleteAccount()` เรียก `GoogleSignIn.signOut()` บนมือถือ
- [x] ปุ่ม Google แยกเป็น widget ของ module auth มีเส้นคั่น "หรือ" แสดงทั้งสองแท็บ และซ่อนเมื่อเป็น desktop หรือไม่มี Client ID
- [x] error ภาษาไทยสำหรับ login ด้วย Google ไม่สำเร็จ
- [ ] ทดสอบด้วยมือแล้ว
  - สมัครใหม่ด้วย Google
  - สมัครด้วยรหัสผ่าน (ยืนยันอีเมลแล้ว) จากนั้น login ด้วย Google ที่อีเมลเดียวกัน แล้วได้บัญชีผู้ใช้เดิม
  - ทำงานบน Android, iOS และ Web
- [x] `dart format .` และ `tool/check_design.sh` ผ่าน


## Comments

- เพิ่ม google_sign_in 7.2.0, native ID/access token, Web OAuth, username fallback, ล้างสถานะ Google หลัง logout/delete และ config ทุก env พร้อม iOS URL scheme แยก flavor ยังไม่มี Google Client IDs สำหรับตรวจบน Android/iOS/Web จริง; flutter pub add ดาวน์โหลดแล้ว แต่แจ้งว่าเครื่อง Windows ยังไม่เปิด symlink support
- ตรวจอัตโนมัติ: dart format ., tool/check_design.sh และ flutter analyze --no-pub ผ่าน; flutter test --no-pub ผ่านทั้งหมด 50 tests ไม่เพิ่ม unit test ใหม่และไม่ได้ทดสอบผ่าน browser
