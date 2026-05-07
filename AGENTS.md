# AGENTS.md - คู่มือสำหรับ AI Agent

## การพัฒนา Flutter App - Money

---

## 🎨 Theme & Dark Mode Guidelines

ทุก Screen และ Widget ที่สร้างใหม่ **ต้อง** รองรับทั้ง Light Mode และ Dark Mode

### 1. การเข้าถึง Dark Mode State

```dart
// ใน State ของ Screen หลัก
@override
Widget build(BuildContext context) {
  final isDarkMode = context.watch<SettingsProvider>().isDarkMode;
  // ...
}

// หรือใช้ Consumer
return Consumer<SettingsProvider>(
  builder: (context, settingsProvider, _) {
    final isDarkMode = settingsProvider.isDarkMode;
    // ...
  },
);
```

### 2. การใช้ AppColors กับ Dark Mode

```dart
// ❌ ไม่ควร: ใช้สีคงที่ (Light Mode only)
Container(color: AppColors.surface)
TextStyle(color: AppColors.textPrimary)

// ✅ ควร: ใช้เงื่อนไขตรวจสอบ Dark Mode
Container(
  color: isDarkMode ? AppColors.darkSurface : AppColors.surface
)
TextStyle(
  color: isDarkMode ? AppColors.darkTextPrimary : AppColors.textPrimary
)
```

### 3. สีที่มีให้ใช้ใน AppColors

| Light Mode | Dark Mode | ใช้สำหรับ |
|------------|-----------|-----------|
| `AppColors.background` | `AppColors.darkBackground` | พื้นหลัง Scaffold |
| `AppColors.surface` | `AppColors.darkSurface` | พื้นหลัง Card/Container |
| `AppColors.textPrimary` | `AppColors.darkTextPrimary` | ข้อความหลัก |
| `AppColors.textSecondary` | `AppColors.darkTextSecondary` | ข้อความรอง |
| `AppColors.divider` | `AppColors.darkDivider` | เส้นแบ่ง |
| `AppColors.header` | `AppColors.darkHeader` | สีหัวข้อ/Primary |
| `AppColors.income` | `AppColors.darkIncome` | สีรายรับ (เขียว) |
| `AppColors.expense` | `AppColors.darkExpense` | สีรายจ่าย (แดง) |
| `AppColors.transfer` | `AppColors.darkTransfer` | สีโอนเงิน (น้ำเงิน) |
| `AppColors.fabYellow` | `AppColors.darkFabYellow` | สี FAB |

### 4. การใช้ amountColor กับ Dark Mode

```dart
// ❌ ไม่ควร: ใช้ amountColor โดยไม่ระบุ isDarkMode
TextStyle(color: AppColors.amountColor(amount))

// ✅ ควร: ใช้ getAmountColor พร้อมระบุ isDarkMode
TextStyle(color: AppColors.getAmountColor(amount, isDarkMode))
```

### 5. Pattern สำหรับ Custom Widget

```dart
class _MyWidget extends StatelessWidget {
  final String title;
  final bool isDarkMode; // ต้องรับ isDarkMode
  
  const _MyWidget({
    required this.title,
    required this.isDarkMode, // required
  });
  
  @override
  Widget build(BuildContext context) {
    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final textColor = isDarkMode ? AppColors.darkTextPrimary : AppColors.textPrimary;
    
    return Container(
      color: surfaceColor,
      child: Text(title, style: TextStyle(color: textColor)),
    );
  }
}
```

### 6. Dialogs และ Bottom Sheets

```dart
void _showMyDialog(BuildContext context) {
  final isDarkMode = context.read<SettingsProvider>().isDarkMode;
  final dialogBgColor = isDarkMode ? AppColors.darkSurface : Colors.white;
  final textColor = isDarkMode ? AppColors.darkTextPrimary : AppColors.textPrimary;
  
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: dialogBgColor,
      title: Text('Title', style: TextStyle(color: textColor)),
      content: Text('Content', style: TextStyle(color: textColor)),
    ),
  );
}

void _showBottomSheet(BuildContext context) {
  final isDarkMode = context.read<SettingsProvider>().isDarkMode;
  final bgColor = isDarkMode ? AppColors.darkSurface : Colors.white;
  
  showModalBottomSheet(
    context: context,
    backgroundColor: bgColor,
    // ...
  );
}
```

### 7. Input Fields (TextField)

```dart
TextField(
  decoration: InputDecoration(
    hintText: 'Hint',
    hintStyle: TextStyle(
      color: isDarkMode ? AppColors.darkTextSecondary : AppColors.textSecondary
    ),
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
  ),
  style: TextStyle(
    color: isDarkMode ? AppColors.darkTextPrimary : AppColors.textPrimary
  ),
)
```

### 8. Checklist ก่อน Commit

- [ ] Screen หลักดึง `isDarkMode` จาก `SettingsProvider`
- [ ] ส่ง `isDarkMode` ไปยังทุก child widgets ที่จำเป็น
- [ ] ไม่มีการใช้ `AppColors` ค่าคงที่โดยตรง (ยกเว้นกรณีพิเศษ)
- [ ] Dialogs และ Bottom Sheets ใช้สีตามธีม
- [ ] TextField ใช้สีตามธีมและไม่มี outline
- [ ] ทดสอบทั้ง Light Mode และ Dark Mode

---

## 📁 Project Structure

```
lib/
├── main.dart                    # Entry point, AppTheme
├── theme/
│   ├── app_colors.dart          # สีทั้งหมด (Light + Dark)
│   └── app_theme.dart           # ThemeData สำหรับ Light/Dark
├── providers/
│   ├── settings_provider.dart   # เก็บสถานะ Dark Mode
│   └── ...
├── screens/
│   ├── account/
│   ├── category/
│   ├── transaction/
│   └── settings/
└── widgets/
```

---

## 🔧 Common Commands

```bash
# Build APK
flutter build apk --debug

# Analyze
flutter analyze

# Run
flutter run
```

---

## 📝 Coding Standards

### Imports
```dart
// เรียงตามลำดับ: Flutter -> Third-party -> Local
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
```

### Widget Structure
- ใช้ `const` constructor เมื่อเป็นไปได้
- แยก widget ย่อยเป็น private class (`_WidgetName`)
- ส่ง `isDarkMode` ผ่าน constructor ไม่ใช่ดึงซ้ำใน widget ย่อย

---

## 🐛 ปัญหาที่พบบ่อย

### 1. Text หายใน Dark Mode
**สาเหตุ:** ใช้ `const TextStyle(color: AppColors.textPrimary)` โดยไม่เปลี่ยนสี

**แก้ไข:**
```dart
Text(
  'ข้อความ',
  style: TextStyle(
    color: isDarkMode ? AppColors.darkTextPrimary : AppColors.textPrimary
  )
)
```

### 2. Background เป็นสีขาวตลอด
**สาเหตุ:** ใช้ `Colors.white` โดยตรง

**แก้ไข:**
```dart
Container(
  color: isDarkMode ? AppColors.darkSurface : Colors.white
)
```

### 3. Bottom Sheet ไม่เปลี่ยนสีตามธีม
**สาเหตุ:** ไม่ระบุ `backgroundColor` ใน `showModalBottomSheet`

**แก้ไข:**
```dart
showModalBottomSheet(
  context: context,
  backgroundColor: isDarkMode ? AppColors.darkSurface : Colors.white,
  // ...
)
```

---

---

## 🗄️ Supabase Database & Migrations Workflow

เพื่อให้การแก้ไข Database Schema สามารถทำงานร่วมกับการ Deploy หรือการเปลี่ยนโปรเจกต์ใหม่ได้ง่าย **ห้ามสร้างไฟล์ `.sql` แยกเด็ดขาด** ให้ทำตาม Workflow ของ Migration ดังนี้:

### 1. การสร้าง Migration ใหม่
เมื่อต้องการแก้ไขตาราง, เพิ่มคอลัมน์, หรือสร้าง Storage ให้สร้างไฟล์ Migration เสมอ:
```bash
npx supabase migration new <ชื่อ_migration>
# ตัวอย่าง: npx supabase migration new add_user_profile
```
คำสั่งนี้จะสร้างไฟล์ในโฟลเดอร์ `supabase/migrations/` (เช่น `20260507123456_add_user_profile.sql`)

### 2. การเขียนโค้ด SQL
นำคำสั่ง SQL ที่ต้องการ (เช่น `ALTER TABLE`, `CREATE POLICY`) ไปใส่ในไฟล์ Migration ที่เพิ่งสร้างขึ้น

### 3. การอัปเดต Database โลคอล (ถ้าจำลอง Local Supabase)
```bash
npx supabase start
npx supabase db reset  # รีเซ็ตและรัน migration ทั้งหมดใหม่
```

### 4. การ Deploy ขึ้นโปรเจกต์จริง (Production / New Project)
เมื่อต้องการอัปเดต Database ของจริง หรือเมื่อย้ายโปรเจกต์:
```bash
npx supabase link --project-ref <project-id>
npx supabase db push
```
คำสั่ง `db push` จะรันไฟล์ Migration เฉพาะที่ยังไม่ได้รัน ตามลำดับเวลาให้โดยอัตโนมัติ

### 5. การ Deploy Edge Functions
Edge Functions จะแยกส่วนกับ Database (ไม่ไปพร้อมกับ `db push`) หากมีการแก้ไขหรือย้ายโปรเจกต์ ต้องทำการ Deploy ใหม่เสมอ:
```bash
# Deploy ฟังก์ชันทั้งหมด
npx supabase functions deploy

# หรือ Deploy แค่ฟังก์ชันเดียว (ตัวอย่าง)
npx supabase functions deploy mirror-stock-logo
```
*(ข้อควรระวัง: หาก Edge Function มีการเรียกใช้ Environment Variables (เช่น API Key) อย่าลืมไปตั้งค่า Secrets ใน Dashboard ของโปรเจกต์ใหม่ด้วยคำสั่ง `npx supabase secrets set KEY=VALUE`)*

---

*Last updated: 2026-05-07*
