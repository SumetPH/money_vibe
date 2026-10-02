#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_FILE="$PROJECT_ROOT/ios/Runner.xcodeproj"
PROFILE_DIR="${HOME:-}/Library/Developer/Xcode/UserData/Provisioning Profiles"
PROFILE_PLIST=""
XCODE_CONFIGURATION="Release"
APP_BUNDLE="$PROJECT_ROOT/build/ios/iphoneos/Runner.app"

log() {
  printf '[install-ios] %s\n' "$*"
}

error() {
  printf '[install-ios] ERROR: %s\n' "$*" >&2
}

die() {
  error "$*"
  exit 1
}

on_error() {
  local status=$?
  error "คำสั่งล้มเหลวที่บรรทัด ${BASH_LINENO[0]} (exit ${status})"
  exit "$status"
}

cleanup() {
  if [[ -n "$PROFILE_PLIST" ]]; then
    rm -f "$PROFILE_PLIST" || true
  fi
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "ไม่พบคำสั่ง '$1'"
}

setting_value() {
  local key="$1"

  printf '%s\n' "$BUILD_SETTINGS" | awk -v key="$key" '
    $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
      value = $0
      sub("^[[:space:]]*" key "[[:space:]]*=[[:space:]]*", "", value)
      print value
      exit
    }
  '
}

wireless_ios_device_ids() {
  awk '
    /^[[:space:]]*\{/ {
      depth++
      if (depth == 1) {
        id = ""
        platform = ""
        emulator = ""
      }
    }
    /"id"[[:space:]]*:/ {
      value = $0
      sub(/^[^:]*:[[:space:]]*"/, "", value)
      sub(/".*$/, "", value)
      id = value
    }
    /"targetPlatform"[[:space:]]*:/ {
      value = $0
      sub(/^[^:]*:[[:space:]]*"/, "", value)
      sub(/".*$/, "", value)
      platform = value
    }
    /"emulator"[[:space:]]*:/ {
      value = $0
      sub(/^[^:]*:[[:space:]]*/, "", value)
      sub(/,.*/, "", value)
      gsub(/[[:space:]]/, "", value)
      emulator = value
    }
    /^[[:space:]]*}[[:space:]]*,?[[:space:]]*$/ {
      if (depth == 1) {
        if (platform == "ios" && emulator == "false" && id != "") {
          print id
        }
      }
      depth--
    }
  '
}

main() {
  if (( $# > 1 )); then
    die "ใช้งาน: ./install_ios.sh [wireless-iPhone-device-id]"
  fi

  [[ "$(uname -s)" == "Darwin" ]] || die "สคริปต์นี้รองรับเฉพาะ macOS"
  [[ -n "${HOME:-}" ]] || die "ไม่พบ HOME ของผู้ใช้"
  [[ -d "$PROJECT_FILE" ]] || die "ไม่พบ Xcode project: $PROJECT_FILE"

  require_command awk
  require_command flutter
  require_command mktemp
  require_command plutil
  require_command security
  require_command xcodebuild
  require_command xcrun

  cd "$PROJECT_ROOT"
  source "$SCRIPT_DIR/flutter_env.sh"
  resolve_flutter_env prod
  resolve_flutter_build_version

  log "กำลังอ่าน Bundle ID และ Team ID จาก Xcode..."
  BUILD_SETTINGS="$(xcodebuild \
    -project "$PROJECT_FILE" \
    -target Runner \
    -configuration "$XCODE_CONFIGURATION" \
    -showBuildSettings)"

  BUNDLE_ID="$(setting_value PRODUCT_BUNDLE_IDENTIFIER)"
  TEAM_ID="$(setting_value DEVELOPMENT_TEAM)"
  [[ "$BUNDLE_ID" =~ ^[A-Za-z0-9.-]+$ ]] || die "อ่าน Bundle ID จาก Xcode ไม่สำเร็จ"
  [[ "$TEAM_ID" =~ ^[A-Za-z0-9]+$ ]] || die "อ่าน Development Team ID จาก Xcode ไม่สำเร็จ"
  EXPECTED_APPLICATION_ID="${TEAM_ID}.${BUNDLE_ID}"

  log "Bundle ID: $BUNDLE_ID"
  log "Team ID: $TEAM_ID"

  log "กำลังค้นหา physical iPhone ที่เชื่อมต่อผ่าน Wi-Fi..."
  DEVICE_JSON="$(flutter devices --device-connection wireless --machine)"
  WIRELESS_DEVICE_LIST="$(printf '%s\n' "$DEVICE_JSON" | wireless_ios_device_ids)"
  WIRELESS_DEVICE_IDS=()
  while IFS= read -r device_id; do
    [[ -n "$device_id" ]] && WIRELESS_DEVICE_IDS+=("$device_id")
  done <<< "$WIRELESS_DEVICE_LIST"

  REQUESTED_DEVICE_ID="${1:-${IOS_DEVICE_ID:-}}"
  DEVICE_ID=""
  if [[ -n "$REQUESTED_DEVICE_ID" ]]; then
    for device_id in "${WIRELESS_DEVICE_IDS[@]}"; do
      if [[ "$device_id" == "$REQUESTED_DEVICE_ID" ]]; then
        DEVICE_ID="$device_id"
        break
      fi
    done
    [[ -n "$DEVICE_ID" ]] || die "ไม่พบ wireless physical iPhone ตาม device ID: $REQUESTED_DEVICE_ID"
  elif (( ${#WIRELESS_DEVICE_IDS[@]} == 1 )); then
    DEVICE_ID="${WIRELESS_DEVICE_IDS[0]}"
  elif (( ${#WIRELESS_DEVICE_IDS[@]} == 0 )); then
    die "ไม่พบ wireless physical iPhone; ให้ pair/เปิด Developer Mode ใน Xcode แล้วลองใหม่"
  else
    error "พบ wireless physical iPhone มากกว่าหนึ่งเครื่อง:"
    printf '  %s\n' "${WIRELESS_DEVICE_IDS[@]}" >&2
    die "เรียกใหม่ด้วย ./install_ios.sh <device-id> หรือ IOS_DEVICE_ID=<device-id>"
  fi

  log "เลือก device: $DEVICE_ID"
  log "กำลังตรวจ cached provisioning profiles..."
  MATCHING_PROFILES=()
  if [[ -d "$PROFILE_DIR" ]]; then
    shopt -s nullglob
    PROFILES=("$PROFILE_DIR"/*.mobileprovision)
    shopt -u nullglob

    if (( ${#PROFILES[@]} > 0 )); then
      PROFILE_PLIST="$(mktemp -t install-ios-profile)"
      for profile in "${PROFILES[@]}"; do
        if ! security cms -D -i "$profile" -o "$PROFILE_PLIST"; then
          die "อ่าน provisioning profile ไม่ได้: $profile"
        fi
        if ! profile_application_id="$(plutil -extract Entitlements.application-identifier raw -o - "$PROFILE_PLIST" 2>/dev/null)"; then
          die "อ่าน application-identifier จาก provisioning profile ไม่ได้: $profile"
        fi
        if [[ "$profile_application_id" == "$EXPECTED_APPLICATION_ID" ]]; then
          MATCHING_PROFILES+=("$profile")
        fi
      done
    fi
  fi

  if (( ${#MATCHING_PROFILES[@]} == 0 )); then
    log "ไม่พบ cached profile ที่ตรงกับ $EXPECTED_APPLICATION_ID"
  else
    log "ลบ cached profile ของแอปนี้ ${#MATCHING_PROFILES[@]} ไฟล์ เพื่อให้ Xcode ขอ profile ใหม่..."
    for profile in "${MATCHING_PROFILES[@]}"; do
      log "ลบ: ${profile##*/}"
      rm -f "$profile"
    done
  fi

  # flutter run ไม่รองรับ --build-name/--build-number จึง build ก่อนแล้วค่อย install
  log "กำลัง build Flutter prod release (${FLUTTER_BUILD_NAME}+${FLUTTER_BUILD_NUMBER})..."
  flutter build ios --release "${FLUTTER_BUILD_VERSION_ARGS[@]}" "${FLUTTER_ENV_ARGS[@]}"

  # ใช้ devicectl ติดตั้งทับแอปเดิม (flutter install จะ uninstall ก่อนทำให้ข้อมูลในเครื่องหาย)
  [[ -d "$APP_BUNDLE" ]] || die "ไม่พบ app bundle: $APP_BUNDLE"
  log "กำลังติดตั้งทับบน $DEVICE_ID..."
  xcrun devicectl device install app --device "$DEVICE_ID" "$APP_BUNDLE"

  log "กำลังเปิดแอป $BUNDLE_ID..."
  xcrun devicectl device process launch --device "$DEVICE_ID" "$BUNDLE_ID"
  log "ติดตั้งและรันสำเร็จ"
}

trap on_error ERR
trap cleanup EXIT

main "$@"
