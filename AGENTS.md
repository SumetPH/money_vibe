# AGENTS.md

แนวทางนี้ใช้เป็นกติกากลางสำหรับ Agent และ Developer ในโปรเจกต์ Money Vibe โดยเน้นให้สอดคล้องกับโค้ดและรูปแบบ UI ที่ใช้อยู่จริงในปัจจุบัน

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

## UI และ Style

- ทุก screen และ widget ใหม่ต้องรองรับทั้ง light mode และ dark mode
- ให้ดึงสถานะ theme จาก `SettingsProvider`
- ใช้ token จาก `lib/theme/app_colors.dart` และ `lib/theme/app_radii.dart` เป็นค่าเริ่มต้น
- ยอมรับการใช้สีของ Flutter ตรง ๆ ได้เฉพาะกรณีที่เป็นสีมาตรฐานของ theme component หรือมีเหตุผลชัดเจนจากบริบทเดิมของไฟล์
- รักษา visual language แบบ list-first, surface-first
- หน้าจอข้อมูลหลักควรอ่านง่าย แบน และแบ่ง section ด้วย spacing, divider, และ surface มากกว่าการ์ดลอยหลายชั้น
- ใช้ card, shadow หรือ radius ใหญ่เฉพาะจุดที่ต้องการแยกบริบทจริง เช่น dialog, bottom sheet, panel หรือ repeated item บางประเภท
- พยายามใช้ `showModalBottomSheet` แทน dropdown select หรือ `DropdownButtonFormField` เมื่อเป็นการเลือกค่าจากรายการ โดยให้แสดงเป็น row/list บน surface และมีสถานะ selected ที่ชัดเจน
- ใช้ dropdown เฉพาะกรณีที่เป็นตัวเลือกสั้นมากจริง ๆ หรือมี pattern เดิมของหน้าจอนั้นที่ชัดเจนอยู่แล้ว
- การใช้สี income, expense, transfer ควรใช้เพื่อสื่อความหมายของตัวเลขหรือสถานะ ไม่ใช้เพื่อแต่งพื้นหลังจนรก
- หากไม่แน่ใจเรื่อง pattern ให้เทียบกับหน้าปัจจุบันใน `transaction`, `portfolio`, `trade`, `statistics`, `budget` และ `credit card bill`

## Naming และโครงสร้างไฟล์

- ไฟล์ Dart ใช้ `snake_case.dart`
- class ใช้ `PascalCase`
- ตัวแปรและเมธอดใช้ `camelCase`
- provider ลงท้ายด้วย `Provider`
- screen ลงท้ายด้วย `Screen`

## กฎสำหรับ Agent

- แก้เฉพาะส่วนที่เกี่ยวข้องกับงาน หลีกเลี่ยงการรื้อโค้ดส่วนอื่นโดยไม่จำเป็น
- รักษา type safety ห้ามใช้วิธีลัดอย่าง `as dynamic`
- ห้าม hard-code API key, secret หรือข้อมูลส่วนตัวลงในโค้ด
- หากมี logic ซับซ้อน ให้ใส่คอมเมนต์สั้น ๆ เท่าที่จำเป็นเพื่อช่วยการดูแลต่อ
- งานในโปรเจกต์นี้ไม่ต้องเพิ่ม test ใหม่ เว้นแต่มีการขอโดยตรง

## ก่อนส่งงาน

ต้องรันคำสั่งต่อไปนี้เสมอเมื่อมีการแก้โค้ด:

1. `dart format .`
2. `flutter analyze`
