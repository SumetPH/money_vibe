# AGENTS.md

แนวทางนี้ใช้เป็นกติกากลางสำหรับ Agent และ Developer ในโปรเจกต์ Money Vibe โดยเน้นให้สอดคล้องกับโค้ดและรูปแบบ UI ที่ใช้อยู่จริงในปัจจุบัน

## Design

เมื่อออกแบบหรือแก้ UI, form, modal, navigation หรือ Account flow ให้อ่าน `docs/design.md` ซึ่งเป็น source of truth ของกติกา design

## การสื่อสาร

- หากงานหรือ skill มีขั้นตอนโต้ตอบ ถามคำถาม หรืออธิบายความคืบหน้า ให้สื่อสารเป็นภาษาไทย

## ภาพรวมโปรเจกต์

- แอปนี้เป็น Flutter app สำหรับจัดการการเงินส่วนบุคคล
- ใช้ Supabase เป็น backend หลัก
- ใช้ `Provider` สำหรับ state management
- ใช้ `GoRouter` สำหรับ top-level navigation และ auth/setup redirect
- โครงสร้างข้อมูลหลักวิ่งผ่าน `DatabaseRepository` และ `SupabaseRepository`

## กฎสำคัญด้านข้อมูล

- ใช้ Supabase เท่านั้น ห้ามเพิ่มหรือพาโค้ดกลับไปพึ่ง SQLite
- หากมีการแก้ schema database ให้สร้างหรือแก้ migration ใน `supabase/migrations`
- apply migration ด้วย Supabase CLI (`supabase db push`)
- การเก็บเวลาใช้ local time ตามเครื่องผู้ใช้ คอลัมน์วันที่เวลาใช้ `timestamp without time zone`
- ห้ามแปลง timezone ไปมาเองตอนอ่านหรือเขียนข้อมูล (ห้ามเรียก `.toUtc()` / `.toLocal()`)
- serialize วันที่เวลาเข้า database ด้วย `DateTime.toIso8601String()` จาก local `DateTime` ตรง ๆ
- คอลัมน์ `tags` ของ transactions ถูกลบไปแล้ว ห้ามเพิ่มกลับหรืออ้างถึงในโค้ด
- ตารางใหม่ใน `public` ต้องมี `GRANT SELECT, INSERT, UPDATE, DELETE ... TO authenticated, service_role` ใน migration เดียวกับที่สร้างตาราง (Supabase ไม่ grant อัตโนมัติแล้ว)
- Edge Function อยู่ใน `supabase/functions/<name>/index.ts` deploy ด้วย `supabase functions deploy <name> --project-ref <ref>` (ดูขั้นตอน release ใน `docs/setup/`)

## Architecture ที่ควรยึดตาม

- เพิ่มหรือลดความสามารถด้านข้อมูลผ่าน `DatabaseRepository` ก่อน แล้วค่อย implement ใน `SupabaseRepository` หรือ adapter ที่เกี่ยวข้อง
- Logic ด้านการดึง/บันทึกข้อมูลควรอยู่ใน repository, service, provider หรือ widget helper ที่เหมาะสม ไม่ยัดไว้ใน UI ตรง ๆ
- ใช้ `Provider` เป็นทางหลักในการเชื่อม UI กับ state

## Naming และโครงสร้างไฟล์

- ไฟล์ Dart ใช้ `snake_case.dart`
- class ใช้ `PascalCase`
- ตัวแปรและเมธอดใช้ `camelCase`
- provider ลงท้ายด้วย `Provider`
- screen ลงท้ายด้วย `Screen`

### โครงสร้างไฟล์ใน `lib/screens/<module>/`

ยึดแบบ `lib/screens/cash_flow/`

- ไฟล์ screen ควรยาวไม่เกิน ~400 บรรทัด และห้ามเกิน 800 บรรทัด
- ไฟล์เดิมที่ยาวเกิน ~400 บรรทัดอยู่แล้ว ไม่ต้อง refactor แยกไฟล์ เว้นแต่ผู้ใช้สั่ง หรือการแก้ครั้งนั้นทำให้ไฟล์เกิน 800 บรรทัด
- แยก tab, section, bottom sheet, dialog, list item, summary card ออกเป็นไฟล์ของตัวเองในโฟลเดอร์ module เดียวกัน (ไม่สร้างโฟลเดอร์ย่อย) ตั้งชื่อ `<feature>_<role>.dart` เช่น `trade_annual_tax_tab.dart`
- widget ที่สั้นกว่า ~40 บรรทัดและใช้ที่เดียวไม่ต้องแยก
- class ที่แยกออกมาเป็น public พร้อม prefix ของ feature (`_MetricTile` → `BudgetMetricTile`) ห้ามใช้ `part` / `part of`
- ไฟล์ screen เก็บ `State`, lifecycle, การเชื่อม Provider, navigation และ action save/delete ส่วน widget ที่แยกออกไปรับข้อมูลและ callback
- data/aggregation class ที่ใช้เฉพาะ UI ให้อยู่ใน `<feature>_models.dart` ข้างไฟล์ screen
- widget ที่ใช้ซ้ำข้าม module ให้ย้ายไป `lib/widgets/` และบันทึกใน `docs/design.md`

## กฎสำหรับ Agent

- **On-Demand Redesign**: เมื่อผู้ใช้ส่ง `@screen` หรือ `@widget` ให้ redesign ตาม `docs/design.md` โดยรักษา **Zero Business Logic Regression** (ห้ามแก้ logic การคำนวณ, state management `Provider`, repository/database, validation หรือ debounce timer เว้นแต่ผู้ใช้สั่งโดยตรง)
- แก้เฉพาะส่วนที่เกี่ยวข้องกับงาน หลีกเลี่ยงการรื้อโค้ดส่วนอื่นโดยไม่จำเป็น
- รักษา type safety ห้ามใช้วิธีลัดอย่าง `as dynamic`
- ห้าม hard-code API key, secret หรือข้อมูลส่วนตัวลงในโค้ด
- หากมี logic ซับซ้อน ให้ใส่คอมเมนต์สั้น ๆ เท่าที่จำเป็นเพื่อช่วยการดูแลต่อ
- ไม่ต้องทดสอบผ่าน browser เว้นแต่ผู้ใช้สั่งโดยตรง
- เขียนเทสต์ตามความเหมาะสม (เช่น logic คำนวณใน service/provider) หรือตามที่ spec กำหนด ไม่บังคับ TDD
- ถ้าแก้โค้ดที่มีเทสต์อยู่แล้วใน `test/` ต้องรัน `flutter test` ให้ผ่าน และแก้เทสต์ที่พังเพราะการเปลี่ยนแปลงนั้น

## ก่อนส่งงาน

ต้องรันคำสั่งต่อไปนี้เสมอเมื่อมีการแก้โค้ด:

1. `dart format .`
2. `flutter analyze` (ต้องไม่มี error หรือ warning ใหม่)
3. `bash tool/check_design.sh` (ตรวจว่าไม่ได้สร้าง UI primitive ซ้ำแทน shared widget/token ใน `docs/design.md` บน Windows ให้รันผ่าน Git Bash)
