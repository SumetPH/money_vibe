# Supabase Setup Guide

คู่มือการตั้งค่า Supabase สำหรับ Money Flutter App

## ขั้นตอนที่ 1: สร้างโปรเจค Supabase

1. ไปที่ [https://supabase.com](https://supabase.com) และสร้างบัญชี (ถ้ายังไม่มี)
2. คลิก "New Project"
3. ตั้งชื่อโปรเจค (เช่น `money-flutter`)
4. ตั้งรหัสผ่านสำหรับ database (จดไว้ให้ดี)
5. เลือก Region ที่ใกล้ที่สุด (เช่น Singapore สำหรับประเทศไทย)
6. รอสักครู่ให้โปรเจคสร้างเสร็จ

## ขั้นตอนที่ 2: สร้าง Tables

1. ไปที่ SQL Editor ใน Supabase Dashboard
2. เปิดไฟล์ `supabase/schema.sql` จากโปรเจค Flutter
3. Copy ทั้งหมดและ Paste ลงใน SQL Editor
4. กด "Run" เพื่อสร้าง tables ทั้งหมด

หรือรันทีละส่วน:
```sql
-- 1. สร้าง accounts table
-- 2. สร้าง categories table
-- 3. สร้าง transactions table
-- 4. สร้าง portfolio_holdings table
-- 5. สร้าง budgets table
-- 6. สร้าง recurring_transactions table
-- 7. สร้าง recurring_occurrences table
-- 8. สร้าง triggers
```

## ขั้นตอนที่ 3: หา API Credentials

1. ไปที่ Project Settings (เฟืองมุมขวาบน)
2. เลือก "API" จาก sidebar
3. คัดลอกค่าต่อไปนี้:

### ข้อมูลที่ต้องใช้:
- **URL**: `https://your-project-id.supabase.co`
- **anon public**: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`

## ขั้นตอนที่ 4: ตั้งค่าในแอพ

1. เปิดแอพ Flutter
2. ไปที่ **ตั้งค่า** → **ตั้งค่า Database**
3. ใส่ข้อมูล:
   - **Supabase URL**: วาง URL ที่คัดลอกมา
   - **Anon Key**: วาง API key ที่คัดลอกมา
4. กด "ทดสอบ" เพื่อตรวจสอบการเชื่อมต่อ
5. ถ้าสำเร็จ กด "บันทึก"

## ขั้นตอนที่ 5: ย้ายข้อมูล (ถ้ามีข้อมูลเดิมใน SQLite)

1. อยู่ในหน้าตั้งค่า Database
2. กด "ย้ายข้อมูลไป Supabase"
3. รอให้การย้ายข้อมูลเสร็จสิ้น
4. แอพจะสลับไปใช้ Supabase โดยอัตโนมัติ

## การสลับระหว่าง SQLite และ Supabase

- ไปที่ **ตั้งค่า** → **ตั้งค่า Database**
- กดปุ่ม **SQLite** หรือ **Supabase** เพื่อสลับโหมด
- หรือแตะที่การ์ดแสดงโหมดปัจจุบัน

## การทำงานร่วมกัน

| ฟีเจอร์ | SQLite | Supabase |
|---------|--------|----------|
| ไม่ต้องใช้อินเทอร์เน็ต | ✅ | ❌ |
| Sync ข้ามอุปกรณ์ | ❌ | ✅ |
| ความเร็ว | เร็ว (local) | ขึ้นกับ internet |
| สำรองข้อมูล | Manual | Auto (cloud) |

## แก้ไขปัญหาเบื้องต้น

### ไม่สามารถเชื่อมต่อ Supabase ได้
- ตรวจสอบว่าใส่ URL และ Anon Key ถูกต้อง
- ตรวจสอบ internet connection
- ตรวจสอบว่า tables ถูกสร้างครบใน Supabase

### ย้ายข้อมูลไม่สำเร็จ
- ตรวจสอบว่าเชื่อมต่อ Supabase ได้
- ตรวจสอบว่า tables ว่างเปล่า (ไม่มีข้อมูลซ้ำ)
- ลองล้างข้อมูลใน Supabase แล้วย้ายใหม่

## หมายเหตุด้านความปลอดภัย

- ปัจจุบันใช้ Anonymous Auth (ไม่ต้อง login)
- Row Level Security (RLS) เปิดใช้งานแล้วแต่อนุญาตทุก operation
- ถ้าต้องการความปลอดภัยสูงขึ้น ควรเพิ่ม Authentication

## DateTime Handling

- **SQLite**: เก็บเป็น ISO8601 String (e.g., `2026-03-05T10:30:00.000`)
- **Supabase**: เก็บเป็น `timestamp without time zone` (เวลา local โดยตรง)
- ไม่มีการแปลง timezone เก็บเวลาตามเครื่องผู้ใช้เลย
- Logic การคำนวณและแสดงผลทำงานเหมือนกันทั้งสองโหมด
