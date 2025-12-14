#!/bin/bash

# Mist App Signing and Notarization Script
# This script signs the app with Developer ID and submits it for notarization

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Mist App Signing and Notarization ===${NC}\n"

# Configuration
APP_NAME="Mist"
BUILD_DIR="build/Build/Products/Release"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"
DMG_NAME="${APP_NAME}.dmg"
DMG_PATH="${BUILD_DIR}/${DMG_NAME}"
ZIP_NAME="${APP_NAME}.zip"
ZIP_PATH="${BUILD_DIR}/${ZIP_NAME}"

# Configuration
DEVELOPER_ID_APPLICATION="Developer ID Application: OwO Network, LLC (ZDY6H3JN3N)"
TEAM_ID="ZDY6H3JN3N"

# These should be set as environment variables
# export APPLE_ID="your-apple-id@example.com"
# export APP_PASSWORD="your-app-specific-password"

if [[ -z "$APPLE_ID" ]] || [[ -z "$APP_PASSWORD" ]]; then
    echo -e "${RED}Error: Missing required environment variables${NC}"
    echo "Please set the following environment variables:"
    echo "  export APPLE_ID=\"your-apple-id@example.com\""
    echo "  export APP_PASSWORD=\"your-app-specific-password\""
    echo ""
    echo "You can get an app-specific password from https://appleid.apple.com"
    exit 1
fi

# Step 1: Build the app in Release mode
echo -e "${YELLOW}Step 1: Building app in Release mode...${NC}"
xcodebuild clean build \
    -project Mist.xcodeproj \
    -scheme Mist \
    -configuration Release \
    -derivedDataPath build \
    CODE_SIGN_STYLE=Automatic \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    -allowProvisioningUpdates

if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}Error: App not found at $APP_PATH${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Build complete${NC}\n"

# Step 2: Sign the app with Developer ID
echo -e "${YELLOW}Step 2: Signing app with Developer ID...${NC}"

# Sign the app extension first
codesign --force --options runtime \
    --sign "$DEVELOPER_ID_APPLICATION" \
    --timestamp \
    --deep \
    "${APP_PATH}/Contents/PlugIns/MistShareExtension.appex"

# Then sign the main app
codesign --force --options runtime \
    --sign "$DEVELOPER_ID_APPLICATION" \
    --timestamp \
    --deep \
    "$APP_PATH"

# Verify signature
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo -e "${GREEN}✓ Signing complete${NC}\n"

# Step 3: Create ZIP for notarization
echo -e "${YELLOW}Step 3: Creating ZIP archive...${NC}"
cd "$BUILD_DIR"
ditto -c -k --keepParent "${APP_NAME}.app" "$ZIP_NAME"
cd - > /dev/null

echo -e "${GREEN}✓ ZIP created: $ZIP_PATH${NC}\n"

# Step 4: Submit for notarization
echo -e "${YELLOW}Step 4: Submitting to Apple for notarization...${NC}"
echo "This may take several minutes..."

xcrun notarytool submit "$ZIP_PATH" \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID" \
    --password "$APP_PASSWORD" \
    --wait

echo -e "${GREEN}✓ Notarization complete${NC}\n"

# Step 5: Staple the notarization ticket
echo -e "${YELLOW}Step 5: Stapling notarization ticket...${NC}"
xcrun stapler staple "$APP_PATH"

echo -e "${GREEN}✓ Stapling complete${NC}\n"

# Step 6: Create DMG
echo -e "${YELLOW}Step 6: Creating DMG for distribution...${NC}"

# Remove old DMG if exists
rm -f "$DMG_PATH"

# Create DMG
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$APP_PATH" \
    -ov -format UDZO \
    "$DMG_PATH"

# Sign the DMG
codesign --sign "$DEVELOPER_ID_APPLICATION" \
    --timestamp \
    "$DMG_PATH"

# Notarize the DMG
echo -e "${YELLOW}Notarizing DMG...${NC}"
xcrun notarytool submit "$DMG_PATH" \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID" \
    --password "$APP_PASSWORD" \
    --wait

# Staple the DMG
xcrun stapler staple "$DMG_PATH"

echo -e "${GREEN}✓ DMG created and notarized: $DMG_PATH${NC}\n"

# Step 7: Verify everything
echo -e "${YELLOW}Step 7: Final verification...${NC}"
spctl --assess --type execute --verbose=4 "$APP_PATH"
spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG_PATH"

echo -e "\n${GREEN}=== Success! ===${NC}"
echo -e "Your signed and notarized app is ready:"
echo -e "  App: ${GREEN}$APP_PATH${NC}"
echo -e "  DMG: ${GREEN}$DMG_PATH${NC}"
echo -e "\nYou can now distribute this DMG to users."
echo -e "Users can download and run it without seeing Gatekeeper warnings.\n"
