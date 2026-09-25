# Money Vibe Design

เอกสารนี้เป็น source of truth สำหรับ UI/UX ของ Money Vibe รวมถึงหน้า Account, form, detail, modal และ widget ที่ใช้ร่วมกัน. `AGENTS.md` ชี้มาที่เอกสารนี้; ADR บันทึกเหตุผลของการเลือกแนวทาง และ `CONTEXT.md` นิยามศัพท์โดเมน. เมื่อโค้ดปัจจุบันต่างจากเอกสารนี้ ให้ใช้เอกสารนี้เป็นเป้าหมายของงาน design และตรวจ flow จริงก่อนแก้. งานแก้ UI ไม่เปลี่ยนการคำนวณ, validation, Provider, repository, debounce หรือ navigation behavior โดยไม่ได้รับคำสั่ง.

## ภาษาภาพรวม

- ใช้ iOS Inset Grouped แบบ surface-first: canvas สงบ, การ์ดที่แบ่งข้อมูลชัด, dark mode first และ light mode ที่มี contrast พอ. สี income, expense, transfer และ debt repayment สื่อความหมายของตัวเลขหรือสถานะ ไม่ใช้ระบายพื้นหลังเพื่อความสวยงาม.
- อ่าน theme จาก `SettingsProvider`; ใช้ `AppColors` และ `AppRadii` เป็น tokens. ใช้ alpha กับสี semantic หรือดำ/ขาวเพื่อสร้าง depth ได้. รูปและไอคอนบัญชีใช้ `AccountIconWidget`; โลโก้หุ้นใช้ `HoldingThumbnailWidget`.
- ใช้ surface แทน elevation หนักหรือ gradient. การ์ดหลักมีระยะขอบแนวนอน 16, มุม `AppRadii.xLarge`, ขอบ `dividerColor.withValues(alpha: 0.4)` หนา 1. หัวข้อ section อยู่ **นอก** การ์ด ใช้ `textSecondary`, 12sp, `FontWeight.w600`, `letterSpacing: 0.5` (ภาษาอังกฤษใช้ตัวพิมพ์ใหญ่เมื่อเหมาะสม).
- แถวใน form/setting: ไอคอนหรือ avatar 32–40px ทางซ้าย, ชื่อ 15sp หนากึ่งกลางและคำอธิบาย 12sp, control หรือค่าที่เลือกทางขวา. แถวรายการในกลุ่มใช้ `AppColors.listDividerFor(isDarkMode)` หนา 1px เต็มความกว้างของรายการ; menu card สามารถใช้ตัวแบ่งที่เยื้องตาม layout ของ menu.
- สวิตช์ใช้ `CupertinoSwitch` พร้อม `activeColor` เป็น accent/semantic color และ `inactiveColor` ชัดเจน (dark `Color(0xFF39393D)`, light `Color(0xFFE9E9EA)` ตาม switch ที่มีอยู่). สถานะใช้แคปซูล `AppRadii` และพื้น semantic tint ประมาณ 12%. ชุดตัวเลขเปรียบเทียบใช้ metric grid สองคอลัมน์หรือ 2×3 ให้ label และค่าเทียบกันได้.
- ช่องกรอกจำนวนเงิน/ตัวเลขใช้กล่องพื้นนุ่ม มุมมน จัดตัวเลขชิดขวา มีสกุลเงินหรือหน่วยในกล่อง และ `onTapOutside` ปิดคีย์บอร์ด. `TextField` ที่อยู่ใน card ใช้ `InputBorder.none` สำหรับทุก border state และ `filled: false` เพื่อไม่ให้ Material outer border/fill ซ้อน. ช่องค้นหาใช้ `CupertinoSearchTextField` หรือ search pill ที่มีไอคอนอยู่ภายใน.

## หน้าจอและการนำทาง

- Main Tab คือพื้นที่หลักที่รักษา state เมื่อสลับแท็บ; Secondary Screen คือหน้าที่เปิดต่อจาก flow และไม่ใช่แท็บหลัก. Main Tabs บน mobile คือ **บัญชี, แผน, รายการ, สถิติ**. `MainTabScreen` เป็นเจ้าของ `IndexedStack`, drawer และ `AppBottomNavigation` แบบ floating capsule พร้อมปุ่มเพิ่มรายการตรงกลาง. หน้า Account List ที่อยู่ใน tab ไม่สร้าง bottom navigation หรือ drawer ซ้ำ. ที่ความกว้างตั้งแต่ 800px ใช้ `AppSidebar` ของ shell; หน้ารองใช้ action ของหน้านั้นตาม flow.
- Header ของ Main Tab ใช้ canvas color ไม่มี elevation, supertitle 13sp สีรองและ title 30sp สีหลัก, `toolbarHeight: 100`, ชิดซ้าย. หน้า form/detail ใช้ title กลาง 18sp และปุ่มย้อน/ปิดบน circular surface (`leadingWidth: 64`). ปุ่ม action บน header ใช้ circular surface และ touch ripple; action ลบใช้สี expense.
- การเลือกค่าจากรายการใช้ `showAppModalBottomSheet` และ `AppModalBottomSheetHeader` พร้อม selected state ที่ชัด. แถวที่แตะได้ใน sheet ใช้ `Material` ที่ clip ตามมุมเพื่อให้ ripple เห็น. Dialog ใช้กับการยืนยันการกระทำหรือแก้ค่าสั้น ๆ ที่ต้องคงบริบทเดิม; แบบฟอร์มหลายช่องใช้หน้าฟอร์ม. ทุก sheet/dialog รองรับ safe area, การเลื่อน, คีย์บอร์ด และ light/dark.
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
| Holding forms                    | Amount/quantity/price ที่เด่นชัดก่อน metadata; cards แยกข้อมูลการซื้อ ขาย และ holding ตั้งต้น.                                                        | validation, save, cancel, delete/confirmation และข้อมูลเฉพาะ buy/sell คงเดิม.                                                                                                             |
| Portfolio Analyze                | บทสนทนาและ input อ่านง่ายในทั้งสอง theme; แยก loading, message และ error ให้เห็นชัด.                                                                  | คงการส่งข้อความ, ลำดับข้อความ, scroll และการกลับมาที่หน้าเดิม.                                                                                                                            |
| Broker Report (จาก US portfolio) | รายการรายปีพร้อมยอดรวม USD/THB; form แยกปี, เงินทุน, เงินปันผล, ภาษี, เงินโอนกลับและหมายเหตุ.                                                         | เพิ่ม/แก้รายงาน, validation ของปีและจำนวนเงิน, สถานะบันทึก/ข้อผิดพลาด; ใช้กับ US portfolio ตาม entry point เดิม.                                                                          |

## Account: modal และ widget ที่ใช้ร่วมกัน

- **Menu sheets** ของ Account List, account row, net-worth summary และ Portfolio Detail แสดงชื่อ sheet, action ที่จัดกลุ่มชัด และ destructive action ที่แยกสี/ตำแหน่ง. ห้ามทำ action เดิมหายเมื่อจัด layout ใหม่.
- **Selection sheets** ใน Account Form (ชนิดบัญชี, สกุลเงิน, วันสรุปยอด, ไอคอน/รูป, สี), Investment Plan (หุ้น) และ `AccountPickerBottomSheet` ใช้ title, แถวแบบ grouped surface, selected state และลำดับกลุ่มจาก model. Account picker ที่ใช้ใน Transaction/Recurring ต้องคงบัญชีที่เลือก, ยอดและตัวกรอง debt-only.
- **Summary/filter sheets** แสดงสินทรัพย์, หนี้สิน, ยอดกลุ่ม และบัญชีที่ร่วมคำนวณด้วย label ที่แยกความหมาย. การเลือก filter ต้องไม่เปลี่ยน hidden/exclude ของบัญชี.
- **Dialogs** ใช้ยืนยันการลบ/การเปลี่ยนสถานะที่มีผล และแก้ค่าพอร์ตแบบสั้น; ต้องบอกผลของ action และมีทางยกเลิก. `AccountIconWidget`, `HoldingThumbnailWidget`, `showAppModalBottomSheet` และ `AppModalBottomSheetHeader` เป็น shared seam ที่ควรแก้ก่อนสร้างรูปแบบซ้ำในแต่ละหน้า.

## ก่อนจบงาน design

ตรวจทุก surface ที่เกี่ยวข้อง รวม state ปกติ/ว่าง/loading/error, light/dark, mobile/จอกว้าง, sheet/dialog, คีย์บอร์ด, action และ navigation. ถ้าแก้ shared widget ให้ตรวจทุก caller. รักษา calculations, Provider, repository, validation, callback และเวลารอเดิม; การเปลี่ยนพฤติกรรมธุรกิจต้องเป็นงานที่ผู้ใช้สั่งแยกต่างหาก.
