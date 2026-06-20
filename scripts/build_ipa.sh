#!/bin/bash
# Build script for iPA

set -e

source "$(dirname "$0")/flutter_env.sh"
resolve_flutter_env "${1:-prod}"

echo "📦 Building for IPA..."

flutter build ipa --release --no-tree-shake-icons "${FLUTTER_ENV_ARGS[@]}" --export-options-plist=ios/ExportOptions-development.plist

destination_dir="/Users/sumetph/Documents/Money Vibe/ipa"
random_suffix=$RANDOM
destination_file="${destination_dir}/Money Vibe-${random_suffix}.ipa"

find "$destination_dir" -maxdepth 1 -type f -name "*.ipa" -delete
cp "./build/ios/ipa/Money Vibe.ipa" "$destination_file"

flutter clean
flutter pub get

echo "✅ IPA built!"
