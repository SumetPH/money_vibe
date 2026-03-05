# Supabase Setup Guide

คู่มือการตั้งค่า Supabase สำหรับ Money Flutter App (พร้อม Authentication)

---

## ขั้นตอนที่ 1: สร้างโปรเจค Supabase

1. ไปที่ [https://supabase.com](https://supabase.com) และสร้างบัญชี (ถ้ายังไม่มี)
2. คลิก "New Project"
3. ตั้งชื่อโปรเจค (เช่น `money-flutter`)
4. ตั้งรหัสผ่านสำหรับ database (จดไว้ให้ดี)
5. เลือก Region ที่ใกล้ที่สุด (เช่น Singapore สำหรับประเทศไทย)
6. รอสักครู่ให้โปรเจคสร้างเสร็จ

---

## ขั้นตอนที่ 2: ตั้งค่า Authentication

1. ไปที่ **Authentication** ใน Supabase Dashboard
2. คลิก **Providers** จาก sidebar
3. เปิดใช้งาน **Email** provider:
   - ✅ Enable Sign up
   - ✅ Confirm email (แนะนำให้เปิดเพื่อความปลอดภัย)
   - ✅ Secure email change
   - ✅ Secure password change
4. ตั้งค่า **Site URL**:
   - ไปที่ **URL Configuration**
   - Site URL: `io.supabase.flutterquickstart://login-callback/` (สำหรับ mobile)
   - หรือ `http://localhost:3000` (สำหรับ web development)

---

## ขั้นตอนที่ 3: สร้าง Tables

1. ไปที่ **SQL Editor** ใน Supabase Dashboard
2. เปิดไฟล์ `supabase/schema.sql` จากโปรเจค Flutter
3. Copy ทั้งหมดและ Paste ลงใน SQL Editor
4. กด **Run** เพื่อสร้าง tables ทั้งหมด

### Tables ที่สร้าง:
- `accounts` - บัญชีเงิน (มี user_id)
- `categories` - หมวดหมู่รายรับ/รายจ่าย (มี user_id)
- `transactions` - ธุรกรรมการเงิน (มี user_id)
- `portfolio_holdings` - ข้อมูลการถือหุ้น (มี user_id)
- `budgets` - งบประมาณ (มี user_id)
- `recurring_transactions` - ธุรกรรมที่เกิดซ้ำ (มี user_id)
- `recurring_occurrences` - การเกิดของธุรกรรมที่ซ้ำ (มี user_id)

### ความปลอดภัย:
- **RLS (Row Level Security)** เปิดใช้งานทุก table
- Policy: `Users can only access their own data`
- แต่ละ user จะเห็นเฉพาะข้อมูลของตัวเองเท่านั้น

---

## ขั้นตอนที่ 4: หา API Credentials

1. ไปที่ **Project Settings** (เฟืองมุมขวาบน)
2. เลือก **API** จาก sidebar
3. คัดลอกค่าต่อไปนี้:

### ข้อมูลที่ต้องใช้:
- **URL**: `https://your-project-id.supabase.co`
- **anon public**: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`

---

## ขั้นตอนที่ 5: ตั้งค่าในแอพ

1. เปิดแอพ Flutter
2. ไปที่ **ตั้งค่า** → **ตั้งค่า Database**
3. ใส่ข้อมูล:
   - **Supabase URL**: วาง URL ที่คัดลอกมา
   - **Anon Key**: วาง API key ที่คัดลอกมา
4. กด **"ทดสอบ"** เพื่อตรวจสอบการเชื่อมต่อ
5. ถ้าสำเร็จ กด **"บันทึก"**
6. แอพจะพาไปหน้า **Login/Register** โดยอัตโนมัติ

---

## ขั้นตอนที่ 6: สมัครสมาชิก / เข้าสู่ระบบ

1. ที่หน้า **Login**:
   - ถ้ามีบัญชีแล้ว: กรอก Email และ Password แล้วกด **"เข้าสู่ระบบ"**
   - ถ้ายังไม่มีบัญชี: กด **"ยังไม่มีบัญชี? สมัครสมาชิก"** แล้วกรอกข้อมูล

2. หลังจาก login สำเร็จ:
   - จะเข้าสู่หน้าหลักของแอพ
   - ข้อมูลทั้งหมดจะถูกแยกตาม user

---

## การทำงานของระบบ Authentication

### Flow การใช้งาน:
```
1. เปิดแอพ
   ↓
2. ตรวจสอบ Database Mode
   ├─ SQLite → เข้าหน้าหลักเลย (ไม่ต้อง login)
   └─ Supabase → ตรวจสอบ Login
                    ├─ Logged in → เข้าหน้าหลัก
                    └─ Not logged in → แสดงหน้า Login
```

### ความปลอดภัย:
- รหัสผ่านต้องมีอย่างน้อย **6 ตัวอักษร**
- แต่ละ user เห็นเฉพาะข้อมูลของตัวเอง (RLS)
- Token จะหมดอายุอัตโนมัติและ refresh ใหม่

---

## การสลับระหว่าง SQLite และ Supabase

- ไปที่ **ตั้งค่า** → **ตั้งค่า Database**
- กดปุ่ม **SQLite** หรือ **Supabase** เพื่อสลับโหมด
- หรือแตะที่การ์ดแสดงโหมดปัจจุบัน

### หมายเหตุ:
- ถ้าสลับเป็น **Supabase** จะต้อง **Login** ก่อนใช้งาน
- ถ้าสลับเป็น **SQLite** จะใช้งานได้ทันที (ข้อมูล local)

---

## การย้ายข้อมูล (ถ้ามีข้อมูลเดิมใน SQLite)

1. ตั้งค่า Supabase ให้เรียบร้อย
2. สมัครสมาชิก / เข้าสู่ระบบ
3. ไปที่ **ตั้งค่า** → **สำรองและกู้คืนข้อมูล**
4. กด **"ย้ายข้อมูลไป Supabase"**
5. รอให้การย้ายข้อมูลเสร็จสิ้น
6. ข้อมูลจะถูกเชื่อมโยงกับบัญชีผู้ใช้ปัจจุบัน

---

## การทำงานร่วมกัน

| ฟีเจอร์ | SQLite | Supabase |
|---------|--------|----------|
| ไม่ต้องใช้อินเทอร์เน็ต | ✅ | ❌ |
| Sync ข้ามอุปกรณ์ | ❌ | ✅ |
| ความเร็ว | เร็ว (local) | ขึ้นกับ internet |
| สำรองข้อมูล | Manual | Auto (cloud) |
| แยกข้อมูลต่อ user | ❌ | ✅ |
| Authentication | ไม่ต้อง | ต้อง Login |

---

## แก้ไขปัญหาเบื้องต้น

### ไม่สามารถเชื่อมต่อ Supabase ได้
- ตรวจสอบว่าใส่ URL และ Anon Key ถูกต้อง
- ตรวจสอบ internet connection
- ตรวจสอบว่า tables ถูกสร้างครบใน Supabase

### ย้ายข้อมูลไม่สำเร็จ
- ตรวจสอบว่าเชื่อมต่อ Supabase ได้
- ตรวจสอบว่า login แล้ว
- ตรวจสอบว่า tables ว่างเปล่า (ไม่มีข้อมูลซ้ำ)

### ไม่สามารถ Login ได้
- ตรวจสอบ email และ password
- ตรวจสอบว่า email ได้รับการยืนยันแล้ว (ถ้าเปิดใช้งาน)
- ลองกด **"ลืมรหัสผ่าน"** เพื่อรีเซ็ต

### ข้อมูลไม่แสดงหลัง Login
- ตรวจสอบว่า user มีข้อมูลหรือไม่
- ถ้าเพิ่งสมัครใหม่ ข้อมูลจะว่างเปล่า (ปกติ)
- ถ้าย้ายข้อมูลแล้วแต่ไม่เห็น ให้ pull to refresh

---

## หมายเหตุด้านความปลอดภัย

- ✅ ใช้ **Email/Password Authentication**
- ✅ **RLS Policies** แยกข้อมูลต่อ user
- ✅ ข้อมูลถูกเข้ารหัสใน transit (HTTPS)
- ✅ รหัสผ่านถูก hash ก่อนเก็บ (Supabase จัดการให้)

---

## DateTime Handling

- **SQLite**: เก็บเป็น ISO8601 String (e.g., `2026-03-05T10:30:00.000`)
- **Supabase**: เก็บเป็น `timestamp without time zone` (เวลา local โดยตรง)
- ไม่มีการแปลง timezone เก็บเวลาตามเครื่องผู้ใช้เลย
- Logic การคำนวณและแสดงผลทำงานเหมือนกันทั้งสองโหมด

---

*Last updated: 2026-03-05*
