#!/bin/bash
# Build script for release

# macos release
# echo "📦 Building for macOS..."
# flutter build macos --no-tree-shake-icons

# echo "🍎 Copying to Application folder..."
# ditto ./build/macos/Build/Products/Release/Money\ Vibe.app /Applications/Money\ Vibe.app

# web release
echo "📦 Building for Web..."
flutter build web --release --no-tree-shake-icons

echo "👀 Copying web build to github folder..."
cp -R ./build/web/* /Users/sumetph/Development/money/money-vibe-web/

echo "🐰 Git commit and push to github..."
cd /Users/sumetph/Development/money/money-vibe-web/
git add .
git commit -m "deploy web build"
git push origin main

# ios release
echo "📦 Building for iOS..."
cd /Users/sumetph/Development/money/money_vibe/
flutter run --release -d 00008130-000A503A012B803A
flutter clean && flutter pub get

echo "✅ Build complete!"