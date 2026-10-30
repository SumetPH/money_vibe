<!--
Sync Impact Report
- Version change: (template, unversioned) → 1.0.0
- Modified principles (placeholder → new title):
  - [PRINCIPLE_1_NAME] → I. Supabase-Only Data Layer
  - [PRINCIPLE_2_NAME] → II. Local-Time Date Handling (NON-NEGOTIABLE)
  - [PRINCIPLE_3_NAME] → III. Repository-First Architecture & Provider State
  - [PRINCIPLE_4_NAME] → IV. Design System Compliance & Zero Business Logic Regression
  - [PRINCIPLE_5_NAME] → V. Modular Screen Structure
- Added sections:
  - Technology Stack & Security Constraints (from [SECTION_2_NAME])
  - Development Workflow & Quality Gates (from [SECTION_3_NAME])
  - Governance (filled)
- Removed sections: none
- Source: AGENTS.md (2026-10-30)
- Follow-up TODOs: none
-->

# Money Vibe Constitution

## Core Principles

### I. Supabase-Only Data Layer

- Supabase MUST เป็น backend และแหล่งข้อมูลเดียวของแอป ห้ามเพิ่มหรือพาโค้ดกลับไปพึ่ง SQLite
  หรือ local database อื่น
- การแก้ schema ทุกครั้ง MUST มี migration ใน `supabase/migrations` และ apply ด้วย
  Supabase CLI (`supabase db push`) ห้ามแก้ schema ผ่าน dashboard โดยไม่มี migration
- ตารางใหม่ใน schema `public` MUST มี
  `GRANT SELECT, INSERT, UPDATE, DELETE ... TO authenticated, service_role`
  อยู่ใน migration เดียวกับที่สร้างตาราง
- คอลัมน์ `tags` ของ `transactions` ถูกลบแล้ว ห้ามเพิ่มกลับหรืออ้างถึงในโค้ด
- Edge Function MUST อยู่ที่ `supabase/functions/<name>/index.ts` และ deploy ด้วย
  `supabase functions deploy <name> --project-ref <ref>` ตามขั้นตอนใน `docs/setup/`

**Rationale**: แหล่งข้อมูลเดียวที่ทุก schema change ถูก version ไว้ ทำให้ทุก environment
reproduce ได้ และ Supabase ไม่ grant สิทธิ์ให้ตารางใหม่อัตโนมัติอีกแล้ว

### II. Local-Time Date Handling (NON-NEGOTIABLE)

- เวลาทั้งหมด MUST เก็บเป็น local time ตามเครื่องผู้ใช้ คอลัมน์วันที่เวลา MUST ใช้
  `timestamp without time zone`
- ห้ามเรียก `.toUtc()` / `.toLocal()` หรือแปลง timezone เองตอนอ่านหรือเขียนข้อมูล
- การ serialize เข้า database MUST ใช้ `DateTime.toIso8601String()` จาก local `DateTime` ตรง ๆ

**Rationale**: ข้อมูลการเงินผูกกับ "วันที่ตามปฏิทินของผู้ใช้" การแปลง timezone ไปมาทำให้
รายการเลื่อนวันและยอดสรุปรายวัน/รายเดือนผิด

### III. Repository-First Architecture & Provider State

- ความสามารถด้านข้อมูลใหม่หรือที่ถูกลด MUST ประกาศใน `DatabaseRepository` ก่อน แล้วจึง
  implement ใน `SupabaseRepository` หรือ adapter ที่เกี่ยวข้อง
- Logic การดึง/บันทึกข้อมูล MUST อยู่ใน repository, service, provider หรือ widget helper
  ที่เหมาะสม ห้ามเขียน query หรือ data logic ตรงใน widget UI
- `Provider` MUST เป็นทางหลักในการเชื่อม UI กับ state และ `GoRouter` MUST เป็นตัวจัดการ
  top-level navigation และ auth/setup redirect

**Rationale**: abstraction ชั้นเดียวทำให้เปลี่ยน backend หรือเขียนเทสต์ด้วย fake repository
ได้โดยไม่แตะ UI

### IV. Design System Compliance & Zero Business Logic Regression

- งานที่ออกแบบหรือแก้ UI, form, modal, navigation หรือ Account flow MUST อ่านและทำตาม
  `docs/design.md` ซึ่งเป็น source of truth ของกติกา design
- MUST ใช้ shared widget/token ที่บันทึกใน `docs/design.md` ห้ามสร้าง UI primitive ซ้ำ
  (ตรวจด้วย `bash tool/check_design.sh`)
- widget ที่ใช้ซ้ำข้าม module MUST อยู่ใน `lib/widgets/` และบันทึกใน `docs/design.md`
- **On-Demand Redesign**: เมื่อผู้ใช้ส่ง `@screen` หรือ `@widget` ให้ redesign ตาม
  `docs/design.md` โดยห้ามแก้ logic การคำนวณ, state management (`Provider`),
  repository/database, validation หรือ debounce timer เว้นแต่ผู้ใช้สั่งโดยตรง

**Rationale**: UI ที่สอดคล้องกันต้องมาจากแหล่งกติกาเดียว และงาน redesign ต้องไม่ทำให้
ตัวเลขทางการเงินเปลี่ยนโดยไม่ตั้งใจ

### V. Modular Screen Structure

ยึดแบบ `lib/screens/cash_flow/` สำหรับทุก `lib/screens/<module>/`:

- ไฟล์ screen SHOULD ยาวไม่เกิน ~400 บรรทัด และ MUST NOT เกิน 800 บรรทัด ไฟล์เดิมที่ยาวเกิน
  ~400 บรรทัดไม่ต้อง refactor เว้นแต่ผู้ใช้สั่ง หรือการแก้ครั้งนั้นทำให้เกิน 800 บรรทัด
- tab, section, bottom sheet, dialog, list item, summary card MUST แยกเป็นไฟล์ของตัวเองใน
  โฟลเดอร์ module เดียวกัน (ไม่สร้างโฟลเดอร์ย่อย) ชื่อ `<feature>_<role>.dart`
  ยกเว้น widget ที่สั้นกว่า ~40 บรรทัดและใช้ที่เดียว
- class ที่แยกออกมา MUST เป็น public พร้อม prefix ของ feature (เช่น `BudgetMetricTile`)
  ห้ามใช้ `part` / `part of`
- ไฟล์ screen เก็บ `State`, lifecycle, การเชื่อม Provider, navigation และ action
  save/delete ส่วน widget ที่แยกออกไปรับเฉพาะข้อมูลและ callback
- data/aggregation class ที่ใช้เฉพาะ UI MUST อยู่ใน `<feature>_models.dart` ข้างไฟล์ screen

**Rationale**: ไฟล์ขนาดเล็กที่แบ่งหน้าที่ชัดเจนทำให้ review, หา และแก้ได้ง่ายทั้งสำหรับคน
และ Agent

## Technology Stack & Security Constraints

- Stack: Flutter (Dart) app จัดการการเงินส่วนบุคคล, Supabase backend, `Provider`,
  `GoRouter`
- Naming: ไฟล์ Dart `snake_case.dart`, class `PascalCase`, ตัวแปร/เมธอด `camelCase`,
  provider ลงท้าย `Provider`, screen ลงท้าย `Screen`
- Type safety MUST ถูกรักษา ห้ามใช้ทางลัดอย่าง `as dynamic`
- ห้าม hard-code API key, secret หรือข้อมูลส่วนตัวลงในโค้ด
- logic ที่ซับซ้อน SHOULD มีคอมเมนต์สั้น ๆ เท่าที่จำเป็นเพื่อการดูแลต่อ

## Development Workflow & Quality Gates

- การเปลี่ยนแปลง MUST จำกัดเฉพาะส่วนที่เกี่ยวข้องกับงาน หลีกเลี่ยงการรื้อโค้ดส่วนอื่น
- การสื่อสารระหว่างทำงาน (คำถาม, ความคืบหน้า, ขั้นตอนโต้ตอบของ skill) MUST เป็นภาษาไทย
- Testing: เขียนเทสต์ตามความเหมาะสม (โดยเฉพาะ logic คำนวณใน service/provider) หรือตามที่
  spec กำหนด ไม่บังคับ TDD ถ้าแก้โค้ดที่มีเทสต์อยู่แล้วใน `test/` MUST รัน `flutter test`
  ให้ผ่านและแก้เทสต์ที่พังจากการเปลี่ยนแปลงนั้น
- ไม่ทดสอบผ่าน browser เว้นแต่ผู้ใช้สั่งโดยตรง
- Quality gates ที่ MUST ผ่านทุกครั้งที่แก้โค้ด ก่อนส่งงาน:
  1. `dart format .`
  2. `flutter analyze` — ไม่มี error หรือ warning ใหม่
  3. `bash tool/check_design.sh` — บน Windows รันผ่าน Git Bash

## Governance

- Constitution นี้มีลำดับความสำคัญเหนือแนวปฏิบัติอื่นในโปรเจกต์ `AGENTS.md` เป็น runtime
  guidance สำหรับ Agent และ Developer และ `docs/design.md` เป็น source of truth ด้าน design
  ทั้งสามเอกสาร MUST สอดคล้องกัน หากขัดกันให้แก้ให้ตรงกันใน amendment เดียวกัน
- Amendment: แก้ผ่าน `/speckit-constitution` พร้อม Sync Impact Report และ PR ที่ระบุเหตุผล
  ของการเปลี่ยน
- Versioning (semantic):
  - MAJOR: ลบหรือนิยาม principle ใหม่แบบไม่ backward compatible
  - MINOR: เพิ่ม principle/section หรือขยาย guidance อย่างมีนัยสำคัญ
  - PATCH: ปรับถ้อยคำ แก้คำผิด หรือขยายความที่ไม่เปลี่ยนความหมาย
- Compliance: ทุก spec/plan (Constitution Check ใน `/speckit-plan`) และทุก PR review MUST
  ตรวจความสอดคล้องกับ principle ข้างต้น การละเมิดใด ๆ MUST มีเหตุผลบันทึกไว้ใน plan

**Version**: 1.0.0 | **Ratified**: 2026-10-30 | **Last Amended**: 2026-10-30
