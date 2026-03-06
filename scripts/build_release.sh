#!/bin/bash
# Build script for macOS

echo "📦 Building for macOS..."
flutter build macos --no-tree-shake-icons
echo "✅ Build complete!"

echo "🍎 Copying to Application folder..."
ditto ./build/macos/Build/Products/Release/Money\ Vibe.app /Applications/Money\ Vibe.app
echo "✅ Copy to Application folder complete!"

echo "📦 Building for iOS..."
flutter run --release -d 00008130-000A503A012B803A
echo "✅ Build complete!"

flutter clean && flutter pub get