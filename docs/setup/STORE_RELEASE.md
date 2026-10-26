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
- [ ] ตรวจ signature: `keytool -printcert -jarfile build/app/outputs/bundle/prodRelease/app-prod-release.aab`
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
- ตัวเลือกแหล่งราคาหุ้น Yahoo Finance; Settings และ service บังคับใช้ Finnhub แม้เคยเลือก Yahoo ไว้

## แหล่งราคาหุ้น
- Store build ใช้ Finnhub เท่านั้น (ผู้ใช้ต้องใส่ API key เอง)
- Build ส่วนตัว/sideload เลือก Yahoo ได้ที่ ตั้งค่า → API → ปิด "ใช้ Finnhub ดึงราคาหุ้น"; ค่าเริ่มต้นยังเป็น Finnhub
- Yahoo ใช้ `GET https://query1.finance.yahoo.com/v8/finance/chart/{symbol}?interval=1d&range=1d` โดยอ่าน `regularMarketPrice` และคำนวณเปอร์เซ็นต์เทียบ `chartPreviousClose` (สำรองด้วย `previousClose`)
- ไม่มีราคา Pre/Post; โลโก้/ชื่อบริษัทยังใช้ Finnhub และอัตราแลกเปลี่ยนยังใช้ Frankfurter
- Yahoo ล้มเหลวให้คงราคาเดิมตามกติกา snapshot ครบทั้งพอร์ต; ไม่มีการสลับผู้ให้บริการอัตโนมัติ
- พอร์ตหุ้นไทยไม่มีราคาอัตโนมัติ ต้องกรอกเองในช่อง "ราคาปัจจุบัน"
- Yahoo เป็น endpoint ไม่เป็นทางการ อาจถูกจำกัดหรือเปลี่ยนรูปแบบได้
- Flutter Web build ส่วนตัวเรียก Yahoo ตรงไม่ได้ (ไม่มี CORS header) จึงเรียกผ่าน edge function `yahoo-quote` (ต้อง login) แทน; Store build ไม่เรียก function นี้เลย
  - deploy ไป project ที่ web build ส่วนตัวใช้: `supabase functions deploy yahoo-quote --project-ref <ref>`
  - ตั้ง secret `ALLOWED_ORIGINS` ให้มี origin ของ web (เช่น `http://localhost:5000,https://your-web-domain`) ไม่งั้น browser ยังบล็อก CORS

### สถานะการเชื่อม Yahoo สำหรับ build ส่วนตัว

ครบด้านโค้ด 3/3 · ยังไม่ยืนยัน live service และ Store binary

| ส่วนจาก UI/design | ทำถึงไหน | ขาด/ครบ | หมายเหตุ |
| --- | --- | --- | --- |
| เลือกแหล่งราคา | UI มีแล้ว; บันทึก preference ผ่าน Provider | ครบ | ซ่อนและบังคับ Finnhub ใน Store |
| ราคาหุ้น US และ % เปลี่ยนแปลง | UI เดิม; API เชื่อมแล้ว | ครบ | ตรวจ local ตามบันทึกด้านล่าง |
| ข้อมูลว่าง/โหลดไม่ครบ | UI เดิม; API คืนผลล้มเหลวและคงราคาเก่า | ครบ | ใช้กติกา snapshot เดิม |

ตรวจ UI เทียบ `docs/design.md` โดยใช้ `SettingsToggleTile` เดิม ไม่มี mock; ไม่รวมการคืนราคา Pre/Post หรือราคาหุ้นไทย

ผลตรวจ 2026-10-16: `dart format .` (เรียก Dart SDK โดยตรงเพราะ Flutter wrapper เขียน cache นอก sandbox), `tool/check_design.sh`, static analysis ของไฟล์ที่แก้ และ assert self-check ชั่วคราวของ quote mapping/flag ทั้งส่วนตัวและ Store ผ่านแล้ว ไม่ได้เพิ่ม unit test หรือทดสอบ browser ตามกติกาโปรเจกต์

Live probe ของ Yahoo สำหรับ AAPL ได้ HTTP 429 จากเครือข่ายที่ตรวจ จึงยังไม่ยืนยัน live success หรือความเร็วช่วงตลาดเปิด และยังไม่ได้ build IPA/AAB จริง
