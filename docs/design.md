# Money Vibe Design

เอกสารนี้เป็น source of truth สำหรับ UI/UX ของ Money Vibe รวมถึงหน้า Account, form, detail, modal และ widget ที่ใช้ร่วมกัน. `AGENTS.md` ชี้มาที่เอกสารนี้; ADR บันทึกเหตุผลของการเลือกแนวทาง และ `CONTEXT.md` นิยามศัพท์โดเมน. เมื่อโค้ดปัจจุบันต่างจากเอกสารนี้ ให้ใช้เอกสารนี้เป็นเป้าหมายของงาน design และตรวจ flow จริงก่อนแก้. งานแก้ UI ไม่เปลี่ยนการคำนวณ, validation, Provider, repository, debounce หรือ navigation behavior โดยไม่ได้รับคำสั่ง.

## Shared widgets และ tokens

ห้ามสร้าง UI primitive เหล่านี้เองในหน้าจอ ให้ใช้ของกลางเสมอ; ถ้าต้องการหน้าตาใหม่ให้แก้ที่ widget/token กลางแล้วตรวจทุก caller. `tool/check_design.sh` ตรวจกติกานี้อัตโนมัติ.

| ใช้                                                                   | แทน                                                    | ไฟล์                                      |
| --------------------------------------------------------------------- | ------------------------------------------------------ | ----------------------------------------- |
| `AppSwitch`                                                           | `CupertinoSwitch`                                      | `lib/widgets/app_switch.dart`             |
| `AppSectionHeader`, `AppInsetCard`, `AppCardDivider`                  | helper `_buildSectionHeader` / `_buildInsetCard` ในหน้า | `lib/widgets/app_inset_card.dart`         |
| `AppCloseButton` (ฟอร์ม), `AppBackButton` (หน้ารอง), `AppSaveButton` | ปุ่ม leading/บันทึกที่สร้างเองบน AppBar               | `lib/widgets/app_bar_buttons.dart`        |
| `AppBarActionButton`                                                  | ปุ่ม icon action อื่นบน AppBar                         | `lib/widgets/app_bar_action_button.dart`  |
| `showAppConfirmDialog`                                                | `AlertDialog` สำหรับยืนยัน                             | `lib/widgets/app_confirm_dialog.dart`     |
| `showAppModalBottomSheet`, `AppModalBottomSheetHeader`, `AppDraggableSheet` | `showModalBottomSheet` / `DraggableScrollableSheet` | `lib/widgets/app_modal_bottom_sheet.dart` |
| `AppColors.*For(isDarkMode)` และ `AppRadii`                           | `Color(0x…)` และ ternary สี dark/light ในหน้า          | `lib/theme/`                              |

Color tokens ที่ใช้บ่อย: `backgroundFor`, `surfaceFor`, `textPrimaryFor`, `textSecondaryFor`, `expenseFor`, `borderFor` (ขอบการ์ด/ตัวแบ่ง, divider alpha 0.4), `switchInactiveFor`, `insetFillFor` (ช่องกรอก/segmented control ที่ยุบลงในการ์ด), `raisedFillFor` (ปุ่มรองบนการ์ด), `saveButtonFor`, `accentFor(isDarkMode, themeColor)` และ `onHeader`. Dialog ที่มีช่องกรอกหรือหลายตัวเลือก (เช่น แก้เงินสด, reset Peak, ลืมรหัสผ่าน) ใช้ `AlertDialog` ได้โดยใส่ `// design-check: allow <เหตุผล>` บรรทัดก่อนหน้า และใช้พื้น `surfaceFor`.

## ภาษาภาพรวม

- ใช้ iOS Inset Grouped แบบ surface-first: canvas สงบ, การ์ดที่แบ่งข้อมูลชัด, dark mode first และ light mode ที่มี contrast พอ. สี income, expense, transfer และ debt repayment สื่อความหมายของตัวเลขหรือสถานะ ไม่ใช้ระบายพื้นหลังเพื่อความสวยงาม.
- อ่าน theme จาก `SettingsProvider`; ใช้ `AppColors` และ `AppRadii` เป็น tokens. ใช้ alpha กับสี semantic หรือดำ/ขาวเพื่อสร้าง depth ได้. รูปและไอคอนบัญชีใช้ `AccountIconWidget`; โลโก้หุ้นใช้ `HoldingThumbnailWidget`.
- ใช้ surface แทน elevation หนักหรือ gradient. การ์ดหลักมีระยะขอบแนวนอน 16, มุม `AppRadii.xLarge`, ขอบ `AppColors.borderFor` หนา 1 (`AppInsetCard`). หัวข้อ section อยู่ **นอก** การ์ด (`AppSectionHeader`: `textSecondary`, 12sp, `FontWeight.w600`, `letterSpacing: 0.5`, padding 20/16/20/6).
- แถวใน form/setting/รายการ: ไอคอนหรือ avatar 32–40px ทางซ้าย, ชื่อ 15sp `FontWeight.w600` และคำอธิบาย 12sp, control หรือค่าที่เลือกทางขวา. ตัวแบ่งในการ์ดใช้ `AppCardDivider` (สี `borderFor` หนา 1px); แถวรายการเต็มความกว้างใช้ `indent: 0`, แถวฟอร์มที่มีไอคอนนำใช้ `indent: 60, endIndent: 16`, แถวฟอร์มหุ้นใช้ `indent: 16`.
- สวิตช์ใช้ `AppSwitch` เท่านั้น (track เปิดเป็น accent ของธีม, track ปิดเป็น `switchInactiveFor`). สถานะใช้แคปซูล `AppRadii.full` และพื้น semantic tint ประมาณ 12%. ชุดตัวเลขเปรียบเทียบใช้ metric grid สองคอลัมน์หรือ 2×3 ให้ label และค่าเทียบกันได้.
- ช่องกรอกจำนวนเงิน/ตัวเลขใช้กล่องพื้นนุ่ม มุมมน จัดตัวเลขชิดขวา มีสกุลเงินหรือหน่วยในกล่อง และ `onTapOutside` ปิดคีย์บอร์ด. `TextField` ที่อยู่ใน card ใช้ `InputBorder.none` สำหรับทุก border state และ `filled: false` เพื่อไม่ให้ Material outer border/fill ซ้อน. ช่องค้นหาใช้ `CupertinoSearchTextField` หรือ search pill ที่มีไอคอนอยู่ภายใน.

## หน้าจอและการนำทาง

- Main Tab คือพื้นที่หลักที่รักษา state เมื่อสลับแท็บ; Secondary Screen คือหน้าที่เปิดต่อจาก flow และไม่ใช่แท็บหลัก. Main Tabs บน mobile คือ **บัญชี, แผน, รายการ, สถิติ**. `MainTabScreen` เป็นเจ้าของ `IndexedStack`, drawer และ `AppBottomNavigation` แบบ floating capsule พร้อมปุ่มเพิ่มรายการตรงกลาง; เงาของ capsule เบา (ดำ alpha 0.2, blur 8, offset (0, 2)). หน้า Account List ที่อยู่ใน tab ไม่สร้าง bottom navigation หรือ drawer ซ้ำ. ที่ความกว้างตั้งแต่ 800px ใช้ `AppSidebar` ของ shell; หน้ารองใช้ action ของหน้านั้นตาม flow.
- Header ของ Main Tab ใช้ canvas color ไม่มี elevation, supertitle 13sp สีรองและ title 30sp สีหลัก, `toolbarHeight: 100`, ชิดซ้าย. หน้า form/detail ใช้ title กลาง 18sp `FontWeight.w700`, `centerTitle: true`, `leadingWidth: 64`, พื้นสี canvas ไม่มี elevation/`scrolledUnderElevation`.
  - **หน้าฟอร์ม** (เพิ่ม/แก้ไข) ใช้ `AppCloseButton`: `Icons.close` ขนาด 20 บน circular surface ขอบ `borderFor`, tooltip `ปิด`; ส่ง `onPressed` ที่ปิดคีย์บอร์ดก่อน pop และเป็น `null` ขณะ loading.
  - **หน้ารอง** ที่เปิดดูต่อ (Portfolio Detail, Credit Card Bill, Recurring Detail, Broker Report List, Transaction List แบบกรอง, settings ย่อย, Auth ฯลฯ) ใช้ `AppBackButton`: `Icons.arrow_back_rounded` แบบไม่มี surface, tooltip `ย้อนกลับ`.
  - ปุ่มบันทึกของ**ทุกฟอร์ม** (Account, Transaction, Category, Budget, Recurring, Holding/Buy/Sell, Stock Trade, Broker Report) ใช้ `AppSaveButton`: pill `AppRadii.full` สี `saveButtonFor`, padding 16×8, `Icons.check` 16 + label 14sp `w700` สีดำ, แสดงทั้งโหมดเพิ่มและแก้ไข และเปลี่ยนเป็น spinner 16px ขณะ loading. label ค่าเริ่มต้นคือ `บันทึก`; ฟอร์มซื้อ/ขายหุ้นใช้ `ซื้อ`/`ขาย`.
  - ปุ่ม icon action อื่นบน header ใช้ `AppBarActionButton` (circular surface + ripple); action ลบใช้สี expense.
- การเลือกค่าจากรายการใช้ `showAppModalBottomSheet` (surface, มุมบน `AppRadii.xLarge`, drag handle, barrier ดำ alpha 0.5, safe area) และ `AppModalBottomSheetHeader` (16sp `w700` กึ่งกลาง) พร้อม selected state ที่ชัด. Selection sheet ที่มีรายการยาว (account/category picker, ชนิด/ไอคอน/สีใน form, net-worth filter) ใช้ `AppDraggableSheet` (เต็มความสูง, ลากลงได้ถึง 0.3) คู่กับ `showAppModalBottomSheet(isScrollControlled: true)`. Menu sheet ใช้ label 15sp น้ำหนักปกติ (ไม่หนา) และ action ลบใช้สี expense. แถวที่แตะได้ใน sheet ใช้ `Material` ที่ clip ตามมุมเพื่อให้ ripple เห็น. Dialog ใช้กับการยืนยันการกระทำ (`showAppConfirmDialog`: ปุ่มยกเลิกสีข้อความหลัก, ปุ่มยืนยันสี accent หรือ expense เมื่อ `isDestructive`; ทำงานหลังผู้ใช้ยืนยันแล้วจึงปิดหน้า) หรือแก้ค่าสั้น ๆ ที่ต้องคงบริบทเดิม; แบบฟอร์มหลายช่องใช้หน้าฟอร์ม. ทุก sheet/dialog รองรับ safe area, การเลื่อน, คีย์บอร์ด และ light/dark.
- Form บันทึกจำนวนเงินใช้ลำดับ: ตัวเลือกชนิดรายการถ้ามี → amount hero → selection และ metadata cards. ฟิลด์เฉพาะ flow เพิ่มในกลุ่มที่เกี่ยวข้อง. อย่าสร้างสไตล์ฟอร์มอีกชุดสำหรับ transaction, recurring หรือ Account.

## Account: โครงสร้างข้อมูลที่แสดง

Account ครอบคลุมเงินสด/เงินฝาก, บัญชีธนาคาร, บัตรเครดิต, หนี้สิน, ทรัพย์สิน, เงินลงทุน/เงินออม และพอร์ตหุ้น US/ไทย. จัดกลุ่มตาม `AccountGroup` ที่ model กำหนด; ลำดับในหน้ารายการ, picker และ summary อาจต่างกัน. ใช้ `AccountProvider` และ `TransactionProvider` สำหรับยอดเงินจริงและ `SettingsProvider` สำหรับ theme/filter. UI ไม่สร้างสูตรยอดเงินหรืออัตราแลกเปลี่ยนใหม่.

- **ซ่อนบัญชี** ส่งผลต่อการแสดงในรายการหลัก; **ไม่รวมในทรัพย์สินสุทธิ** ส่งผลต่อ net worth; ตัวกรอง net worth เป็นอีกการเลือกหนึ่ง. แสดงคำอธิบายและ control แยกกันเสมอ. บัญชีที่ซ่อนยังอาจถูกนับใน net worth ถ้าไม่ได้ถูก exclude/filter ออก.
- ยอดบัญชีอาจเป็น THB หรือ USD; แสดงหน่วยชัดเจนที่ตัวเลขและในช่องกรอก. ยอดรวมที่แสดงเป็น THB ต้องใช้ conversion ของระบบ. สีและเครื่องหมายของหนี้/ยอดติดลบต้องตรงกับค่าที่ Provider ส่งมา.
- ชนิดบัญชีกำหนดปลายทางเมื่อเปิดรายการ: พอร์ตไปหน้า Portfolio Detail, บัตรเครดิตไปหน้า Credit Card Bill, ชนิดอื่นไป Transaction List ที่กรอง account. การแก้บัญชีเปิด Account Form โดยยังคง account เดิม.

## Account: สัญญาของแต่ละ surface

| Surface                          | โครงสร้างและข้อมูลสำคัญ                                                                                                                               | Action และสถานะที่ต้องรักษา                                                                                                                                                               |
| -------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Account List                     | Header หลัก → net-worth summary → กลุ่มบัญชีพร้อมยอดกลุ่มและแถวบัญชี. แต่ละแถวมี icon, ชื่อ, ยอดและสกุลเงิน; แสดงเฉพาะบัญชีที่ไม่ถูกซ่อนในรายการปกติ. | เปิดปลายทางตามชนิด, เพิ่มบัญชี/ธุรกรรม, แก้บัญชี, reorder กลุ่มและบัญชี, ดูบัญชีที่ซ่อน, เปิด summary และ net-worth filter. โหมด reorder ต้องแสดง affordance ของการลาก.                   |
| Account Form                     | Amount hero → ข้อมูลบัญชี → รูปลักษณ์ → เงื่อนไขตามชนิด/สกุลเงิน → การแสดงผลและคำนวณ; delete อยู่ท้ายหน้าแก้ไข.                                       | ชื่อ, ชนิด, สกุลเงิน, วันที่เริ่ม, รูป/ไอคอน/สี, exchange rate ของ USD, วันสรุปยอดของบัตร และสวิตช์ hide/exclude. คง validation, loading, save/close และ delete confirmation.             |
| Credit Card Bill                 | สรุปยอดที่เด่นชัด → รอบบิล/สถานะ/ยอดที่เกี่ยวข้องเป็นการ์ดอ่านเทียบกันได้ → empty state เมื่อไม่มีรอบ.                                                | เปิดรายการธุรกรรมที่กรองตามรอบบิล; อย่าเปลี่ยนนิยามยอดค้างชำระหรือการชำระ.                                                                                                                |
| Portfolio Detail                 | Hero แสดงมูลค่าพอร์ตและเงินสด → tab พอร์ต/แผนการลงทุน. แถว holding ใช้ thumbnail, ticker, จำนวน, มูลค่าและสถานะที่อ่านเทียบกันได้.                    | รีเฟรชราคา, ซื้อ/ขาย/แก้ holding, เพิ่ม holding ตั้งต้น, จัดกลุ่ม/เรียง, เปิด report/analysis ตามชนิดพอร์ต, แก้เงินสด/อัตราแลกเปลี่ยน. คง loading/error และข้อจำกัดของ US/Thai portfolio. |
| Investment Plan                  | การ์ดเป้าหมายและ metric grid สำหรับ allocation/rebalance/recommendation.                                                                              | เลือกหุ้น, แก้ target และยอดซื้อ, สถานะ DCA/confirmation; ไม่เปลี่ยนสูตรหรือการบันทึก.                                                                                                    |
| Holding forms                    | Buy/Sell: `นำเข้าจากภาพ` (เฉพาะ USD บน iOS/Android และไม่ใช่การแก้ประวัติ) → `วันที่คำสั่งสำเร็จ` (หลังเติมจากภาพ) → ข้อมูลการซื้อ/ขาย → ค่าธรรมเนียม → หลังการซื้อ/ขาย → (Sell) สรุปผลการขาย. Holding ตั้งต้น: ข้อมูลหุ้น → แผนการขาย. | validation, save, cancel และข้อมูลเฉพาะ buy/sell คงเดิม. การลบ holding อยู่ใน menu sheet ของแถว holding ไม่อยู่ในฟอร์ม. การนำเข้าจากภาพผ่าน `BrokerOrderImportButton`: เลือกโบรกเกอร์ใน sheet → เลือกรูป → dialog ยืนยันก่อนเติมฟอร์ม; อ่านไม่ได้/ticker ไม่ตรงแจ้งด้วย SnackBar. |
| Portfolio Analyze                | บทสนทนาและ input อ่านง่ายในทั้งสอง theme; แยก loading, message และ error ให้เห็นชัด.                                                                  | คงการส่งข้อความ, ลำดับข้อความ, scroll และการกลับมาที่หน้าเดิม.                                                                                                                            |
| Broker Report (จาก US portfolio) | รายการรายปีพร้อมยอดรวม USD/THB; form แยกปี, เงินทุน, เงินปันผล, ภาษี, เงินโอนกลับและหมายเหตุ.                                                         | เพิ่ม/แก้รายงาน, validation ของปีและจำนวนเงิน, สถานะบันทึก/ข้อผิดพลาด; ใช้กับ US portfolio ตาม entry point เดิม.                                                                          |

## Account: modal และ widget ที่ใช้ร่วมกัน

- **Menu sheets** ของ Account List, account row, net-worth summary และ Portfolio Detail แสดงชื่อ sheet, action ที่จัดกลุ่มชัด และ destructive action ที่แยกสี/ตำแหน่ง. ห้ามทำ action เดิมหายเมื่อจัด layout ใหม่.
- **Selection sheets** ใน Account Form (ชนิดบัญชี, สกุลเงิน, วันสรุปยอด, ไอคอน/รูป, สี), Investment Plan (หุ้น) และ `AccountPickerBottomSheet` ใช้ title, แถวแบบ grouped surface, selected state และลำดับกลุ่มจาก model. Account picker ที่ใช้ใน Transaction/Recurring ต้องคงบัญชีที่เลือก, ยอดและตัวกรอง debt-only.
- **Summary/filter sheets** แสดงสินทรัพย์, หนี้สิน, ยอดกลุ่ม และบัญชีที่ร่วมคำนวณด้วย label ที่แยกความหมาย. การเลือก filter ต้องไม่เปลี่ยน hidden/exclude ของบัญชี.
- **Dialogs** ใช้ยืนยันการลบ/การเปลี่ยนสถานะที่มีผล และแก้ค่าพอร์ตแบบสั้น; ต้องบอกผลของ action และมีทางยกเลิก. `AccountIconWidget`, `HoldingThumbnailWidget`, `AppBarActionButton`, `BrokerOrderImportButton`, `showAppModalBottomSheet` และ `AppModalBottomSheetHeader` เป็น shared seam ที่ควรแก้ก่อนสร้างรูปแบบซ้ำในแต่ละหน้า.

## ก่อนจบงาน design

ตรวจทุก surface ที่เกี่ยวข้อง รวม state ปกติ/ว่าง/loading/error, light/dark, mobile/จอกว้าง, sheet/dialog, คีย์บอร์ด, action และ navigation. ถ้าแก้ shared widget ให้ตรวจทุก caller และรัน `tool/check_design.sh`. รักษา calculations, Provider, repository, validation, callback และเวลารอเดิม; การเปลี่ยนพฤติกรรมธุรกิจต้องเป็นงานที่ผู้ใช้สั่งแยกต่างหาก.
