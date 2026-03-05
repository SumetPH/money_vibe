#!/bin/bash
# Build script for iOS

echo "📦 Building for iOS..."
flutter run --release -d 00008130-000A503A012B803A && flutter clean && flutter pub get

echo "✅ Build complete!"