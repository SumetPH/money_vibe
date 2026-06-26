#!/bin/bash
# Build script

set -e

source "$(dirname "$0")/flutter_env.sh"
resolve_flutter_env "${1:-prod}"

BUILD_MARKER=$(date +%s)

# web release
echo "📦 Building for Web..."
flutter build web --release --no-tree-shake-icons "${FLUTTER_ENV_ARGS[@]}"

echo "👀 Copying web build to github folder..."
cp -R ./build/web/* /Users/sumetph/Development/money/money-vibe-build/web/

echo "🐰 Git commit and push to github..."
cd /Users/sumetph/Development/money/money-vibe-build/web/
git add .
git commit -m "deploy web build"
git push origin main

cd /Users/sumetph/Development/llm/money_vibe
flutter clean
flutter pub get

echo "✅ Build complete!"
