#!/bin/bash
# Clean build script for iOS to clear splash screen cache

echo "🧹 Cleaning Flutter build..."
flutter clean

echo "📦 Getting dependencies..."
flutter pub get

echo "🍎 Cleaning iOS build..."
cd ios
rm -rf build
rm -rf Pods
rm -rf Podfile.lock
rm -rf ~/Library/Developer/Xcode/DerivedData/*

echo "📱 Installing iOS pods..."
pod install --repo-update

cd ..

echo "✅ Clean complete!"
echo ""
echo "👉 ขั้นตอนต่อไป:"
echo "1. ลบแอปเก่าออกจาก iPhone Simulator หรือ Device"
echo "2. Reset Simulator: Device > Erase All Content and Settings"
echo "3. รันแอปใหม่: flutter run"
