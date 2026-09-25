# AGENTS.md

แนวทางนี้ใช้เป็นกติกากลางสำหรับ Agent และ Developer ในโปรเจกต์ Money Vibe โดยเน้นให้สอดคล้องกับโค้ดและรูปแบบ UI ที่ใช้อยู่จริงในปัจจุบัน

## Agent skills

### Issue tracker

ติดตาม issues เป็น Local Markdown ใต้ `.scratch/` ดูรายละเอียดที่ `docs/agents/issue-tracker.md`

### Triage labels

ใช้ triage labels มาตรฐานทั้งห้ารายการ ดูรายละเอียดที่ `docs/agents/triage-labels.md`

### Domain docs

ใช้โครงสร้าง domain docs แบบ single-context ดูรายละเอียดที่ `docs/agents/domain.md`

### Design

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
- หากมีการสร้างหรือแก้ migration ต้องอัปเดต `supabase/init_schema.sql` ให้รวม schema ล่าสุดด้วยเสมอ
- การเก็บเวลาใช้ local time ตามเครื่องผู้ใช้
- ห้ามแปลง timezone ไปมาเองตอนอ่านหรือเขียนข้อมูล
- ใช้ ISO8601 เมื่อต้อง serialize วันที่เวลาเข้า database
- ห้ามใช้งานคอลัมน์ `tags` ของ transactions

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

## กฎสำหรับ Agent

- **On-Demand Redesign**: เมื่อผู้ใช้ส่ง `@screen` หรือ `@widget` ให้ redesign ตาม `docs/design.md` โดยรักษา **Zero Business Logic Regression** (ห้ามแก้ logic การคำนวณ, state management `Provider`, repository/database, validation หรือ debounce timer เว้นแต่ผู้ใช้สั่งโดยตรง)
- แก้เฉพาะส่วนที่เกี่ยวข้องกับงาน หลีกเลี่ยงการรื้อโค้ดส่วนอื่นโดยไม่จำเป็น
- รักษา type safety ห้ามใช้วิธีลัดอย่าง `as dynamic`
- ห้าม hard-code API key, secret หรือข้อมูลส่วนตัวลงในโค้ด
- หากมี logic ซับซ้อน ให้ใส่คอมเมนต์สั้น ๆ เท่าที่จำเป็นเพื่อช่วยการดูแลต่อ
- ไม่ต้องทดสอบผ่าน browser เว้นแต่ผู้ใช้สั่งโดยตรง
- ไม่เสนอ TDD หรือเขียน unit test เว้นแต่ผู้ใช้สั่งโดยตรง

## ก่อนส่งงาน

ต้องรันคำสั่งต่อไปนี้เสมอเมื่อมีการแก้โค้ด:

1. `dart format .`
2. `tool/check_design.sh` (ตรวจว่าไม่ได้สร้าง UI primitive ซ้ำแทน shared widget/token ใน `docs/design.md`)
