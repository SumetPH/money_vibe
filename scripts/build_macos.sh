#!/bin/bash
# Build script for macOS

set -e

source "$(dirname "$0")/flutter_env.sh"
resolve_flutter_env "${1:-prod}"

echo "📦 Building for macOS..."
flutter build macos --no-tree-shake-icons "${FLUTTER_ENV_ARGS[@]}"

echo "🍎 Copying to Application folder..."
ditto ./build/macos/Build/Products/Release/Money\ Vibe.app /Applications/Money\ Vibe.app

echo "✅ Build complete!"
