#!/bin/bash
# Build script for Android APK

# Exit immediately if a command exits with a non-zero status.
set -e

# Generate a build marker based on current timestamp
BUILD_MARKER=$(date +%s)
APK_PATH="./build/app/outputs/flutter-apk/app-release.apk"

echo "📦 Building Android APK (Release)..."
echo "🔢 Using build marker: ${BUILD_MARKER}"

flutter build apk --release --no-tree-shake-icons --dart-define=APP_BUILD_MARKER="${BUILD_MARKER}"

echo "✅ Build complete!"
echo "📍 APK Location: ${APK_PATH}"

VERSION="v1.0.$(date +%Y%m%d%H%M)" # สร้างเลขเวอร์ชันจากวันที่และเวลา
RELEASE_NOTES="อัปเดตเมื่อ $(date '+%Y-%m-%d %H:%M:%S')"
REPO="SumetPH/money-vibe-build"

echo "กำลังอัปโหลด APK ไปที่ GitHub Release..."
gh release create $VERSION "$APK_PATH" \
    --title "Release $VERSION" \
    --notes "$RELEASE_NOTES" \
    --repo $REPO