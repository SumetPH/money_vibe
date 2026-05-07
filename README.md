# Money Vibe

Money Vibe คือแอป Flutter สำหรับจัดการการเงินส่วนบุคคล รองรับบัญชีหลายประเภท รายการรับ-จ่าย งบประมาณ รายการประจำ หมวดหมู่ สถิติ และพอร์ตการลงทุน โดยใช้ Supabase เป็นฐานข้อมูลบน Cloud เพื่อให้ข้อมูลซิงค์ข้ามอุปกรณ์ได้

## ฟีเจอร์หลัก

- จัดการบัญชีเงินสด ธนาคาร บัตรเครดิต และพอร์ตการลงทุน
- บันทึกรายการรายรับ รายจ่าย และโอนเงิน
- จัดการหมวดหมู่และงบประมาณ
- สร้างรายการประจำ พร้อมระบบแจ้งเตือน
- ดูสถิติและสรุปภาพรวมการเงิน
- ติดตาม holdings ในพอร์ต พร้อมการตั้งค่า Finnhub API สำหรับราคาหุ้น
- วิเคราะห์พอร์ตด้วย LLM API
- นำเข้าและส่งออกข้อมูลผ่าน CSV
- รองรับ Light Mode และ Dark Mode
- ใช้งานบน Android, iOS, Web, macOS, Linux และ Windows ตาม platform ที่ Flutter รองรับ

## Tech Stack

- Flutter / Dart
- Provider สำหรับ state management
- GoRouter สำหรับ navigation
- Supabase สำหรับ authentication และ cloud database
- Shared Preferences สำหรับ config ภายในเครื่อง
- fl_chart สำหรับกราฟและสถิติ
- flutter_local_notifications สำหรับแจ้งเตือนรายการประจำ

## เริ่มต้นใช้งาน

### Prerequisites

- Flutter SDK ที่รองรับ Dart `^3.10.0`
- Supabase project
- Xcode สำหรับ build iOS/macOS
- Android Studio หรือ Android SDK สำหรับ build Android

### ติดตั้ง dependencies

```bash
flutter pub get
```

### ตั้งค่า Supabase

1. สร้าง Supabase project
2. เปิดใช้งาน Email authentication
3. รัน SQL schema จากไฟล์ `supabase/schema.sql`
4. คัดลอก `Project URL` และ `anon public key`
5. เปิดแอปครั้งแรก แล้วกรอกค่าทั้งสองในหน้า Setup

รายละเอียดเต็มดูได้ที่ [SUPABASE_SETUP.md](SUPABASE_SETUP.md)

### Run

```bash
flutter run
```

สำหรับ Web:

```bash
flutter run -d chrome
```

## คำสั่งที่ใช้บ่อย

### Analyze

```bash
flutter analyze
```

### Test

```bash
flutter test
```

### Build Android

```bash
flutter build apk --debug
flutter build apk --release
```

หรือใช้ script:

```bash
./scripts/build_android.sh
```

### Build iOS IPA

```bash
flutter build ipa --release --no-tree-shake-icons --export-options-plist=ios/ExportOptions-development.plist
```

รายละเอียดสำหรับ AltStore ดูได้ที่ [IOS_IPA_ALTSTORE.md](IOS_IPA_ALTSTORE.md)

### Build Web

```bash
./scripts/build_web.sh
```

### Build macOS

```bash
./scripts/build_macos.sh
```

## โครงสร้างโปรเจกต์

```text
lib/
├── main.dart
├── models/
├── providers/
├── repositories/
├── screens/
│   ├── account/
│   ├── auth/
│   ├── budget/
│   ├── category/
│   ├── recurring/
│   ├── settings/
│   ├── splash/
│   ├── statistics/
│   └── transaction/
├── services/
├── theme/
├── utils/
└── widgets/

supabase/
├── functions/
└── migrations/


scripts/
├── build_android.sh
├── build_ios.sh
├── build_macos.sh
├── build_release.sh
└── build_web.sh
```

## การตั้งค่า API เพิ่มเติม

ตั้งค่าได้จากหน้า `ตั้งค่า` ภายในแอป:

- `Finnhub API Key` สำหรับดึงราคาหุ้น
- `LLM API Key` สำหรับฟีเจอร์วิเคราะห์พอร์ต
- `จัดการข้อมูล` สำหรับ Supabase config, import และ export CSV

## แนวทางการพัฒนา

- ทุก screen/widget ใหม่ต้องรองรับทั้ง Light Mode และ Dark Mode
- ใช้สีจาก `lib/theme/app_colors.dart`
- ดึงสถานะ dark mode จาก `SettingsProvider`
- ส่ง `isDarkMode` ผ่าน constructor ไปยัง private child widgets
- รัน `flutter analyze` และ `flutter test` ก่อนส่งงานเมื่อมีการแก้ logic

รายละเอียดมาตรฐานสำหรับ agent/developer ดูได้ที่ [AGENTS.md](AGENTS.md)

## เอกสารที่เกี่ยวข้อง

- [SUPABASE_SETUP.md](SUPABASE_SETUP.md) - วิธีตั้งค่า Supabase
- [IOS_IPA_ALTSTORE.md](IOS_IPA_ALTSTORE.md) - วิธี build IPA สำหรับ AltStore
- [MIGRATION_SUMMARY.md](MIGRATION_SUMMARY.md) - บันทึก migration

## Version

เวอร์ชันปัจจุบันกำหนดใน `pubspec.yaml`

```yaml
version: 1.0.1+1
```
