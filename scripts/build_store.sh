#!/bin/bash
# Build script สำหรับส่งขึ้น App Store / Play Store
#
# Usage: scripts/build_store.sh [android|ios|all] [prod|dev]
#
# - ใส่ DISTRIBUTION=store เพื่อซ่อนฟีเจอร์ที่ใช้เฉพาะ build ส่วนตัว/sideload
# - obfuscate และแยก debug symbols ไว้ที่ build/symbols (เก็บไว้ใช้ถอด stack trace)
# - คง --no-tree-shake-icons เพราะไอคอนถูกเก็บเป็น codePoint แล้วสร้าง IconData แบบ dynamic

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

TARGET="${1:-all}"

source "$SCRIPT_DIR/flutter_env.sh"
resolve_flutter_env "${2:-prod}"
resolve_flutter_build_version

STORE_ARGS=(
  --release
  --no-tree-shake-icons
  --obfuscate
  --dart-define=DISTRIBUTION=store
)

build_android() {
  if [ ! -f "android/key.properties" ]; then
    echo "❌ Missing android/key.properties (release signing). See docs/setup/STORE_RELEASE.md" >&2
    exit 1
  fi

  echo "📦 Building Android App Bundle (store)..."
  flutter build appbundle "${STORE_ARGS[@]}" \
    --split-debug-info=build/symbols/android \
    "${FLUTTER_BUILD_VERSION_ARGS[@]}" "${FLUTTER_ENV_ARGS[@]}"
  echo "📍 AAB: build/app/outputs/bundle/release/app-release.aab"
}

build_ios() {
  echo "📦 Building iOS IPA (store)..."
  flutter build ipa "${STORE_ARGS[@]}" \
    --split-debug-info=build/symbols/ios \
    "${FLUTTER_BUILD_VERSION_ARGS[@]}" "${FLUTTER_ENV_ARGS[@]}" \
    --export-options-plist=ios/ExportOptions-appstore.plist
  echo "📍 IPA: build/ios/ipa/"
}

case "$TARGET" in
  android) build_android ;;
  ios) build_ios ;;
  all)
    build_android
    build_ios
    ;;
  *)
    echo "Usage: $0 [android|ios|all] [prod|dev]" >&2
    exit 1
    ;;
esac

echo "✅ Store build complete!"
