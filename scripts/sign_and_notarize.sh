#!/bin/bash

# Mist App Signing and Notarization Script
# Builds the app, then signs, notarizes, and packages it (zip + DMG) using the
# same script the release CI uses (.github/scripts/package-app.sh).

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Mist App Signing and Notarization ===${NC}\n"

APP_NAME="Mist"
BUILD_DIR="build/Build/Products/Release"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"

TEAM_ID="NCFNX3LJ83"
export CODESIGN_IDENTITY="Developer ID Application: MOE AI LLC (${TEAM_ID})"
export APPLE_TEAM_ID="$TEAM_ID"
# package-app.sh reads APPLE_APP_PASSWORD; accept the legacy APP_PASSWORD name too.
export APPLE_APP_PASSWORD="${APPLE_APP_PASSWORD:-${APP_PASSWORD:-}}"

if [[ -z "${APPLE_ID:-}" ]] || [[ -z "$APPLE_APP_PASSWORD" ]]; then
    echo -e "${RED}Error: Missing required environment variables${NC}"
    echo "Please set the following environment variables:"
    echo "  export APPLE_ID=\"your-apple-id@example.com\""
    echo "  export APP_PASSWORD=\"your-app-specific-password\""
    echo ""
    echo "You can get an app-specific password from https://appleid.apple.com"
    exit 1
fi

# Step 1: Build the app in Release mode (unsigned; package-app.sh signs it)
echo -e "${YELLOW}Step 1: Building app in Release mode...${NC}"
xcodebuild clean build \
    -project Mist.xcodeproj \
    -scheme Mist \
    -configuration Release \
    -derivedDataPath build \
    CODE_SIGNING_ALLOWED=NO

if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}Error: App not found at $APP_PATH${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Build complete${NC}\n"

# Step 2: Sign, notarize, staple, and package (zip + DMG)
echo -e "${YELLOW}Step 2: Signing, notarizing, and packaging...${NC}"
"$(dirname "$0")/../.github/scripts/package-app.sh" \
    "$APP_PATH" \
    "${BUILD_DIR}/${APP_NAME}.zip" \
    "${BUILD_DIR}/${APP_NAME}.dmg"

echo -e "\n${GREEN}=== Success! ===${NC}"
echo -e "Your signed and notarized app is ready:"
echo -e "  App: ${GREEN}$APP_PATH${NC}"
echo -e "  ZIP: ${GREEN}${BUILD_DIR}/${APP_NAME}.zip${NC}"
echo -e "  DMG: ${GREEN}${BUILD_DIR}/${APP_NAME}.dmg${NC}"
echo -e "\nYou can now distribute the DMG to users.\n"
