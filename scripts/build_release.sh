#!/bin/bash
# Build script for release

set -e

BUILD_MARKER=$(date +%s)

# --------------------------------------------------------------------------

# android release
APK_PATH="./build/app/outputs/flutter-apk/app-release.apk"

echo "📦 Building Android APK (Release)..."

flutter build apk --release --no-tree-shake-icons --dart-define=APP_BUILD_MARKER="${BUILD_MARKER}"

echo "📍 APK Location: ${APK_PATH}"

VERSION="v1.0.$(date +%Y%m%d%H%M)" # สร้างเลขเวอร์ชันจากวันที่และเวลา
RELEASE_NOTES="อัปเดตเมื่อ $(date '+%Y-%m-%d %H:%M:%S')"
REPO="SumetPH/money-vibe-build"

echo "กำลังอัปโหลด APK ไปที่ GitHub Release..."
gh release create $VERSION "$APK_PATH" \
    --title "Release $VERSION" \
    --notes "$RELEASE_NOTES" \
    --repo $REPO

# --------------------------------------------------------------------------

# web release
echo "📦 Building for Web..."
flutter build web --release --no-tree-shake-icons

echo "👀 Copying web build to github folder..."
cp -R ./build/web/* /Users/sumetph/Development/money/money-vibe-build/web/

echo "🐰 Git commit and push to github..."
cd /Users/sumetph/Development/money/money-vibe-build/web/
git add .
git commit -m "deploy web build"
git push origin main

# --------------------------------------------------------------------------

# ios release
read -r -p "🤔 Build iOS? Press Enter to continue or Ctrl+C to cancel..."

echo "📦 Building for iOS..."
echo "🔢 Using build marker: ${BUILD_MARKER}"
cd /Users/sumetph/Development/money/money_vibe/
flutter run --release --dart-define=APP_BUILD_MARKER="${BUILD_MARKER}" -d 00008130-000A503A012B803A
flutter clean
flutter pub get

# --------------------------------------------------------------------------

echo "✅ Build complete!"
