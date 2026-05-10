#!/bin/bash
# Build script for iOS

echo "📦 Building for IPA..."

flutter build ipa --release --no-tree-shake-icons --export-options-plist=ios/ExportOptions-development.plist

cp ./build/ios/ipa/Money\ Vibe.ipa /Users/sumetph/Documents/Money\ Vibe/ipa/

echo "✅ IPA built!"
