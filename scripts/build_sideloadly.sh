#!/bin/bash
# Build IPA แบบไม่ sign สำหรับติดตั้งผ่าน Sideloadly (Sideloadly จะ re-sign ด้วย Apple ID ตอนติดตั้ง)

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_BUNDLE="$PROJECT_ROOT/build/ios/iphoneos/Runner.app"
OUTPUT_DIR="$PROJECT_ROOT/build/sideloadly"

log() {
  printf '[sideloadly] %s\n' "$*"
}

die() {
  printf '[sideloadly] ERROR: %s\n' "$*" >&2
  exit 1
}

trap 'die "คำสั่งล้มเหลวที่บรรทัด $LINENO"' ERR

[[ "$(uname -s)" == "Darwin" ]] || die "สคริปต์นี้รองรับเฉพาะ macOS"
command -v flutter >/dev/null 2>&1 || die "ไม่พบคำสั่ง 'flutter'"
command -v zip >/dev/null 2>&1 || die "ไม่พบคำสั่ง 'zip'"

cd "$PROJECT_ROOT"
source "$SCRIPT_DIR/flutter_env.sh"
resolve_flutter_env "${1:-prod}"
resolve_flutter_build_version

log "กำลัง build iOS release แบบไม่ sign (${FLUTTER_BUILD_NAME}+${FLUTTER_BUILD_NUMBER})..."
flutter build ios --release --no-codesign --no-tree-shake-icons \
  "${FLUTTER_BUILD_VERSION_ARGS[@]}" "${FLUTTER_ENV_ARGS[@]}" "${FLUTTER_FLAVOR_ARGS[@]}"

[[ -d "$APP_BUNDLE" ]] || die "ไม่พบ app bundle: $APP_BUNDLE"

log "กำลังแพ็ก Payload/Runner.app เป็น .ipa..."
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/Payload"
cp -R "$APP_BUNDLE" "$OUTPUT_DIR/Payload/"

ipa_name="Money Vibe-${FLUTTER_ENV_NAME}-${FLUTTER_BUILD_NAME}+${FLUTTER_BUILD_NUMBER}.ipa"
(cd "$OUTPUT_DIR" && zip -qry "$ipa_name" Payload)
rm -rf "$OUTPUT_DIR/Payload"

log "✅ เสร็จแล้ว: $OUTPUT_DIR/$ipa_name"
log "เปิด Sideloadly แล้วลากไฟล์นี้เข้าไปเพื่อติดตั้ง"
