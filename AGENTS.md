# AGENTS.md

แนวทางนี้ใช้เป็นกติกากลางสำหรับ Agent และ Developer ในโปรเจกต์ Money Vibe โดยเน้นให้สอดคล้องกับโค้ดและรูปแบบ UI ที่ใช้อยู่จริงในปัจจุบัน

## Agent skills

### Issue tracker

ติดตาม issues เป็น Local Markdown ใต้ `.scratch/` ดูรายละเอียดที่ `docs/agents/issue-tracker.md`

### Triage labels

ใช้ triage labels มาตรฐานทั้งห้ารายการ ดูรายละเอียดที่ `docs/agents/triage-labels.md`

### Domain docs

ใช้โครงสร้าง domain docs แบบ single-context ดูรายละเอียดที่ `docs/agents/domain.md`

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
- หากหน้าจอมี flow เลือกข้อมูลจากรายการ เช่น บัญชี หมวดหมู่ พอร์ต หรือ filter ให้ยึด pattern bottom sheet/list selection ที่มีอยู่ในโปรเจกต์ก่อน

## UI และ Style (ตาม ADR 0001: iOS Design System)

- ทุก screen และ widget ใหม่ต้องรองรับทั้ง light mode และ dark mode โดยเน้น Dark Mode First
- ให้ดึงสถานะ theme จาก `SettingsProvider`
- ใช้ token จาก `lib/theme/app_colors.dart` และ `lib/theme/app_radii.dart` เป็นค่าเริ่มต้น ห้าม hardcode สีเทาหรือ hex ทั่วไป (อนุญาตให้ใช้ alpha บนสีดำ/ขาวเพื่อสร้าง depth แบบ iOS เช่น `.withValues(alpha: 0.05)`)
- **Inset Grouped Card**: ใช้การ์ดโค้งมน `AppRadii.xLarge` มีระยะขอบข้าง `16` ขอบเส้นบาง (`dividerColor.withValues(alpha: 0.4)`) และหัวข้อ Section นอกการ์ดตัวพิมพ์เล็ก/ใหญ่กึ่งหนา (`12sp`, `letterSpacing: 0.5`)
- **Toggles**: บังคับใช้ `CupertinoSwitch` พร้อมกำหนด `activeTrackColor` และ `inactiveTrackColor` เสมอ ห้ามใช้ Material `SwitchListTile`
- **Selection**: ใช้ `showAppModalBottomSheet` แทน dropdown หรือ `DropdownButtonFormField` เมื่อเป็นการเลือกค่าจากรายการ
- **Numeric & Amount Input**: กล่องกรอกตัวเลขแบบ iOS พื้นหลังนุ่มนวล ขอบมน จัดชิดขวา มีหน่วย/สกุลเงินในตัว และมี `onTapOutside` ปิดคีย์บอร์ดเสมอ
- **Metric Grid & Status Capsule**: ตัวเลขทางการเงิน/บาลานซ์จัดแสดงในตารางกริดโค้งมน และป้ายสถานะใช้แคปซูล (`AppRadii.full`) สี semantic โปร่งแสง 12%
- **Scaffold Header & App Bar**: พื้นหลังกลืนกับ canvas (`backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.background`, `elevation: 0`, `scrolledUnderElevation: 0`)
  - _หน้าหลัก (Tab Screens)_: ใช้ iOS Large Title สองระดับ (supertitle `13sp` `textSecondary` + title `30sp` `textPrimary`), `toolbarHeight: 100`, `centerTitle: false`
  - _หน้า Form / Detail_: ใช้ title กึ่งกลาง `18sp`, `leadingWidth: 64`
  - _ปุ่ม Action / Leading_: ต้องครอบด้วยวงกลมพื้นหลัง surface เสมอ (`Material(color: surface, clipBehavior: Clip.antiAlias, child: IconButton(...))`) ห้ามวาง icon ลอย ๆ บนพื้นหลัง
- **Bottom Navigation**: สำหรับหน้าจอหลักบน mobile (`!isLargeScreen`) ต้องใช้ `AppBottomNavigation` แบบ Floating Capsule เสมอ (ขอบโค้งมน `AppRadii.xLarge`, มีขอบเส้นบางและเงาละมุน, มีปุ่ม FAB เพิ่มรายการตรงกลาง และปุ่มเมนูเปิด Drawer) โดยครอบด้วย `Builder` เพื่อให้ `Scaffold.of(context).openDrawer()` ทำงานได้ถูกต้อง
- การใช้สี income, expense, transfer, debtRepay ควรใช้เพื่อสื่อความหมายของตัวเลขหรือสถานะ ไม่ใช้เพื่อแต่งพื้นหลังจนรก
- ศึกษาตัวอย่างและรายละเอียดเพิ่มเติมได้ที่ `docs/adr/0001-ios-design-system-and-ui-conventions.md`

## Naming และโครงสร้างไฟล์

- ไฟล์ Dart ใช้ `snake_case.dart`
- class ใช้ `PascalCase`
- ตัวแปรและเมธอดใช้ `camelCase`
- provider ลงท้ายด้วย `Provider`
- screen ลงท้ายด้วย `Screen`

## กฎสำหรับ Agent

- **On-Demand Redesign**: เมื่อผู้ใช้ส่ง `@screen` หรือ `@widget` ให้ทำการ redesign UI ตามมาตรฐานใน ADR 0001 โดยต้องรักษา **Zero Business Logic Regression** (ห้ามแก้ logic การคำนวณ, state management `Provider`, repository/database, validation หรือ debounce timer เว้นแต่ผู้ใช้สั่งโดยตรง)
- แก้เฉพาะส่วนที่เกี่ยวข้องกับงาน หลีกเลี่ยงการรื้อโค้ดส่วนอื่นโดยไม่จำเป็น
- รักษา type safety ห้ามใช้วิธีลัดอย่าง `as dynamic`
- ห้าม hard-code API key, secret หรือข้อมูลส่วนตัวลงในโค้ด
- หากมี logic ซับซ้อน ให้ใส่คอมเมนต์สั้น ๆ เท่าที่จำเป็นเพื่อช่วยการดูแลต่อ
- ไม่ต้องทดสอบผ่าน browser เว้นแต่ผู้ใช้สั่งโดยตรง
- ไม่เสนอ TDD หรือเขียน unit test เว้นแต่ผู้ใช้สั่งโดยตรง

## ก่อนส่งงาน

ต้องรันคำสั่งต่อไปนี้เสมอเมื่อมีการแก้โค้ด:

1. `dart format .`
