#!/bin/bash
# Build script for macOS

echo "📦 Building for macOS..."
flutter build macos --no-tree-shake-icons

echo "🍎 Copying to Application folder..."
ditto ./build/macos/Build/Products/Release/Money\ Vibe.app /Applications/Money\ Vibe.app

echo "✅ Build complete!"