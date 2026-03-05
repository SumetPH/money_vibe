#!/bin/bash
# สคริปต์ล้าง cache ของ iOS Splash Screen อย่างละเอียด

echo "🧹 Cleaning Flutter..."
flutter clean

echo "📦 Getting dependencies..."
flutter pub get

echo "🍎 Deep cleaning iOS..."
cd ios

# ลบ build ทั้งหมด
rm -rf build
rm -rf Pods
rm -rf Podfile.lock
rm -rf .symlinks

# ลบ DerivedData (cache ของ Xcode)
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# ลบ cache ของ CocoaPods
pod cache clean --all

echo "📱 Reinstalling pods..."
pod install --repo-update

cd ..

echo ""
echo "⚠️  ขั้นตอนสำคัญถัดไป:"
echo ""
echo "1️⃣  ลบแอปเก่าออกจาก iPhone Simulator:"
echo "   กดค้างที่แอป Money > Remove App > Delete App"
echo ""
echo "2️⃣  หรือ Reset Simulator ทั้งหมด:"
echo "   Simulator > Device > Erase All Content and Settings..."
echo ""
echo "3️⃣  รันแอปใหม่:"
echo "   flutter run"
echo ""
echo "✅ Clean complete!"
