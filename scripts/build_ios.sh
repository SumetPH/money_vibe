#!/bin/bash
# Build script for iOS

set -e

BUILD_MARKER=$(date +%s)

echo "📦 Building for iOS..."
echo "🔢 Using build marker: ${BUILD_MARKER}"

flutter run --release --dart-define=APP_BUILD_MARKER="${BUILD_MARKER}" -d 00008130-000A503A012B803A
flutter clean
flutter pub get

echo "✅ Build complete!"
