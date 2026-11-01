# ตั้งค่าบัญชีผู้ใช้และ Google Sign-In

ทำแยกสำหรับ dev และ prod โดยใช้ Google Cloud project และ Supabase project ของ env เดียวกัน แอปรองรับ Android, iOS และ Web; ซ่อน Google บน desktop และเมื่อ Client ID ยังว่าง

## 1. เตรียม Supabase

1. ตั้งค่า Email ตาม [SUPABASE_SETUP.md](SUPABASE_SETUP.md): เปิด Confirm email, ตั้ง template Confirm signup, Reset Password และ Reauthentication ให้แสดง `{{ .Token }}` และเปิด Secure password change
2. Login CLI และผูก dev project ก่อน:

   ```sh
   supabase login
   supabase link --project-ref <dev-project-ref>
   supabase db push
   ```

   หากไม่ได้ติดตั้ง CLI ใช้ `npx --yes supabase` แทน `supabase` ได้ การ push ใช้ migrations ทุกไฟล์ที่ยังไม่ apply; ตรวจ project ที่ผูกก่อนทุกครั้ง
3. Migration `20261101000000_add_has_password.sql` เพิ่ม RPC `public.has_password()` เฉพาะผู้ใช้ที่ login แล้ว โดยคืนเพียง boolean ของผู้ใช้ปัจจุบัน
4. เปิด Allow manual linking ใน Authentication เพื่อให้ผู้ใช้เชื่อม Google จากหน้าตั้งค่าได้

## 2. เตรียม Google Cloud

1. เปิด Google Auth Platform ของ project สำหรับ env นั้น กรอก Branding และ Audience; ระหว่าง Testing เพิ่มอีเมลที่จะทดสอบเป็น Test users
2. ใช้ scopes `openid`, `email`, `profile` ไม่ต้องขอสิทธิ์ Gmail หรือ Drive
3. สร้าง OAuth client ชนิด **Web application** ตั้งชื่อให้แยก dev/prod
4. เพิ่ม Authorized redirect URI เป็น callback จาก Supabase Google provider: `https://<project-ref>.supabase.co/auth/v1/callback` ค่านี้เป็น callback ฝั่ง Supabase ไม่ใช่ URL หน้าแอป
5. เก็บ Web Client ID สำหรับ config แอป ส่วน Client Secret ใส่เฉพาะ Supabase Dashboard ห้ามใส่ใน repo หรือ config ที่ build เข้าแอป

## 3. Android

1. สร้าง OAuth client แบบ Android โดยใช้ package name ของ flavor:
   - dev: `app.sumetph.moneyvibe.dev`
   - prod: `app.sumetph.moneyvibe`
2. ใช้ `cd android` แล้ว `./gradlew signingReport` (Windows ใช้ `gradlew.bat signingReport`) เพื่อดู SHA-1 ของแต่ละ variant
3. ลงทะเบียนแต่ละคู่ package/SHA-1 ที่ใช้งานจริง รวม debug และ release ของทั้งสอง flavor หากส่งผ่าน Play Store ให้เพิ่ม SHA-1 ของ App signing certificate จาก Play Console ด้วย
4. แอปส่ง Web Client ID เป็น `serverClientId` ให้ `google_sign_in` จึงไม่ต้องเพิ่ม Android Client ID ลง Dart config และไม่ต้องแก้ Android manifest

## 4. iOS

1. สร้าง OAuth client แบบ iOS สองตัว โดยใช้ bundle ID `app.sumetph.moneyvibe.dev` และ `app.sumetph.moneyvibe`
2. ใส่ iOS Client ID ของ env นั้นใน `GOOGLE_IOS_CLIENT_ID`
3. คัดลอก `ios/Flutter/GoogleAuth.example.xcconfig` เป็น `ios/Flutter/GoogleAuth.xcconfig` แล้วกรอก:

   ```xcconfig
   GOOGLE_REVERSED_CLIENT_ID_DEV = com.googleusercontent.apps.<dev-ios-client-id-prefix>
   GOOGLE_REVERSED_CLIENT_ID_PROD = com.googleusercontent.apps.<prod-ios-client-id-prefix>
   ```

   ตัวอย่างเช่น Client ID `123-abc.apps.googleusercontent.com` จะกลับเป็น `com.googleusercontent.apps.123-abc` ใช้ค่าจริงจาก iOS client ของ Google
4. Debug/Release xcconfig รวมไฟล์นี้ไว้แล้ว และ Runner build settings เลือกค่าตาม flavor ผ่าน `GOOGLE_REVERSED_CLIENT_ID`; Info.plist นำไปใช้เป็น URL scheme ไฟล์ค่าจริงถูก gitignore; ใน CI ให้สร้างไฟล์นี้ก่อน build
5. แอปส่ง `clientId` และ `serverClientId` ผ่าน Dart จึงไม่ต้องเพิ่ม GIDClientID/GIDServerClientID ใน plist อีก

เมื่อยังไม่ตั้งค่า Google ไฟล์ build ใช้ URL scheme สำรอง `moneyvibe-google-disabled-dev` / `moneyvibe-google-disabled-prod` เพื่อไม่ให้ plist มี scheme ว่าง ค่านี้ใช้ login ไม่ได้ ให้แทนที่ด้วย reversed client ID จริงก่อนเปิด Google ใน config

## 5. เปิด Google provider ใน Supabase

1. เปิด Authentication → Sign In / Providers → Google
2. ใส่ Web Client ID และ Web Client Secret ของ env เดียวกัน แล้วเพิ่ม iOS/Android client IDs ที่ใช้ในรายการ Client IDs ที่ยอมรับ โดยคง Web Client ID เป็นตัวแรกสำหรับ OAuth บนเว็บ
3. Native flow ใช้ `google_sign_in` 7.x แล้วส่ง ID token และ access token ไป Supabase; SDK ฝั่ง iOS ไม่ได้ให้แอปส่ง nonce ของตนเองใน flow นี้ จึงตั้ง Skip nonce check ตามคู่มือ Supabase Flutter สำหรับ iOS
4. ตรวจว่า Confirm email เปิดอยู่ก่อนเปิด automatic linking เพื่อป้องกันผู้ที่สมัครด้วยอีเมลคนอื่นล่วงหน้า
5. Manual linking บนมือถือเทียบอีเมลแบบไม่สนตัวพิมพ์ก่อน link บนเว็บตรวจหลัง callback และ unlink ทันทีหากอีเมลไม่ตรง บัญชี Google ที่ผูกกับผู้ใช้อื่นจะแสดง error ภาษาไทย

## 6. Config และ Web redirect

1. ใส่ค่าใน `config/dev.json` และ `config/prod.json` โดยคัดลอกจากไฟล์ example:

   ```json
   {
     "GOOGLE_WEB_CLIENT_ID": "<web-client-id>",
     "GOOGLE_IOS_CLIENT_ID": "<ios-client-id>"
   }
   ```

   นี่เป็นเฉพาะ key ที่เพิ่ม ให้คง APP_ENV และ Supabase config เดิมไว้ Client ID เป็นค่าของแต่ละ env; ไม่ใส่ Client Secret ในไฟล์นี้ ปล่อย Client ID ว่างได้หากยังไม่เปิด Google
2. Build/run ด้วย `--dart-define-from-file=config/dev.json` และ `--flavor dev` บนมือถือ (prod ใช้ prod ทั้งสองตำแหน่ง)
3. ใน Supabase → URL Configuration ตั้ง Site URL เป็น origin ของเว็บ และเพิ่ม Redirect URLs ของ dev/prod ที่ใช้จริง เช่น `http://localhost:3000` และ `https://<production-host>`
4. ใช้ port คงที่เมื่อทดสอบเว็บ: `flutter run -d chrome --web-port 3000 --dart-define-from-file=config/dev.json`
5. เว็บใช้ Supabase OAuth redirect ไป `Uri.base.origin` ทั้ง login และ link; link จะจำ user ID ที่เริ่ม flow ไว้ในเครื่องและกลับหน้าตั้งค่าหลังโหลดใหม่ ไม่ต้องใส่ client secret ในเว็บหรือเพิ่ม Google JavaScript SDK

## 7. ตรวจด้วยบัญชี dev จริงก่อนเปิดใช้งาน

- สมัครด้วยรหัสผ่าน → รับ OTP → กรอกผิด/หมดอายุ → ขอใหม่ → ยืนยันสำเร็จ และ login บัญชีที่ยังไม่ยืนยันต้องกลับมาขั้นตอน OTP ได้
- สมัครอีเมลซ้ำต้องเห็นข้อความกลาง ๆ ไม่บอกว่าบัญชีเดิมใช้ช่องทางใด
- สมัครด้วย Google แล้วตรวจ username; login ด้วย Google อีเมลเดียวกับบัญชีรหัสผ่านที่ยืนยันแล้วต้องได้ user ID และข้อมูลการเงินชุดเดิม ชื่อเดิมต้องไม่ถูกทับ
- เปลี่ยนรหัสผ่าน: รหัสเดิมผิดต้องถูกปฏิเสธ รหัสใหม่สั้น/ซ้ำ/ไม่ตรงกัน/รั่วไหลต้องมีข้อความไทย ตรวจว่า session บนอีกเครื่องยังใช้ได้
- Google-only → ตั้งรหัสผ่าน → กรอก nonce หาก Supabase ขอ → เมนูเปลี่ยนเป็น “เปลี่ยนรหัสผ่าน” → logout → login ด้วยรหัสใหม่ รวมการสร้างรหัสผ่านผ่าน “ลืมรหัสผ่าน”
- ตรวจ `user.identities.length` หลังตั้งรหัสผ่านและบันทึกเฉพาะจำนวนใน Comments ของ issue 06 ห้ามเดาว่าจะมี email identity เพิ่มเอง ปุ่ม unlink แสดงเมื่อมีอย่างน้อย 2 identities ตาม response จริง
- เชื่อม Google อีเมลตรง/ไม่ตรง/ที่ผูกบัญชีอื่น ทดสอบยกเลิกการเชื่อมและ login ด้วยรหัสผ่านต่อ ตรวจ callback กลับหน้าตั้งค่าบนเว็บ
- ยกเลิกหน้าเลือก Google ต้องไม่ขึ้น error; ทดสอบเน็ตหลุด, logout และลบบัญชี แล้วครั้งถัดไปเลือก Google account ใหม่ได้
- ตรวจ password manager บน Android/iOS/Web ว่าเติม บันทึก และเสนอรหัสใหม่ได้ รวม light/dark และคีย์บอร์ดบนจอเล็ก

## เอกสารอ้างอิง

- [Supabase: Google Sign-In](https://supabase.com/docs/guides/auth/social-login/auth-google)
- [Supabase Flutter: native Google flow](https://github.com/supabase/supabase-flutter/tree/main/packages/supabase_flutter)
- [Flutter: google_sign_in](https://pub.dev/packages/google_sign_in)
- [Flutter: iOS URL scheme](https://pub.dev/packages/google_sign_in_ios)
