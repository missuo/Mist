#!/bin/bash

# Quick build script for Release version
# Use this for testing before full signing and notarization

set -e

echo "🏗️  Building Mist Release version..."

xcodebuild clean build \
    -project Mist.xcodeproj \
    -scheme Mist \
    -configuration Release \
    -derivedDataPath build

echo "✅ Build complete!"
echo "📦 App location: build/Build/Products/Release/Mist.app"
echo ""
echo "To test locally:"
echo "  open build/Build/Products/Release/Mist.app"
echo ""
echo "To sign and notarize for distribution:"
echo "  ./scripts/sign_and_notarize.sh"
