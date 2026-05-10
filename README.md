# Money Vibe

Money Vibe คือแอป Flutter สำหรับจัดการการเงินส่วนบุคคลที่เน้นความเรียบง่าย แต่ทรงพลัง รองรับการใช้งานแบบ **Online-First (Supabase)** เพื่อให้ข้อมูลซิงค์ตรงกันทุกอุปกรณ์แบบ Real-time พร้อมฟีเจอร์การวิเคราะห์อัจฉริยะด้วย AI และการจัดการพอร์ตการลงทุนที่ครบวงจร

## ฟีเจอร์หลัก

- **Cloud-First Architecture**: ข้อมูลซิงค์อัตโนมัติข้ามทุกอุปกรณ์ผ่าน Supabase
- **Financial Tracking**: จัดการบัญชีเงินสด, ธนาคาร, และบัตรเครดิต
- **Smart Transactions**: บันทึกรายรับ-รายจ่าย พร้อมระบบโอนเงินและชำระหนี้สิน
- **AI Analysis (LLM)**: วิเคราะห์พอร์ตการลงทุนและข้อมูลทางการเงินด้วย AI อัจฉริยะ
- **Portfolio & Stocks**: ติดตามราคาหุ้นอัตโนมัติ (Finnhub) และจัดการพอร์ตการลงทุน
- **Recurring Transactions**: ระบบรายการอัตโนมัติที่เกิดซ้ำ (รายวัน, รายสัปดาห์, รายเดือน)
- **Budgeting**: วางแผนงบประมาณตามหมวดหมู่ พร้อมระบบแจ้งเตือนเมื่อใกล้เต็ม
- **Visual Statistics**: กราฟและสรุปภาพรวมการเงินที่สวยงามและเข้าใจง่าย
- **Data Portability**: นำเข้าและส่งออกข้อมูลผ่านไฟล์ CSV
- **Dark Mode Native**: รองรับทั้ง Light และ Dark Mode อย่างสมบูรณ์แบบ
- **Multi-Platform**: รองรับ Android, iOS, Web, macOS, Linux และ Windows

## Tech Stack

- **Framework**: Flutter / Dart
- **State Management**: Provider
- **Architecture**: Repository Pattern (Cloud-First)
- **Database & Auth**: Supabase
- **Navigation**: GoRouter
- **Storage**: Shared Preferences (Local Config) & Supabase Storage (Icons/Logos)
- **Charts**: fl_chart
- **AI Integration**: Edge Functions & Provider-based LLM Service

## เริ่มต้นใช้งาน

### Prerequisites

- Flutter SDK `^3.10.0`
- Supabase Project (URL & Anon Key)
- Finnhub API Key (สำหรับการดึงราคาหุ้น)

### การตั้งค่า

1. **Install Dependencies**:
   ```bash
   flutter pub get
   ```

2. **Supabase Setup**:
   - สร้างโปรเจกต์ใน Supabase Dashboard
   - รัน SQL schema จาก `supabase/schema.sql`
   - ดูขั้นตอนละเอียดได้ที่ [SUPABASE_SETUP.md](docs/SUPABASE_SETUP.md)

3. **Run App**:
   - เปิดแอปและกรอก Supabase URL/Key ในหน้า Setup ครั้งแรก
   - สมัครสมาชิก/เข้าสู่ระบบเพื่อเริ่มใช้งาน

## คำสั่งที่ใช้บ่อย

### Quality Control

```bash
flutter analyze  # ตรวจสอบคุณภาพโค้ด
flutter test     # รัน unit และ widget tests
dart format .    # จัดรูปแบบโค้ดตามมาตรฐาน
```

### Build Scripts

เราได้เตรียม scripts สำหรับการ build ในแต่ละ platform ไว้ที่โฟลเดอร์ `scripts/`:

```bash
./scripts/build_android.sh  # Build Android APK
./scripts/build_ios.sh      # Build iOS Framework
./scripts/build_web.sh      # Build Web App
./scripts/build_macos.sh    # Build macOS App
```

## มาตรฐานการพัฒนา (Development Standards)

เพื่อให้โค้ดมีคุณภาพและเป็นไปในทิศทางเดียวกัน:

- **Dark Mode**: ทุก UI Component ต้องรองรับทั้ง Light และ Dark Mode
- **Coloring**: ใช้สีจาก `AppColors` เท่านั้น ห้าม Hard-code
- **DateTime**: ใช้เวลา Local ตามเครื่องผู้ใช้เสมอ (ISO8601)
- **No SQLite**: แอปทำงานบน Supabase เท่านั้น ไม่ต้อง implement logic สำหรับ local database
- **Validation**: ต้องรัน `flutter analyze` และผ่านทั้งหมดก่อนส่งงาน

รายละเอียดเพิ่มเติมดูได้ที่ [AGENTS.md](AGENTS.md)

## เอกสารที่เกี่ยวข้อง

- [AGENTS.md](AGENTS.md) - มาตรฐานการพัฒนาสำหรับ Developer/Agent
- [SUPABASE_SETUP.md](docs/SUPABASE_SETUP.md) - คู่มือตั้งค่าระบบ Cloud
- [MIGRATION_SUMMARY.md](docs/MIGRATION_SUMMARY.md) - สรุปการเปลี่ยนผ่านสถาปัตยกรรม
- [IOS_IPA_ALTSTORE.md](docs/IOS_IPA_ALTSTORE.md) - คู่มือ Build สำหรับ iOS (AltStore)

---
*Money Vibe - Your personal finance, perfectly in sync.*
