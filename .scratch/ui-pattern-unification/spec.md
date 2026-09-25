# UI Pattern Unification

Status: done

## เป้าหมาย

ทำให้ทั้งแอปใช้ UI pattern เดียวกัน โดยย้าย UI primitive ที่แต่ละหน้าสร้างเองไปเป็น token และ shared widget กลาง แล้วบังคับด้วยสคริปต์ตรวจ. ต้องรักษา **Zero Business Logic Regression**: ไม่แตะการคำนวณ, Provider, repository, validation, debounce และ navigation behavior.

## สภาพก่อนเริ่ม (นับจาก `lib/`)

| Pattern                                   | ไฟล์ | จุด |
| ----------------------------------------- | ---- | --- |
| `CupertinoSwitch(`                        | 14   | 19  |
| `_buildSectionHeader` แยกกันเอง           | 8    | 43  |
| `_buildInsetCard` / `_buildCard`          | 7    | 7   |
| ปุ่มปิด/ย้อนบน header ที่เขียนเอง         | ~20  | ~20 |
| `AlertDialog(`                            | 17   | 22  |
| `DraggableScrollableSheet(`               | 8    | 12  |
| `withValues(alpha: 0.4)` สำหรับสีขอบ      | 35   | 169 |
| สี hard-code `const Color(0x…)` ใน screen | 13   | 36  |

## Phases

| #   | งาน                                                                                                            | ผลลัพธ์                                          |
| --- | -------------------------------------------------------------------------------------------------------------- | ------------------------------------------------ |
| 1   | Tokens: `AppColors.borderFor`, `switchInactiveFor` และ theme helpers ที่ใช้ซ้ำ                                   | `lib/theme/app_colors.dart`                      |
| 2   | Shared widgets: `AppSwitch`, `AppSectionHeader`, `AppInsetCard`, `AppCardDivider`, `AppCloseButton`, `AppBackButton`, `AppSaveButton`, `showAppConfirmDialog`, `showAppSelectionSheet` | `lib/widgets/app_*.dart`                          |
| 3   | ย้าย `CupertinoSwitch` ทั้งหมด → `AppSwitch`                                                                    | สี switch เป็น accent ของธีมทุกหน้า              |
| 4   | ย้ายปุ่ม leading ของ AppBar → `AppCloseButton` (ฟอร์ม) / `AppBackButton` (หน้ารอง)                              | header หน้ารองเหมือนกันทุกหน้า                   |
| 5   | ย้ายปุ่มบันทึกของฟอร์ม → `AppSaveButton`                                                                        | ปุ่มบันทึกแบบเดียวทั้งแอป                        |
| 6   | ย้าย section header / inset card / card divider → shared widgets                                                | ลบ `_buildSectionHeader`/`_buildInsetCard` ในหน้า |
| 7   | ย้าย confirmation `AlertDialog` → `showAppConfirmDialog`                                                        | dialog ยืนยันแบบเดียว                            |
| 8   | ย้าย selection `DraggableScrollableSheet` → `showAppSelectionSheet`                                             | sheet เลือกค่าขนาด/พฤติกรรมเดียวกัน              |
| 9   | แทนสีขอบ ternary `divider.withValues(alpha: 0.4)` → `AppColors.borderFor`                                        | token เดียวสำหรับขอบการ์ด                        |
| 10  | Guard: `tool/check_design.sh`, อัปเดต `docs/design.md` และ `AGENTS.md`                                           | กันการเขียน pattern ซ้ำกลับเข้ามา                |

## การตัดสินใจ

- สวิตช์ใช้ accent ของธีมเสมอ (ไม่มี override สี semantic) เพื่อให้เป็น pattern เดียว.
- ปุ่มบันทึกทุกฟอร์มใช้ pill `fabFor` + check icon; ฟอร์มหุ้นใช้ label ตาม action (`ซื้อ`/`ขาย`) บน pill แบบเดียวกัน.
- ตัวแบ่งในการ์ดใช้ `AppColors.borderFor` (alpha 0.4) ทั้งหมด; ระยะเยื้องกำหนดผ่าน `indent` ตาม layout ของแถว.
- Dialog ที่มีช่องกรอก (แก้เงินสด, reorder กลุ่ม, ลืมรหัสผ่าน ฯลฯ) ไม่อยู่ในขอบเขต `showAppConfirmDialog` แต่ใช้พื้น surface จาก theme ตามเดิม.

## ตรวจก่อนจบ

- `dart format .`
- `flutter analyze` ไม่มี error/warning ใหม่
- `tool/check_design.sh` ผ่าน

## ผลลัพธ์ (2026-09-25)

ทุก phase เสร็จ. `dart format .`, `flutter analyze` (No issues), `tool/check_design.sh`, `flutter test` และ `flutter build web --debug` ผ่าน. 40 ไฟล์เปลี่ยน, โค้ดลดลงราว 1,700 บรรทัด.

การเปลี่ยนหน้าตาที่ตั้งใจ (เพื่อให้เป็น pattern เดียว):

- สวิตช์ใน holding/investment plan/recurring/budget/reorder sheets เปลี่ยนเป็นสี accent ของธีม.
- ปุ่มบันทึกของฟอร์มหุ้น, Stock Trade และ Broker Report เปลี่ยนเป็น pill สีเหลืองแบบเดียวกับฟอร์มหลัก.
- dialog ยืนยันใช้สไตล์เดียว (ปุ่ม TextButton, สี expense เมื่อ destructive); dialog ลบที่เดิมโหลดค้างใน dialog จะปิด dialog ก่อนแล้วแสดง loading บนหน้าฟอร์ม.
- หัวข้อ section ของ Account Form เป็น 12sp/letterSpacing 0.5 เท่าฟอร์มอื่น; ตัวแบ่งในการ์ดใช้ alpha 0.4 ทุกหน้า.
- ฟอง chat และปุ่มส่งของ Portfolio Analyze ใช้สี accent ของธีม.

นอกขอบเขต: dialog ที่มีช่องกรอก/หลายตัวเลือก 7 จุดยังเป็น `AlertDialog` (มี marker `design-check: allow`), และ `dividerColor.withValues(alpha: 0.4)` ที่คำนวณจาก token อยู่แล้วยังไม่ถูกแทนทั้งหมด.
