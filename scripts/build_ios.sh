#!/bin/bash
# Build script for iOS

set -e

source "$(dirname "$0")/flutter_env.sh"
resolve_flutter_env "${1:-prod}"

BUILD_MARKER=$(date +%s)

echo "📦 Building for iOS..."
echo "🔢 Using build marker: ${BUILD_MARKER}"

flutter run --release --no-tree-shake-icons "${FLUTTER_ENV_ARGS[@]}" --dart-define=APP_BUILD_MARKER="${BUILD_MARKER}" -d 00008130-000A503A012B803A
flutter clean
flutter pub get

echo "✅ Build complete!"
