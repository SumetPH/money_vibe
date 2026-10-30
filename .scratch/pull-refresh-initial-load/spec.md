# Spec: Manual Refresh และ Initial Load แบบไม่บล็อก

Status: ready-for-agent

## Problem Statement

ผู้ใช้ใช้ Money Vibe จากหลายเครื่อง (มือถือ, web) และเจอปัญหาสองข้อ

1. **ไม่มีทางสั่งให้ข้อมูลอัปเดต** เมื่อสงสัยว่ายอดเงินหรือรายการไม่ตรงกับอีกเครื่อง ข้อมูลจะเปลี่ยนก็ต่อเมื่อ Background Sync ทำงาน ซึ่งเกิดเฉพาะตอนสลับ tab, เปลี่ยน route หรือกลับเข้าแอป และติด cooldown 30 วินาที ถ้า `sync_logs` ไม่ถูก bump (เช่น trigger พลาด หรือมีคนแก้ข้อมูลตรงใน DB) ข้อมูลจะค้างอยู่อย่างนั้น ผู้ใช้ต้องปิดแล้วเปิดแอปใหม่
2. **เปิดแอปช้า** native splash ค้างอยู่จนกว่าข้อมูลทุก module (accounts, budgets, categories, transactions, recurring, cash flow) จะโหลดครบ ผู้ใช้จึงไม่เห็นอะไรเลยระหว่างรอ หลัง login ก็เป็นแบบเดียวกัน และถ้าเปิดแอปตอน offline แอปจะแสดงข้อมูลว่าง ดูเหมือนบัญชีหายหมด

## Solution

- **Manual Refresh**: ดึงหน้าจอลง (pull-to-refresh) เพื่อโหลดข้อมูลทุก module ที่หน้านั้นใช้ใหม่ทั้งหมด โดยไม่ดูว่าระบบคิดว่าข้อมูลเปลี่ยนหรือไม่ ส่วนจอกว้างมีปุ่ม refresh ใน app bar ด้วย
- **Initial Load แบบไม่บล็อก**: ปล่อย splash ทันทีที่รู้สถานะ login แล้วแสดงหน้าจอเลย หน้าไหนที่ข้อมูลยังมาไม่ครบให้แสดง skeleton ถ้าโหลดล้มเหลวให้แสดง error state พร้อมปุ่ม "ลองใหม่"
- Background Sync ทำงานเหมือนเดิม ไม่เพิ่ม polling หรือ Realtime

คำศัพท์ (Initial Load, Background Sync, Manual Refresh) ใช้ตาม `GLOSSARY.md`

## User Stories

1. As a ผู้ใช้มือถือ, I want ดึงหน้า Accounts ลงเพื่อโหลดข้อมูลใหม่, so that ยอดเงินของแต่ละบัญชีตรงกับที่เพิ่งบันทึกจากอีกเครื่อง
2. As a ผู้ใช้มือถือ, I want ดึงหน้า Transactions ลงเพื่อโหลดใหม่, so that เห็นรายการที่เพิ่มจาก web ทันทีโดยไม่ต้องปิดแอป
3. As a ผู้ใช้มือถือ, I want ดึงหน้า Budgets ลงเพื่อโหลดใหม่, so that ยอดใช้จ่ายเทียบงบเป็นปัจจุบัน
4. As a ผู้ใช้มือถือ, I want ดึงหน้า Statistics ลงเพื่อโหลดใหม่, so that กราฟและสรุปคำนวณจากข้อมูลล่าสุด
5. As a ผู้ใช้, I want ดึงหน้า Cash flow ลงเพื่อโหลดใหม่, so that ประมาณการกระแสเงินสดใช้ยอดบัญชี งบ และรายการล่าสุด
6. As a ผู้ใช้, I want ดึงหน้า Recurring ลงเพื่อโหลดใหม่, so that รายการประจำที่แก้จากอีกเครื่องแสดงถูกต้อง
7. As a ผู้ใช้, I want Manual Refresh โหลดทุก module ที่หน้านั้นใช้พร้อมกัน, so that ตัวเลขในหน้าไม่ขัดกัน (เช่นยอดบัญชีที่คำนวณจาก transactions)
8. As a ผู้ใช้, I want Manual Refresh ทำงานแม้ระบบคิดว่าข้อมูลไม่ได้เปลี่ยน, so that แก้ปัญหาได้เองเมื่อ Background Sync พลาด
9. As a ผู้ใช้, I want Manual Refresh ไม่ติด cooldown, so that กดซ้ำได้ทันทีเมื่อต้องการ
10. As a ผู้ใช้ที่ถือบัญชี USD, I want Manual Refresh บนหน้าที่โหลด accounts ดึงอัตราแลกเปลี่ยนใหม่ด้วย, so that net worth ที่แปลงเป็น THB เป็นปัจจุบัน
11. As a ผู้ใช้, I want เห็น spinner ของการดึงหน้าจอระหว่าง Manual Refresh, so that รู้ว่าระบบกำลังโหลด
12. As a ผู้ใช้, I want เห็น SnackBar แจ้งเมื่อ Manual Refresh ล้มเหลว, so that รู้ว่าข้อมูลยังไม่ได้อัปเดต
13. As a ผู้ใช้, I want ข้อมูลเดิมยังแสดงอยู่เมื่อ Manual Refresh ล้มเหลว, so that ไม่เห็นหน้าว่างตอนเน็ตหลุด
14. As a ผู้ใช้ web หรือจอกว้าง, I want มีปุ่ม refresh ใน app bar, so that สั่ง Manual Refresh ได้ด้วยเมาส์ที่ดึงหน้าจอไม่ได้
15. As a ผู้ใช้, I want Manual Refresh ที่สั่งระหว่าง Background Sync รอรอบนั้นจบก่อน, so that ไม่มีการโหลดซ้อนจนข้อมูลกระพริบหรือขัดกัน
16. As a ผู้ใช้, I want Background Sync รอบถัดไปไม่โหลดซ้ำ module ที่เพิ่ง Manual Refresh ไป, so that ประหยัดเน็ตและไม่กระพริบ
17. As a ผู้ใช้, I want เห็นหน้าจอแอปทันทีหลังเปิดแอป, so that ไม่ต้องจ้อง splash นาน
18. As a ผู้ใช้, I want เห็นหน้าหลักทันทีหลัง login, so that เริ่มใช้งานได้เร็ว
19. As a ผู้ใช้, I want เห็น skeleton แทนข้อมูลจนกว่าข้อมูลของหน้านั้นจะครบ, so that รู้ว่ากำลังโหลด ไม่ได้ว่างจริง
20. As a ผู้ใช้, I want ไม่เห็นข้อความ empty state เช่น "ยังไม่มีบัญชี" ระหว่างที่ข้อมูลยังมาไม่ถึง, so that ไม่ตกใจว่าข้อมูลหาย
21. As a ผู้ใช้, I want หน้าหนึ่งแสดงข้อมูลเมื่อทุก module ของหน้านั้นพร้อม ไม่ทยอยแสดงบางส่วน, so that ไม่เห็นยอดเงินที่คำนวณจากข้อมูลไม่ครบ
22. As a ผู้ใช้ที่เปิดแอปตอน offline, I want เห็น error state พร้อมปุ่ม "ลองใหม่" แทนหน้าว่าง, so that รู้ว่าโหลดไม่สำเร็จและลองใหม่ได้
23. As a ผู้ใช้, I want ปุ่ม "ลองใหม่" กับการดึงหน้าจอลงทำงานเหมือนกัน, so that มีวิธีเดียวที่คาดเดาได้
24. As a ผู้ใช้, I want ดึงหน้าจอลงได้แม้อยู่ใน skeleton หรือ error state, so that สั่งโหลดใหม่ได้ทุกเมื่อ
25. As a ผู้ใช้, I want ปุ่มเพิ่ม/แก้ไข/reorder ใช้ไม่ได้จนกว่าข้อมูลของหน้าจะพร้อม, so that ไม่เปิดฟอร์มที่ไม่มีบัญชีหรือหมวดหมู่ให้เลือก
26. As a ผู้ใช้, I want สลับ tab, เปิด drawer และเข้า Settings ได้ระหว่าง Initial Load, so that ไม่ถูกล็อกไว้ที่หน้าเดียว
27. As a ผู้ใช้, I want การดึงหน้าจอลงระหว่าง Initial Load ไม่ยิงโหลดซ้ำ แต่รอรอบที่กำลังโหลดอยู่, so that ไม่เปลืองเน็ต
28. As a ผู้ใช้, I want การดึงหน้าจอลงหลัง Initial Load ล้มเหลวสั่งโหลดใหม่จริง, so that กู้คืนได้เมื่อเน็ตกลับมา
29. As a ผู้ใช้ที่ทำ import หรือ clear data, I want แอปรอจนข้อมูลโหลดครบก่อนบอกว่าเสร็จ, so that มั่นใจว่าผลลัพธ์ถูกต้อง
30. As a ผู้ใช้, I want หน้าใน drawer ที่อ่าน module เดียวกัน (เช่น Category list) แสดง skeleton ตามกติกาเดียวกัน, so that ไม่เห็น empty state ผิด ๆ
31. As a ผู้ใช้ที่ logout แล้ว login ด้วยบัญชีอื่น, I want สถานะความพร้อมของข้อมูลเริ่มใหม่ทั้งหมด, so that ไม่เห็นข้อมูลของบัญชีก่อนหน้า
32. As a ผู้ใช้ dark mode, I want skeleton ใช้สีตาม theme, so that ไม่มีแถบสว่างแสบตา

## Implementation Decisions

### Data Readiness อยู่ใน `SyncProvider`

- `SyncProvider` เก็บสถานะความพร้อมของแต่ละ `SyncModule` มี 4 ค่า: ยังไม่โหลด, กำลังโหลด, พร้อม, ล้มเหลว
  - **พร้อม** หมายถึงโหลดสำเร็จมาแล้วอย่างน้อยหนึ่งครั้ง ถ้า Manual Refresh รอบหลังล้มเหลว ให้คงสถานะ "พร้อม" ไว้ (ข้อมูลเดิมยังใช้ได้) แล้วรายงานความล้มเหลวให้ผู้เรียกแทน
  - **ล้มเหลว** ใช้เฉพาะ module ที่ยังไม่เคยโหลดสำเร็จเลย
  - `portfolio` ใช้สถานะของ `accounts` (ตาม `refreshTarget` เดิม)
- มี getter ให้ UI ถามสถานะรวมของ set ของ module ได้ ถ้าตัวไหนล้มเหลวให้ถือว่าทั้ง set ล้มเหลว ถ้าทุกตัวพร้อมแล้วถือว่าพร้อม นอกนั้นถือว่ากำลังโหลด
- `SyncProvider` เรียก `notifyListeners` เมื่อสถานะเปลี่ยน
- `reset()` (ตอนเปลี่ยน user) ล้างสถานะทุก module กลับเป็น "ยังไม่โหลด"

### Initial Load

- `initialize` เปลี่ยนจากรับ closure เดียว เป็นรับ loader แยกตาม module (map จาก `SyncModule` ไปยัง loader) เพื่อให้รู้ผลของแต่ละ module ยังโหลดแบบขนานเหมือนเดิม และยังอ่าน `sync_logs` ก่อนและหลังโหลดเพื่อตั้ง baseline เหมือนเดิม
- loader ของ module ที่ล้มเหลวจะไม่ทำให้ module อื่นล้มด้วย ส่วน baseline timestamp ให้บันทึกเฉพาะ module ที่โหลดสำเร็จ
- ตอนเปิดแอป: `main` จะไม่ await Initial Load อีกต่อไป ให้รอแค่ settings, auth และ debug bootstrap แล้วจึงรัน app และปล่อย splash จากนั้นเริ่ม Initial Load ในพื้นหลัง
- หลัง login: auth screen สั่ง Initial Load โดยไม่ await แล้วนำทางไปหน้าหลักทันที
- import และ clear data ในหน้าจัดการข้อมูลยัง await Initial Load จนเสร็จเหมือนเดิม
- `hasBaseline` เดิมยังคงไว้ เพื่อให้ Background Sync ไม่ทำงานก่อน Initial Load เสร็จ

### Manual Refresh

- เพิ่ม `refresh(Set<SyncModule> modules)` ใน `SyncProvider`
  - force reload ทุก module ที่ระบุ ไม่ดู `sync_logs` และไม่ติด cooldown
  - ถ้า Initial Load กำลังทำงาน ให้รอรอบนั้นจบ แล้ว reload เฉพาะ module ที่ยังไม่พร้อม (ถ้าทุกตัวพร้อมแล้วก็ไม่ต้องทำอะไร)
  - ถ้า Background Sync กำลังทำงาน ให้รอรอบนั้นจบก่อน แล้วค่อย force reload
  - อ่าน `sync_logs` ก่อน reload แล้วบันทึก timestamp ที่อ่านได้เฉพาะ module ที่ reload สำเร็จ เพื่อให้ Background Sync รอบถัดไปไม่โหลดซ้ำ
  - reload module ที่ระบุแบบขนาน ถ้ามี module ล้มเหลวให้ throw หลังจากทุกตัวจบแล้ว เพื่อให้ UI แสดง SnackBar
  - การเรียก refresh ที่ซ้อนกันด้วย set เดียวกันให้แชร์ Future เดียวกัน
- `SyncProvider` รับ `manualRefreshers` เพิ่ม (optional) แยกจาก `refreshers` เดิม สำหรับ Manual Refresh ถ้า module ไหนไม่มีใน map นี้ให้ใช้ `refreshers` แทน
  - accounts ใช้ loader ที่ดึงอัตราแลกเปลี่ยน USD ใหม่ด้วย (เทียบเท่า `AccountProvider.init`) ส่วน Background Sync ยังใช้ `reloadPersistedData` เหมือนเดิม

### Module ของแต่ละหน้า

| หน้า | Module |
|---|---|
| Accounts | accounts, transactions |
| Budgets | budgets, transactions, categories |
| Transactions | transactions, accounts, categories |
| Statistics | transactions, accounts |
| Cash flow | cashFlow, accounts, budgets, transactions |
| Recurring | recurring, accounts, categories |
| Category list (drawer) | categories (skeleton อย่างเดียว ไม่มี pull-to-refresh) |

ให้ตั้งชุด module นี้เป็นค่าคงที่ไว้ใกล้หน้าจอนั้น หรือรวมไว้ในที่เดียว เพื่อให้ skeleton, error state และ Manual Refresh ใช้ชุดเดียวกัน

### UI

- **Skeleton**: shared widget ใหม่ใน `lib/widgets/` เป็น placeholder แบบนิ่ง ไม่มี shimmer ใช้ token สีจาก theme ทั้ง light และ dark และต้องบันทึกกติกาใน `docs/design.md` ให้แต่ละหน้าเลือกโครงที่ใกล้กับ layout จริง เช่นแถวรายการหรือการ์ดสรุป
- **Error state**: ข้อความสั้นพร้อมปุ่ม "ลองใหม่" ที่สั่ง Manual Refresh ของหน้านั้น ถ้าเป็น pattern ที่ใช้ข้ามหน้า ให้ทำเป็น shared widget และบันทึกใน `docs/design.md`
- **Pull-to-refresh**: ครอบเนื้อหาด้วย `RefreshIndicator` ทั้งใน state ปกติ, skeleton และ error (ต้องเลื่อนได้เสมอเพื่อให้ดึงได้) สำหรับ 6 หน้าในตาราง ยกเว้น Category list
- **ปุ่ม refresh บนจอกว้าง** (≥800px ตาม breakpoint เดิม): ใช้ shared app bar button ที่มีอยู่ และระหว่าง refresh ให้แสดงสถานะ busy
- **SnackBar** เมื่อ Manual Refresh ล้มเหลว โดยคงข้อมูลเดิมไว้
- **ปุ่มเพิ่ม/แก้ไข/reorder** ของหน้าจะเป็น disabled จนกว่า module ของหน้าจะพร้อม ส่วน navigation ใช้ได้ปกติ
- `isLoading` ของ provider แต่ละตัวยังคงไว้ แต่ UI ใหม่ต้องอ่านความพร้อมจาก `SyncProvider` ไม่ใช่จาก `isLoading`
- ไฟล์ screen ต้องไม่เกินกำหนดใน `AGENTS.md` ถ้าเกินให้แยก widget ออกเป็นไฟล์ตามกติกา

### อื่น ๆ

- ไม่มีการเปลี่ยน schema หรือ migration
- ไม่แก้ logic การคำนวณ (balance, budget, forecast) และไม่แก้ repository

## Testing Decisions

- **Seam เดียว คือ `SyncProvider`** เพราะรับ `getSyncLogs`, `refreshers`, `manualRefreshers` และ loader ของ Initial Load ผ่าน constructor/argument จึงทดสอบได้โดยไม่ใช้ Supabase หรือ widget
- test ที่ดีต้องตรวจพฤติกรรมที่มองเห็นจากภายนอก คือสถานะความพร้อมที่ getter คืนมา, จำนวนครั้งที่ refresher ถูกเรียก, จำนวนครั้งที่อ่าน `sync_logs` และ error ที่ throw ออกมา ห้ามตรวจ field ภายใน
- พฤติกรรมที่ควรครอบคลุม:
  - Initial Load ที่ module หนึ่งล้มเหลว: module นั้นเป็น "ล้มเหลว" ส่วนที่เหลือเป็น "พร้อม"
  - Manual Refresh force reload แม้ `sync_logs` ไม่เปลี่ยน และไม่ติด cooldown
  - Manual Refresh ใช้ `manualRefreshers` ก่อน ถ้าไม่มีจึงใช้ `refreshers`
  - Manual Refresh ระหว่าง Initial Load รอรอบนั้นแทนการโหลดซ้ำ
  - Manual Refresh หลัง Initial Load ล้มเหลวจะโหลดใหม่ แล้วสถานะกลายเป็น "พร้อม"
  - Manual Refresh ที่ล้มเหลวบน module ที่พร้อมแล้ว คงสถานะ "พร้อม" และ throw
  - หลัง Manual Refresh แล้ว Background Sync จะไม่ reload module นั้นซ้ำ ถ้า `sync_logs` ไม่เปลี่ยนอีก
  - `reset()` ล้างสถานะทั้งหมด
- **Prior art**: `test/sync_provider_test.dart` (fake `getSyncLogs` กับ counter ใน refreshers) ให้เพิ่มเคสต่อจากไฟล์นี้ และปรับเคสเดิมที่เรียก `initialize` ด้วย closure เดียวให้ใช้ signature ใหม่
- ตาม `AGENTS.md` จะเขียน test ใหม่เมื่อผู้ใช้สั่งเท่านั้น แต่เคสเดิมต้องผ่านหลังเปลี่ยน signature

## Out of Scope

- Polling หรือ Supabase Realtime เพื่ออัปเดตข้อมูลระหว่างเปิดหน้าจอค้าง
- Local snapshot cache ของข้อมูลการเงิน (ทั้ง shared_preferences, ไฟล์ และ localStorage)
- เปลี่ยนเงื่อนไขหรือ cooldown ของ Background Sync
- Pull-to-refresh ในหน้า detail, หน้าฟอร์ม, Settings, Trade และ Category
- Lazy load หรือ pagination ของรายการ transaction
- เปลี่ยน import/clear data ให้ไม่รอ Initial Load (ยังคงรอจนเสร็จเหมือนเดิม)

## Further Notes

- `AccountProvider` มี `waitForIdle` และ `TransactionProvider` มี `_stateVersion` ที่ throw `StateError` เมื่อ state เปลี่ยนระหว่างโหลด ให้ระวังกรณีที่ผู้ใช้บันทึกรายการระหว่าง Manual Refresh ถือว่าเป็นความล้มเหลวปกติของ refresh (แสดง SnackBar) ไม่ต้องแก้ logic เดิม
- Recurring notification และ reinstall reminder ที่ตอนนี้ init หลังโหลดข้อมูล ให้ตรวจว่าพึ่งข้อมูลจาก provider หรือไม่ ถ้าพึ่ง ให้รันหลัง Initial Load ของ module ที่เกี่ยวข้องเสร็จ แทนการรันก่อนปล่อย splash
- ก่อนส่งงานต้องรัน `dart format .` และ `tool/check_design.sh`
