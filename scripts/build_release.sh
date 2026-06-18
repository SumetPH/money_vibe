#!/bin/bash
# Build script for iPA

echo "📦 Building for IPA..."

flutter build ipa --release --no-tree-shake-icons --export-options-plist=ios/ExportOptions-development.plist

destination_dir="/Users/sumetph/Documents/Money Vibe/ipa"
random_suffix=$RANDOM
destination_file="${destination_dir}/Money Vibe-${random_suffix}.ipa"

find "$destination_dir" -maxdepth 1 -type f -name "*.ipa" -delete
cp "./build/ios/ipa/Money Vibe.ipa" "$destination_file"

flutter clean
flutter pub get

echo "✅ IPA built!"

# ---------------------------------------------------------------------

set -e

BUILD_MARKER=$(date +%s)

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

cd /Users/sumetph/Development/money/money_vibe
flutter clean
flutter pub get

echo "✅ Build complete!"
