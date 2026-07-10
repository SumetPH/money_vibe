#!/bin/bash
# Build script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

source "$SCRIPT_DIR/flutter_env.sh"
resolve_flutter_env "${1:-prod}"
resolve_flutter_build_version

BUILD_MARKER=$(date +%s)

# web release
echo "📦 Building for Web..."
flutter build web --release --no-tree-shake-icons "${FLUTTER_BUILD_VERSION_ARGS[@]}" "${FLUTTER_ENV_ARGS[@]}"

echo "👀 Copying web build to github folder..."
cp -R ./build/web/* /Users/sumetph/Development/money/money-vibe-build/web/

echo "🐰 Git commit and push to github..."
cd /Users/sumetph/Development/money/money-vibe-build/web/
git add .
git commit -m "deploy web build"
git push origin main

cd "$PROJECT_ROOT"
flutter clean
flutter pub get

echo "✅ Build complete!"
