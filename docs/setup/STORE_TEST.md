# Store Test (Supabase Free)

ทดสอบ store build กับ Supabase project ใหม่บน free tier ก่อนทำตาม [STORE_RELEASE.md](STORE_RELEASE.md) กับ prod

> ใช้ project แยกสำหรับทดสอบเสมอ ห้ามใช้ project ที่มีข้อมูลจริง (การทดสอบรวมถึงการลบบัญชี)

## 1. เตรียม project ทดสอบ

1. สร้าง project ใหม่ใน Dashboard (free tier สร้างได้ 2 project)
2. Link แล้วสร้าง schema ทั้งหมด (database ว่าง จึง push ได้เลยโดยไม่ต้อง `migration repair`)
   ```bash
   supabase link --project-ref <test-ref>
   supabase db push
   ```
3. Deploy Edge Functions
   ```bash
   supabase functions deploy mirror-stock-logo --project-ref <test-ref>
   supabase functions deploy delete-account --project-ref <test-ref>
   ```
4. Authentication
   - Minimum password length = 8
   - **Custom SMTP (จำเป็นถ้าจะเทสลืมรหัสผ่าน):** free tier ที่ใช้ SMTP ในตัวแก้ email template ไม่ได้ อีเมลรีเซ็ตจะมีแค่ลิงก์ ไม่มีรหัส OTP ([changelog](https://supabase.com/changelog/46599-changes-to-email-template-customisation-on-free-tier))
     - Authentication → SMTP Settings → เปิด Custom SMTP
     - Resend: Host `smtp.resend.com`, Port `465`, Username `resend`, Password = API key
     - Sender `onboarding@resend.dev` ใช้เทสได้ แต่ส่งได้เฉพาะอีเมลที่ใช้สมัคร Resend จึงต้องสมัครบัญชีทดสอบในแอปด้วยอีเมลนั้น
   - **Confirm email**: ถ้ายังไม่ได้ตั้ง custom SMTP ให้ปิดไว้ระหว่างทดสอบ
   - Leaked password protection ใช้ได้เฉพาะ Pro จึงข้ามได้
   - Email Templates → **Reset Password** (หลังตั้ง custom SMTP แล้ว): ใส่ `{{ .Token }}` ในเนื้อหาอีเมล แล้วขอรหัสใหม่จากแอป (อีเมลเก่าที่ได้ไปแล้วยังเป็นแบบลิงก์)
5. ใส่ค่าของ project ทดสอบใน `config/dev.json`
   ```json
   {
     "APP_ENV": "dev",
     "SUPABASE_URL": "https://<test-ref>.supabase.co",
     "SUPABASE_ANON_KEY": "<anon key>",
     "PRIVACY_POLICY_URL": "https://example.com/privacy"
   }
   ```
6. รันแอปแบบ store build
   ```bash
   flutter run --dart-define-from-file=config/dev.json --dart-define=DISTRIBUTION=store
   ```

## 2. ตรวจ database หลัง push

รันใน SQL Editor:

```sql
-- ต้องได้ 'c' (ON DELETE CASCADE)
select confdeltype from pg_constraint where conname = 'sync_logs_user_id_fkey';

-- ต้องไม่มี image/svg+xml
select allowed_mime_types from storage.buckets where id = 'stock-logos';

-- ต้องได้ 0 (RPC เก่าถูกลบแล้ว)
select count(*) from pg_proc where proname = 'delete_user';
```

## 3. Checklist การทดสอบในแอป

### Auth
- [ ] สมัครด้วยรหัสผ่านสั้นกว่า 8 ตัว → ถูกปฏิเสธ
- [ ] สมัครด้วยรหัสผ่าน 8 ตัวขึ้นไป → สำเร็จ
- [ ] Login ผิดรหัส → ข้อความภาษาไทยที่ไม่มี exception ดิบ
- [ ] ลืมรหัสผ่าน: กรอกอีเมล → ได้อีเมลที่มีรหัสยืนยัน → เปิดหน้า "ตั้งรหัสผ่านใหม่"
- [ ] กรอกรหัสผิด → "รหัสยืนยันไม่ถูกต้องหรือหมดอายุ" และยังอยู่หน้าเดิม
- [ ] รหัสผ่านใหม่สั้นกว่า 8 ตัว หรือช่องยืนยันไม่ตรง → ถูกปฏิเสธ
- [ ] กรอกรหัสถูก → กลับหน้า login พร้อมข้อความให้เข้าสู่ระบบ (ไม่ถูก login อัตโนมัติ) แล้ว login ด้วยรหัสใหม่ได้
- [ ] กด "ส่งอีกครั้ง" ถี่ ๆ → ข้อความให้รอสักครู่ (Supabase จำกัดการขอรหัสประมาณ 60 วินาทีต่อครั้ง)

### Store build ซ่อนฟีเจอร์ถูกต้อง
- [ ] Settings ไม่มี toggle Yahoo, LLM API Key และหมวด "การติดตั้ง"
- [ ] Settings → เกี่ยวกับ มี "นโยบายความเป็นส่วนตัว" และกดแล้วเปิด browser
- [ ] เมนูพอร์ตไม่มี "วิเคราะห์พอร์ต"

### ราคาและอัตราแลกเปลี่ยน
- [ ] พอร์ตสหรัฐฯ ที่ยังไม่ใส่ Finnhub key → กดรีเฟรชแล้วมีข้อความให้ใส่ key และไม่ crash
- [ ] ใส่ Finnhub key → รีเฟรชแล้วได้ราคาและโลโก้
- [ ] ตรวจใน Storage ว่าโลโก้อยู่ที่ `stock-logos/{user_id}/TICKER.png`
- [ ] พอร์ตหุ้นไทย → รีเฟรชแล้วไม่ดึงราคา และแก้ "ราคาปัจจุบัน" เองได้
- [ ] บัญชี USD ที่เปิด auto update rate → ได้อัตรา USD/THB (จาก Frankfurter)
- [ ] ปิดแอปแล้วเปิดใหม่ → Finnhub key ยังอยู่ (เก็บใน secure storage)

### ลบบัญชี
1. เตรียมข้อมูลให้ครบทุกโมดูล: บัญชี (อัปโหลดรูปไอคอน), ธุรกรรม, หมวดหมู่, งบประมาณ, รายการประจำ, พอร์ตพร้อมหุ้น, Cash-flow และ planned purchase
2. ทดสอบ:
   - [ ] พิมพ์อีเมลผิดใน dialog → ไม่ลบ และมีข้อความ "อีเมลไม่ตรงกัน"
   - [ ] พิมพ์อีเมลถูก → ลบสำเร็จแล้วกลับไปหน้า login
   - [ ] Login ด้วยบัญชีเดิม → ไม่ได้ (user ถูกลบแล้ว)
3. ตรวจใน Dashboard:
   - [ ] Authentication → Users ไม่มี user นี้
   - [ ] Storage → ไม่มีโฟลเดอร์ `{user_id}` ใน `account-icons` และ `stock-logos`
   - [ ] ทุกตารางไม่มีแถวของ user นี้
     ```sql
     select 'accounts', count(*) from accounts where user_id = '<uid>'
     union all select 'transactions', count(*) from transactions where user_id = '<uid>'
     union all select 'sync_logs', count(*) from sync_logs where user_id = '<uid>'
     union all select 'planned_purchases', count(*) from planned_purchases where user_id = '<uid>';
     ```

### Edge Function security
หา anon key จาก Dashboard → Project Settings → API แล้วเรียกโดยไม่ login:

```bash
curl -i -X POST "https://<test-ref>.supabase.co/functions/v1/mirror-stock-logo" \
  -H "Authorization: Bearer <anon key>" -H "Content-Type: application/json" \
  -d '{"ticker":"AAPL","sourceUrl":"https://static2.finnhub.io/file/publicdatany/finnhubimage/stock_logo/AAPL.png"}'
# ต้องได้ 401

curl -i -X POST "https://<test-ref>.supabase.co/functions/v1/delete-account" \
  -H "Authorization: Bearer <anon key>"
# ต้องได้ 401
```

ใช้ access token ของ user ที่ login แล้ว (ดูจาก log ตอน debug หรือ sign in ผ่าน REST) ทดสอบ input ที่ต้องถูกปฏิเสธ:

- [ ] `"ticker":"../x"` → 400
- [ ] `"sourceUrl":"https://example.com/logo.png"` → 400
- [ ] `"sourceUrl":"http://static2.finnhub.io/..."` (ไม่ใช่ https) → 400

### Android build
- [ ] `scripts/build_store.sh android dev` ได้ `.aab` ที่ sign ด้วย upload key
- [ ] ติดตั้งผ่าน Play Console → Internal testing แล้วลองใช้งานตาม checklist ข้างบน

### iOS build
- [ ] `scripts/build_store.sh ios dev` ได้ `.ipa`
- [ ] อัปโหลดขึ้น TestFlight แล้วลองเลือกรูปไอคอนบัญชี ต้องมีข้อความขอสิทธิ์ภาษาไทยและไม่ crash

## 4. หลังทดสอบเสร็จ
- **link กลับไป prod ก่อนรันคำสั่ง CLI กับ prod:** `supabase link --project-ref <prod-ref>` (`supabase link` ผูก repo ไว้กับ project ล่าสุดที่ link ถ้าลืม `db push` ครั้งต่อไปจะไปเข้า project ทดสอบ)
- คืนค่า `config/dev.json` ถ้าเคยชี้ไป project อื่น
- project ทดสอบที่ไม่มีการใช้งานประมาณ 1 สัปดาห์จะถูก pause อัตโนมัติ (เปิดกลับได้จาก Dashboard) หรือลบทิ้งได้
- ทำตาม [STORE_RELEASE.md](STORE_RELEASE.md) กับ project prod
