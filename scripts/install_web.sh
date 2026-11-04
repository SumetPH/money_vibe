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

# path ของ repo ปลายทางต่างกันระหว่าง mac/windows จึง override ได้ด้วย WEB_BUILD_REPO
WEB_BUILD_REPO="${WEB_BUILD_REPO:-$HOME/Development/repositories/money-vibe-build/web}"

if ! git -C "$WEB_BUILD_REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "❌ Web build repo not found: $WEB_BUILD_REPO" >&2
  echo "   Set WEB_BUILD_REPO to the money-vibe-build/web path on this machine." >&2
  exit 1
fi

# pull ก่อน build เพราะสลับเครื่อง deploy กัน ป้องกัน push ชน
echo "⬇️  Pulling latest web build repo..."
git -C "$WEB_BUILD_REPO" pull --rebase origin main

# web release
echo "📦 Building for Web..."
flutter build web --release --no-tree-shake-icons "${FLUTTER_BUILD_VERSION_ARGS[@]}" "${FLUTTER_ENV_ARGS[@]}"

echo "👀 Copying web build to github folder..."
cp -R ./build/web/* "$WEB_BUILD_REPO/"

echo "🐰 Git commit and push to github..."
cd "$WEB_BUILD_REPO"
git add .
if git diff --cached --quiet; then
  echo "ℹ️  No changes to deploy."
else
  git commit -m "deploy web build"
  git push origin main
fi

cd "$PROJECT_ROOT"
flutter clean
flutter pub get

echo "✅ Build complete!"
