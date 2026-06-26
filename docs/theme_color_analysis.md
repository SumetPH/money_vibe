# Theme Color Analysis

สถานะ: analysis ก่อน implement

## เป้าหมาย

เพิ่ม feature เลือก theme color โดยเน้น dark mode ก่อน และลดจุดที่สีหลักถูก hard-code กระจายอยู่ตาม screen/widget

## ภาพรวมปัจจุบัน

- Theme mode มีเพียง boolean `SettingsProvider.isDarkMode`
- ค่า setting ถูกเก็บใน `SharedPreferences` ด้วย key `dark_mode`
- `MaterialApp.router` เรียก `AppTheme.getTheme(settingsProvider.isDarkMode)`
- สีหลักอยู่ใน `lib/theme/app_colors.dart` เป็น static constants
- หลายหน้าดึง `SettingsProvider.isDarkMode` แล้วเลือกสีเองด้วย ternary เช่น `isDarkMode ? AppColors.darkSurface : AppColors.surface`
- กฎโปรเจกต์กำหนดให้ใช้ token จาก `AppColors` และรองรับ light/dark mode

## จุดที่ต้องแก้หรือระวัง

### 1. AppTheme ยังรับแค่ dark/light

`AppTheme.getTheme(bool isDarkMode)` ทำให้ theme color เปลี่ยนตาม setting เพิ่มเติมไม่ได้โดยตรง ต้องขยาย interface เป็นรับ theme palette หรือ theme option

จุดสำคัญ:

- `ColorScheme.fromSeed(seedColor: AppColors.header)` ใช้ seed เดิมทั้ง light และ dark
- dark theme ยังใช้ `AppColors.header` เป็น seed แม้ app bar ใช้ `AppColors.darkHeader`
- focused border และ switch selected track ยังผูกกับ `AppColors.header`
- dark bottom nav selected item ใช้ `AppColors.darkIncome` ซึ่งเป็น semantic income ไม่ใช่ brand/accent color

### 2. AppColors เป็น static token แบบ fixed

สีหลัก เช่น `header`, `darkHeader`, `fabYellow`, `darkFabYellow`, `darkIncome` เป็นค่าคงที่ ทำให้เลือก theme color แบบ runtime ต้องมีอีกชั้นหนึ่ง เช่น `AppPalette` หรือ `AppThemeColors`

ควรแยกประเภทสี:

- semantic: income, expense, transfer, warning
- surface/text/divider: background, surface, textPrimary
- accent/brand: header, selected, FAB, focused border, active controls
- data/entity colors: account/category colors

อย่าปรับ semantic colors ตาม theme color มากเกินไป เพราะตัวเลขรายรับรายจ่ายต้องสื่อความหมายคงที่

### 3. Hard-code ที่จะชนกับ theme color

จุดที่เกี่ยวกับ accent/brand โดยตรง:

- `lib/theme/app_theme.dart`: header, seed, switch, focused border, FAB, bottom nav selected
- `lib/screens/settings/settings_screen.dart`: `AppBar.backgroundColor: AppColors.header`
- `lib/widgets/app_drawer.dart`: header และ selected item
- `lib/widgets/app_sidebar.dart`: selected item และ selected tile background
- `lib/widgets/bottom_summary_bar.dart`: header/FAB สีหลักของ bottom summary
- `lib/screens/splash/splash_screen.dart`: splash ยังใช้ `AppColors.header`
- auth/settings/data management บางส่วนใช้ `AppColors.header` โดยตรง

จุดที่เป็น status color ควรคงไว้หรือแยกเป็น semantic token:

- logout/delete ใช้ `AppColors.expense` หรือ `Colors.red`
- success/configured ใช้ green
- warning/not configured ใช้ orange
- transfer ใช้ blue

### 4. UI หลายจุด bypass ThemeData

แม้มี `ThemeData` ส่วนกลาง แต่ UI จำนวนมากระบุสีเองจาก `AppColors` ทำให้การเปลี่ยน theme color ผ่าน `ThemeData.colorScheme` อย่างเดียวไม่พอ

แนวทางที่เข้ากับ codebase คือเพิ่ม helper/token layer ที่ screen เรียกได้ง่าย เช่น:

- `AppColors.accent(isDarkMode, palette)`
- `AppColors.headerFor(isDarkMode, palette)`
- หรือ object `AppPalette` ที่ส่งเข้า `AppTheme.getTheme(...)`

ถ้าเปลี่ยนทีเดียวทั้ง codebase จะใหญ่เกินไป ควรเริ่มจาก shell/navigation/settings ก่อน แล้วค่อย migrate จุดอื่น

### 5. Persistence และ debug bootstrap

ต้องเพิ่ม setting ใหม่ใน `SettingsProvider` เช่น key `theme_color`

ควรพิจารณาเพิ่ม debug dart-define ต่อ:

- `DEBUG_THEME_COLOR`

เพื่อให้เปิด web/dev แล้วตรวจ theme ได้เร็วเหมือน `DEBUG_DARK_MODE`

### 6. Settings UI

ปัจจุบัน section `ลักษณะ` มีแค่ switch โหมดมืด เหมาะจะเพิ่ม row "สีธีม" ที่เปิด bottom sheet เลือก swatch

เพื่อเข้ากับ pattern โปรเจกต์:

- ใช้ `showModalBottomSheet`
- แสดงรายการสีเป็น row/list หรือ swatch grid บน surface
- มี selected state ชัดเจน
- ไม่ใช้ dropdown

### 7. Dark mode first scope

ถ้าเน้น dark mode ก่อน ให้ theme color คุมเฉพาะ accent/shell ก่อน:

- app bar/header
- navigation selected state
- switch selected track
- focused input border
- FAB หรือ primary action accent
- splash background

ยังไม่ควรให้ theme color เปลี่ยน:

- income/expense/transfer
- account/category user-chosen colors
- destructive/status colors
- chart semantic colors

## Proposed domain model

`ThemeColorOption`

- `id`: key สำหรับ persistence เช่น `slate`, `teal`, `violet`, `amber`
- `label`: ชื่อภาษาไทยใน settings
- `darkAccent`: สีหลักใน dark mode
- `darkHeader`: สี header ใน dark mode
- `darkFab`: สี FAB/primary action ถ้าต้องการแยกจาก accent
- `lightAccent`: เตรียมไว้ แต่ implement รอบแรกอาจ map เป็นค่าเดิม

`SettingsProvider`

- เพิ่ม getter `themeColor`
- เพิ่ม `setThemeColor(ThemeColorOption option)` หรือ `setThemeColorId(String id)`
- default ควรรักษาหน้าตาเดิม เช่น option `classic`

`AppTheme`

- เปลี่ยน `getTheme(bool isDarkMode)` เป็นรับ option เพิ่ม
- dark theme ใช้ option สำหรับ seed/accent/header/FAB
- light theme ช่วงแรกคง visual เดิมได้ เพื่อไม่ให้ scope บาน

## คำถามก่อน implement

1. ต้องการให้ light mode เปลี่ยนสีตามด้วยทันทีไหม หรือรอบแรกให้ theme color มีผลเฉพาะ dark mode? ตัดสินใจ: ให้ light mode เปลี่ยนตามด้วยเท่าที่ทำได้
2. สี default ควรเป็นหน้าตาปัจจุบัน หรืออยากเปลี่ยน default dark mode ไปทางสีใหม่เลย? ตัดสินใจ: default เป็นหน้าตาปัจจุบัน
3. จำนวนสีในรอบแรกควรเป็น preset เล็ก ๆ 4-6 สี หรือเปิด custom color picker? ตัดสินใจ: ใช้ preset 4 สี
4. FAB สีส้มปัจจุบันควรถือเป็น brand/accent ที่เปลี่ยนได้ หรือเป็น action color คงเดิม? ตัดสินใจ: ให้ FAB เปลี่ยนตาม theme

## Recommendation

เริ่มแบบ preset เท่านั้นและรักษา default เดิม:

- เพิ่ม `ThemeColorOption` 4 ตัว: classic, teal, blue, violet
- ทำให้ dark mode เปลี่ยนเฉพาะ accent/shell
- เพิ่ม settings bottom sheet สำหรับเลือกสี
- migrate เฉพาะไฟล์ shell สำคัญก่อน: `app_theme.dart`, `main.dart`, `settings_provider.dart`, `settings_screen.dart`, `app_drawer.dart`, `app_sidebar.dart`, `bottom_summary_bar.dart`, `splash_screen.dart`
- รอบถัดไปค่อยไล่จุดที่ยังใช้ `AppColors.header` โดยตรง

## Implementation decisions

- ใช้ `ThemeColorOption` เป็น module กลางสำหรับ preset สี
- Preset รอบแรกมี 4 ตัว: classic, teal, blue, violet
- `classic` รักษาค่าสีเดิมของแอป
- ทั้ง light และ dark mode ใช้ preset เดียวกันสำหรับ header/accent/FAB
- semantic colors เช่น income, expense, transfer ยังไม่เปลี่ยนตาม preset
