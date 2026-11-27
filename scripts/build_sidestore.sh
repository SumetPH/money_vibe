#!/bin/bash
# Build IPA แบบไม่ sign สำหรับติดตั้งผ่าน SideStore (SideStore จะ re-sign ด้วย Apple ID ตอนติดตั้ง)

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_BUNDLE="$PROJECT_ROOT/build/ios/iphoneos/Runner.app"
OUTPUT_DIR="$HOME/Documents/IPA"
STAGING_DIR=""

log() {
  printf '[sidestore] %s\n' "$*"
}

die() {
  printf '[sidestore] ERROR: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  if [[ -n "$STAGING_DIR" && -d "$STAGING_DIR" ]]; then
    rm -rf "$STAGING_DIR"
  fi
}

trap 'die "คำสั่งล้มเหลวที่บรรทัด $LINENO"' ERR
trap cleanup EXIT

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
STAGING_DIR="$(mktemp -d)"
mkdir -p "$STAGING_DIR/Payload"
cp -R "$APP_BUNDLE" "$STAGING_DIR/Payload/"

ipa_name="Money Vibe-${FLUTTER_ENV_NAME}-${FLUTTER_BUILD_NAME}+${FLUTTER_BUILD_NUMBER}.ipa"
(cd "$STAGING_DIR" && zip -qry "$ipa_name" Payload)
mkdir -p "$OUTPUT_DIR"
mv -f "$STAGING_DIR/$ipa_name" "$OUTPUT_DIR/$ipa_name"

log "✅ เสร็จแล้ว: $OUTPUT_DIR/$ipa_name"
log "นำไฟล์นี้ไปติดตั้งผ่าน SideStore ได้เลย"
