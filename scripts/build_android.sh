#!/bin/bash
# Build script for Android APK

# Exit immediately if a command exits with a non-zero status.
set -e

# Generate a build marker based on current timestamp
BUILD_MARKER=$(date +%s)

echo "📦 Building Android APK (Release)..."
echo "🔢 Using build marker: ${BUILD_MARKER}"

# Build the APK
# --split-per-abi: Creates separate APKs for different CPU architectures (smaller file size)
# --obfuscate --split-debug-info: For code protection and smaller APKs (optional)
# --no-tree-shake-icons: Required when using dynamic icons
flutter build apk --release --no-tree-shake-icons --dart-define=APP_BUILD_MARKER="${BUILD_MARKER}"

echo "✅ Build complete!"
echo "📍 APK Location: build/app/outputs/flutter-apk/app-release.apk"
