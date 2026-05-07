#!/bin/bash
# Build script for iOS

echo "📦 Building for IPA..."

flutter build ipa --release --no-tree-shake-icons --export-options-plist=ios/ExportOptions-development.plist

echo "✅ IPA built!"
