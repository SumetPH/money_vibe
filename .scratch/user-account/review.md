# Implementation review

จุดเริ่มต้น: `f75cd16b7cfbc0fb68df430d36c2347d4f6bc291`

ใช้ skill `mattpocock-skills:code-review` แยก reviewer สองแกน และตรวจแก้ซ้ำก่อน commit รอบสุดท้าย

## Standards

พบ 1 ประเด็น P2: หน้าตั้งค่าใช้ `!signInMethodsReady` แสดง “โหลดช่องทางเข้าสู่ระบบไม่สำเร็จ” ทั้งช่วงกำลังโหลดและเมื่อผิดพลาด ขัดกติกาความพร้อมของข้อมูลใน `docs/design.md`

แก้แล้ว: แยก `isLoadingSignInMethods` และสถานะ failure แสดง `SettingsBusyIndicator` ระหว่างรอ ผู้รีวิวตรวจ working diff ซ้ำและยืนยันว่าประเด็นเดิมปิดแล้ว ไม่พบ baseline smell ที่มีผลกระทบเพิ่มเติม

## Spec

พบ 1 ประเด็น P1: หาก logout ระหว่าง initial load ของ A แล้ว login B ทันที `initialize()` อาจคืน future เก่า ทำให้ B ไม่ได้โหลดข้อมูลใหม่และสถานะพร้อมอาจมาจากผล A ขัดข้อกำหนดให้เข้าบัญชีและเห็นข้อมูลการเงินของตน

แก้แล้ว: เพิ่ม generation ให้ SyncProvider, ยกเลิกการเขียน readiness/checkpoints ของ generation เก่า, รอคำขอเก่าจบก่อนโหลด user ใหม่ และตรวจ future ตัวเดิมก่อน cleanup manual refresh ผู้รีวิวตรวจซ้ำทั้ง initialization, refresh และ check แล้วไม่พบช่องข้าม generation หรือ deadlock เพิ่มในขอบเขตที่ตรวจ

ผลรีวิว: Standards พบ 1 แก้แล้ว 1; Spec พบ 1 แก้แล้ว 1 ไม่มี finding ค้างจากการตรวจโค้ด

## Validation

- `dart format .` ผ่าน
- `tool/check_design.sh` ผ่าน
- `flutter analyze --no-pub` ผ่าน
- `flutter test --no-pub` ผ่าน 50 tests หลังแก้รีวิว รวม sync tests เดิม 20 tests
- `flutter build web --no-pub --dart-define-from-file=config/dev.json` สำเร็จ ไม่เปิด browser หรือ server; มี Wasm dry-run warning จาก `flutter_timezone` ที่ใช้อยู่เดิม
- ไม่มี unit test ใหม่ตาม spec และ AGENTS.md

## งานที่ยังต้องใช้บัญชีและอุปกรณ์จริง

ยังไม่ apply migration: `db push` พบว่ายังไม่ link project และเมื่อ link dev จาก config พบ `AccessTokenRequiredError` ต้อง `supabase login` แล้ว link/dev push ตามคู่มือ

ยังไม่ได้แก้ Dashboard, ใส่ Google Client IDs หรือทดสอบ OTP/Google/password manager บนอุปกรณ์จริง จำนวน identities หลังตั้งรหัสผ่านยังไม่ทราบ จึงคง checklist เหล่านี้ไว้และตั้ง issues 02–07 เป็น `ready-for-human` คู่มืออยู่ `docs/setup/GOOGLE_AUTH_SETUP.md`
