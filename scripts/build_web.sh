#!/bin/bash
# Build script

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

echo "✅ Build complete!"
