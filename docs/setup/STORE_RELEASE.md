# Store Release Checklist

ขั้นตอนเตรียม Money Vibe ขึ้น App Store / Google Play งานในไฟล์นี้ต้องทำเองนอกโค้ด

> ทดสอบกับ Supabase project แยกก่อนตาม [STORE_TEST.md](STORE_TEST.md)

## 0. Supabase plan
- **Free:** ใช้ได้ แต่ไม่มี daily backup, project ที่ไม่มีการใช้งานประมาณ 1 สัปดาห์จะถูก pause และ**ต้องตั้ง custom SMTP** ไม่งั้นแก้ email template ไม่ได้ ([changelog](https://supabase.com/changelog/46599-changes-to-email-template-customisation-on-free-tier)) ซึ่งทำให้ลืมรหัสผ่านใช้ไม่ได้ (อีเมลจะมีแค่ลิงก์ ไม่มีรหัส OTP)
- **Pro (แนะนำสำหรับข้อมูลการเงินของผู้ใช้จริง):** มี daily backup, ไม่ pause และใช้ leaked password protection ได้
- ถ้าใช้ free ให้สำรองข้อมูลเองเป็นระยะด้วย `supabase db dump`
- ตรวจโควตาล่าสุดที่ https://supabase.com/pricing

## 1. Supabase (prod)

### Edge Functions
- [ ] ลบ function ที่เลิกใช้แล้ว (ใช้ข้อมูล Yahoo ซึ่งไม่ได้รับอนุญาต และ LLM proxy ที่เปิดให้ใครก็เรียกได้)
  ```bash
  supabase functions delete yfinance --project-ref <prod-ref>
  supabase functions delete llm-portfolio-analyze --project-ref <prod-ref>
  ```
- [ ] Deploy `mirror-stock-logo` เวอร์ชันใหม่ (`supabase/functions/mirror-stock-logo/index.ts`) ที่ต้อง login และดึงได้เฉพาะ host ของ Finnhub
- [ ] Deploy `delete-account` (`supabase/functions/delete-account/index.ts`)
- [ ] เปิด **Verify JWT** ของทั้งสอง function ไว้ (เป็นค่า default)
  ```bash
  supabase functions deploy mirror-stock-logo --project-ref <prod-ref>
  supabase functions deploy delete-account --project-ref <prod-ref>
  ```
- [ ] (เฉพาะถ้ามี web build) ตั้ง secret `ALLOWED_ORIGINS=https://your-web-domain` ถ้าไม่ตั้งไว้ function จะไม่ส่ง CORS header (แอปมือถือไม่ต้องใช้)

### Database
- [ ] รัน migration `supabase/migrations/20261006120000_harden_store_release.sql`
  - เพิ่ม `ON DELETE CASCADE` ให้ `sync_logs` (ไม่งั้นลบ user ไม่ได้)
  - แก้ trigger ของ sync log ไม่ให้ insert ระหว่างที่ user กำลังถูกลบ
  - ลบ RPC `delete_user()` ตัวเก่า
  - ตัด SVG ออกจาก bucket `stock-logos`
- [ ] (ไม่บังคับ) ลบไฟล์โลโก้เก่าที่อยู่ที่ root ของ bucket `stock-logos` (ไม่อยู่ใต้ `{uid}/`) ซึ่งสร้างจาก function เวอร์ชันเก่า

### Auth (Dashboard → Authentication)
- [ ] Minimum password length = 8 (ให้ตรงกับ validation ตอนสมัครในแอป)
- [ ] เปิด **Leaked password protection** (เฉพาะ Pro)
- [ ] ตั้ง **custom SMTP** (Authentication → SMTP Settings) **ก่อน**แก้ email template ตัวอย่างกับ Resend:
  - Host `smtp.resend.com`, Port `465`, Username `resend`, Password = Resend API key
  - Sender: ใช้อีเมลจาก domain ที่ยืนยันใน Resend แล้ว (`onboarding@resend.dev` ส่งได้เฉพาะอีเมลเจ้าของบัญชี Resend จึงใช้ได้แค่ตอนเทส)
  - เหตุผล: free tier ที่ใช้ SMTP ในตัวแก้ template ไม่ได้ และส่งอีเมลได้จำกัดมาก
- [ ] เปิด **Confirm email**
- [ ] Email Templates → **Reset Password** (หลังตั้ง custom SMTP แล้ว): ใส่รหัส `{{ .Token }}` ในเนื้อหาอีเมล (แอปให้กรอกรหัสนี้ ไม่ได้ใช้ลิงก์) เช่น `รหัสสำหรับตั้งรหัสผ่านใหม่ของคุณคือ {{ .Token }} (ใช้ได้ภายใน 1 ชั่วโมง)`
- [ ] ตรวจ rate limit ของ sign up / sign in / email
- [ ] (แนะนำ) เปิด CAPTCHA (hCaptcha/Turnstile)

## 2. Privacy Policy
- [ ] เผยแพร่หน้า Privacy Policy (ระบุว่าเก็บอีเมลและข้อมูลการเงินไว้ใน Supabase, ส่ง ticker ไป Finnhub เมื่อผู้ใช้ใส่ key เอง, ใช้ Frankfurter ดึงอัตราแลกเปลี่ยน และวิธีลบบัญชี)
- [ ] ใส่ `PRIVACY_POLICY_URL` ใน `config/prod.json` (ดู `config/prod.example.json`) แล้วลิงก์จะแสดงใน ตั้งค่า → เกี่ยวกับ
- [ ] ใส่ URL เดียวกันใน App Store Connect และ Play Console

## 3. Android (Google Play)
- [ ] สร้าง upload keystore (ครั้งเดียว และเก็บสำรองไว้ให้ดี)
  ```bash
  keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
  ```
- [ ] คัดลอก `android/key.properties.example` → `android/key.properties` แล้วกรอกค่า (ไฟล์นี้ถูก gitignore ไว้แล้ว)
- [ ] Build: `scripts/build_store.sh android`
- [ ] ตรวจ signature: `keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab`
- [ ] เปิด Play App Signing
- [ ] กรอก **Data safety**: Email, Financial info (บันทึกโดยผู้ใช้), Photos (เลือกเอง ไม่ upload ยกเว้นไอคอนบัญชี), เข้ารหัสระหว่างส่ง, ผู้ใช้ขอลบข้อมูลได้ในแอป

## 4. iOS (App Store)
- [ ] Build: `scripts/build_store.sh ios` (ใช้ `ios/ExportOptions-appstore.plist`)
- [ ] เปิด Xcode → Runner target → ตรวจว่า `PrivacyInfo.xcprivacy` อยู่ใน Copy Bundle Resources
- [ ] กรอก **App Privacy**: Email Address และ Other Financial Info (Linked to user, ไม่ใช้ tracking), Photos (App Functionality)
- [ ] ระบุใน Review Notes ว่าการลบบัญชีอยู่ที่ ตั้งค่า → บัญชีผู้ใช้ → ลบบัญชี

## 5. ทั้งสอง Store
- [ ] เพิ่มเลข `version` ใน `pubspec.yaml` (build number คำนวณจากจำนวน commit อัตโนมัติ)
- [ ] เตรียมบัญชีทดสอบที่มีข้อมูลตัวอย่างให้ reviewer
- [ ] เก็บ `build/symbols/` ของแต่ละ release ไว้ถอด stack trace (build ใช้ `--obfuscate`)

## สิ่งที่ store build (`DISTRIBUTION=store`) ซ่อนไว้
- ส่วน "การติดตั้ง" และการแจ้งเตือนให้ติดตั้งใหม่ (ใช้เฉพาะ build ที่ sideload)

## ข้อจำกัดหลังถอด Yahoo
- ราคาหุ้นอัตโนมัติใช้ Finnhub เท่านั้น (ผู้ใช้ต้องใส่ API key เอง) และไม่มีราคา Pre/Post
- พอร์ตหุ้นไทยไม่มีราคาอัตโนมัติ ต้องกรอกเองในช่อง "ราคาปัจจุบัน"
- อัตราแลกเปลี่ยน USD/THB ใช้ Frankfurter (ECB) ซึ่งอัปเดตวันละครั้ง
