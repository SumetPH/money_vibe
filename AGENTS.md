# มาตรฐานการพัฒนาสำหรับ Agent และ Developer (AGENTS.md)

ไฟล์นี้กำหนดมาตรฐานและแนวทางการพัฒนาโค้ดในโปรเจกต์ **Money Vibe** เพื่อให้ AI Agent และนักพัฒนาทำงานร่วมกันได้อย่างมีประสิทธิภาพและรักษาคุณภาพของโค้ด

## Coding Standards

- ถ้ามีการปรับ database ให้เขียน migration ใน /supabase

## 1. เป้าหมายและบริบท (Context)

Money Vibe คือแอปจัดการการเงินส่วนบุคคลที่เน้นความเรียบง่าย แต่ทรงพลัง รองรับการใช้งานแบบ Online-First ด้วย **Supabase** เพื่อให้ข้อมูลซิงค์ตรงกันทุกอุปกรณ์แบบ Real-time พร้อมฟีเจอร์การวิเคราะห์ด้วย AI และการจัดการพอร์ตหุ้น

## 2. สถาปัตยกรรม (Architecture)

โปรเจกต์นี้ใช้ **Repository Pattern** โดยเน้นการทำงานบน Cloud เป็นหลัก

- **Data Layer**:
  - `DatabaseRepository`: Abstract class ที่กำหนด interface
  - `SupabaseRepository`: Implement หลักที่ใช้จัดการข้อมูลบน Cloud
- **Service Layer**:
  - `DatabaseManager`: ทำหน้าที่เป็นจุดศูนย์รวมในการจัดการการเชื่อมต่อ Supabase
- **State Management**:
  - ใช้ **Provider** ในการจัดการ State และเชื่อมต่อกับ `DatabaseManager`
- **Navigation**:
  - ใช้ **GoRouter** ในการจัดการเส้นทาง (Routing) โดยมีการป้องกันหน้าจอด้วย Auth Redirect

## 3. มาตรฐานการเขียนโค้ด (Coding Standards)

### 3.1 UI และ Themes (สำคัญมาก)

- **Dark Mode Support**: ทุก Screen และ Widget ใหม่ **ต้อง** รองรับทั้ง Light และ Dark Mode
- **Color Usage**: ห้ามใช้สีแบบ Hard-code (เช่น `Colors.white`) ให้ใช้สีจาก `lib/theme/app_colors.dart` เท่านั้น
- **Theme Detection**:
  - ดึงสถานะจาก `SettingsProvider`
  - ใช้ `context.isDarkMode` (ถ้ามี extension) หรือ `Provider.of<SettingsProvider>(context).isDarkMode`
  - หากเป็น Private Widget ภายในไฟล์เดียวกัน ให้ส่ง `isDarkMode` ผ่าน constructor แทนการเรียก Provider ซ้ำ

#### 3.1.1 Visual Language ของ Money Vibe

- **List-first, Surface-first**: หน้าจอในแอปควรให้ความรู้สึกเป็น financial utility ที่อ่านง่าย ใช้ `surface` แบบแบนและแบ่งข้อมูลด้วย `Divider`/section มากกว่าการ์ดลอยหลายชั้น
- **หลีกเลี่ยง Card-heavy Dashboard**: ห้ามสร้าง UI ที่เต็มไปด้วย card มีเงา (`boxShadow`) หรือ radius ใหญ่สำหรับข้อมูลปกติ เช่น summary, table, list item, chart section ให้ใช้ full-width surface section แทน
- **ใช้ Card เฉพาะเมื่อจำเป็น**: ใช้ card ได้กับ modal, bottom sheet content, repeated item ที่ต้องแยกบริบทชัดเจน หรือ tool/panel ที่ต้อง framed จริง ๆ เท่านั้น
- **List Item Pattern**: รายการธุรกรรม หุ้น รอบบิล และข้อมูลซ้ำ ๆ ควรเป็น row/list บน `AppColors.surface` หรือ `AppColors.darkSurface` คั่นด้วย `AppColors.divider`/`AppColors.darkDivider`
- **Summary Section Pattern**: summary ด้านบนของหน้าให้เป็น section แบนเต็มความกว้าง มี label เล็ก, ตัวเลขหลัก, metric รอง และ divider ล่าง หลีกเลี่ยง summary card หลายใบถ้าไม่ได้จำเป็นต่อการเปรียบเทียบ
- **Tab Pattern**: `TabBar` ควรใช้ text-only เป็นค่าเริ่มต้น หลีกเลี่ยง icon ใน tab เว้นแต่มีเหตุผลด้านความเข้าใจที่ชัดเจน
- **Selection Pattern**: เมื่อต้องเลือกค่าจากรายการ เช่น พอร์ต บัญชี หมวดหมู่ หรือ filter ให้พยายามใช้ `showModalBottomSheet` เป็นตัวเลือกหลักแทน `DropdownButtonFormField`/dropdown โดยแสดงเป็น row/list บน surface พร้อม check mark ของค่าที่เลือกอยู่ และรองรับ dark mode; ใช้ dropdown เฉพาะกรณีที่เหมาะกับ control สั้น ๆ มากจริง ๆ หรือมี pattern เดิมในบริบทนั้นชัดเจน
- **สีเพื่อสื่อความหมายเท่านั้น**: ใช้สี income/expense/transfer กับตัวเลข สถานะ หรือ badge ที่สื่อความหมายโดยตรง ไม่ควรย้อมพื้นหลังของ logo/icon tile ตามกำไรขาดทุนจนทำให้หน้าดู noisy
- **Token เท่านั้น**: ใช้สีจาก `AppColors` และ radius จาก `AppRadii` เสมอ หลีกเลี่ยง `Colors.*` ใน UI ใหม่ ยกเว้นสีของ AppBar foreground ที่ธีมกำหนดไว้หรือกรณีจำเป็นจริง
- **Bottom Sheet และ Dialog**: bottom sheet ควรกระชับ ใช้ handle, surface background, divider และ action row/list ที่ไม่สูงเกินจำเป็น ต้องรองรับ dark mode
- **ความสอดคล้องก่อนความหวือหวา**: หากไม่แน่ใจ ให้เทียบกับ pattern ปัจจุบันใน `TransactionListScreen`, `PortfolioHoldingItemWidget`, `TradeTrackerScreen`, `StatisticsScreen`, `PortfolioDetailScreen`, และ `CreditCardBillScreen`

### 3.2 การจัดการวันที่และเวลา (DateTime)

- **Local Time**: เก็บเวลาแบบ local ตามเครื่องผู้ใช้เสมอ
- **No Timezone Conversion**: ห้ามทำการแปลง timezone เมื่อบันทึกหรือดึงข้อมูล เพื่อความเรียบง่ายในการใช้งานข้าม Platform
- **Format**: ใช้มาตรฐาน ISO8601 เมื่อส่งข้อมูลเข้า database และใช้ `DateTime` object ภายในแอป

### 3.3 การตั้งชื่อ (Naming Conventions)

- **Files**: ใช้ `snake_case.dart`
- **Classes**: ใช้ `PascalCase`
- **Variables/Methods**: ใช้ `camelCase`
- **Providers**: ลงท้ายด้วย `Provider` เช่น `TransactionProvider`
- **Screens**: ลงท้ายด้วย `Screen` เช่น `SettingsScreen`

## 4. โมเดลและฟีเจอร์สำคัญ

### 4.1 Transactions

- **No Tags**: คอลัมน์ `tags` ถูกถอดออกแล้ว ห้ามใช้งาน
- **Types**: รองรับ Expense, Income, Transfer และ Debt operations

### 4.2 Recurring Transactions

- ใช้สำหรับรายการที่เกิดซ้ำอัตโนมัติ
- มีระบบ `RecurringOccurrence` เพื่อเก็บประวัติการเกิดของแต่ละรอบ

### 4.3 Portfolio & Stocks

- จัดการข้อมูลการถือหุ้น (Stock Holdings)
- มี `StockPriceService` สำหรับดึงราคาล่าสุด และ `StockLogoStorageService` สำหรับจัดการโลโก้

### 4.4 AI Analysis (LLM)

- ใช้ `LlmProvider` สำหรับจัดการบริบทการแชทและการวิเคราะห์ข้อมูลทางการเงินด้วย AI

## 5. กระบวนการทำงาน (Workflow)

### 5.1 ก่อนส่งงาน (Validation)

ก่อนทำการบันทึกหรือ Commit โค้ดที่แก้ไข Agent/Developer ต้องตรวจสอบดังนี้:

1. **Analyze**: รัน `flutter analyze` และต้องไม่มี error/warning
2. **Format**: รัน `dart format .` เพื่อจัดฟอร์แมตโค้ด

### 5.2 การเพิ่มฟีเจอร์ใหม่

1. สร้าง **Model** (หากจำเป็น)
2. เพิ่ม Method ใน `DatabaseRepository` และ Implement ใน `SupabaseRepository`
3. อัปเดต **Provider** ที่เกี่ยวข้อง
4. สร้าง **UI** โดยใช้สีจาก `AppColors` และรองรับ Dark Mode

## 6. กฎเหล็กสำหรับ AI Agent

- **Surgical Updates**: แก้ไขเฉพาะส่วนที่เกี่ยวข้อง ไม่ลบโค้ดส่วนอื่นโดยไม่ได้รับอนุญาต
- **Maintainability**: เขียนโค้ดให้อ่านง่าย มีคอมเมนต์ในส่วนที่ซับซ้อน
- **No Hacks**: ห้ามใช้ `as dynamic` หรือข้ามระบบ Type Safety ของ Dart
- **Security**: ห้าม Hard-code API Key หรือข้อมูลส่วนตัวลงในโค้ด (ให้ใช้ `lib/services/settings_provider.dart` หรือเครื่องมือจัดการ config แทน)
- **Supabase Only**: เลิกใช้ SQLite แล้ว ไม่ต้อง implement หรืออ้างถึงโค้ดส่วนที่เกี่ยวกับ SQLite เดิม

## Testing

- ไม่ต้องเขียน test สำหรับงานในโปรเจกต์นี้
- หากมี test เดิมอยู่และไม่ได้ถูกขอให้แก้โดยตรง ไม่ต้อง maintain หรือเพิ่ม coverage
- ก่อนส่งงานให้รันเฉพาะ `dart format .` และ `flutter analyze`
