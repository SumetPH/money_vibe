# Build iOS IPA for AltStore

เอกสารนี้สำหรับ build ไฟล์ `.ipa` ของ Money Vibe เพื่อนำไปติดตั้งผ่าน AltStore

## คำสั่งหลัก

รันจาก root project:

```bash
flutter build ipa --release --no-tree-shake-icons --export-options-plist=ios/ExportOptions-development.plist
```

```bash
flutter clean && flutter pub get
```

เมื่อ build สำเร็จ ไฟล์ IPA จะอยู่ที่:

```text
build/ios/ipa/Money Vibe.ipa
```

## กำหนด Version

กำหนดเลข version ตอน build ได้ด้วย `--build-name` และ `--build-number`:

```bash
flutter build ipa --release \
  --no-tree-shake-icons \
  --export-options-plist=ios/ExportOptions-development.plist \
  --build-name=1.0.1 \
  --build-number=2
```

ความหมายบน iOS:

- `--build-name=1.0.1` คือ Version Number หรือ `CFBundleShortVersionString`
- `--build-number=2` คือ Build Number หรือ `CFBundleVersion`

ถ้าต้องการเปลี่ยนค่า default ให้แก้ใน `pubspec.yaml`:

```yaml
version: 1.0.1+2
```

โดยตัวหน้า `+` คือ Version Number และตัวหลัง `+` คือ Build Number

## ใช้กับ AltStore

นำไฟล์นี้ไปใช้ใน AltStore:

```text
build/ios/ipa/Money Vibe.ipa
```

ไฟล์นี้เป็น IPA แบบ `debugging`/development export ไม่ใช่ App Store IPA จึงเหมาะกับการ sideload ผ่าน AltStore

## ถ้ามี archive อยู่แล้ว

ถ้ามี archive ที่สร้างไว้แล้วที่:

```text
build/ios/archive/Runner.xcarchive
```

สามารถ export เป็น IPA โดยไม่ต้อง archive ใหม่ได้ด้วยคำสั่ง:

```bash
xcodebuild -exportArchive \
  -archivePath build/ios/archive/Runner.xcarchive \
  -exportPath build/ios/ipa-development \
  -exportOptionsPlist ios/ExportOptions-development.plist \
  -allowProvisioningUpdates
```

ไฟล์ที่ได้จะอยู่ที่:

```text
build/ios/ipa-development/Money Vibe.ipa
```

## หมายเหตุ

- ต้องเปิดโปรเจกต์ iOS ด้วย `ios/Runner.xcworkspace` เสมอ ไม่ใช่ `ios/Runner.xcodeproj`
- ต้องมี signing/provisioning สำหรับ development ใน Xcode
- คำสั่งนี้ใช้ `--no-tree-shake-icons` เพราะโปรเจกต์มี dynamic `IconData`
- ถ้าใช้ `flutter build ipa --release` แบบไม่ระบุ export options Flutter จะพยายาม export แบบ App Store และอาจเจอ error `No signing certificate "iOS Distribution" found`
