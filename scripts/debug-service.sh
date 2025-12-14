#!/bin/bash

# Debug Mist Service
# This script helps troubleshoot the Mist Upload Service

echo "=== Mist Service Debugger ==="
echo ""

# Check if service exists
SERVICE_PATH="$HOME/Library/Services/Upload to Mist.workflow"
if [ ! -d "$SERVICE_PATH" ]; then
    echo "❌ Service not found at: $SERVICE_PATH"
    echo "   Run ./scripts/install-service.sh to install"
    exit 1
else
    echo "✓ Service found at: $SERVICE_PATH"
fi

# Check Info.plist
echo ""
echo "=== Service Configuration ==="
echo "Info.plist:"
plutil -p "$SERVICE_PATH/Contents/Info.plist" | grep -A 5 "NSServices"

# Check if Mist is registered for mist:// URL scheme
echo ""
echo "=== URL Scheme Registration ==="
APP_PATH=$(mdfind "kMDItemCFBundleIdentifier == 'com.missuo.Mist'" | head -1)
if [ -n "$APP_PATH" ]; then
    echo "✓ Mist app found at: $APP_PATH"
    defaults read "$APP_PATH/Contents/Info.plist" CFBundleURLTypes 2>/dev/null | grep -A 2 "mist"
else
    echo "❌ Mist app not found"
    echo "   Make sure Mist.app is installed"
fi

# Check if Mist is running
echo ""
echo "=== Mist Running Status ==="
if pgrep -x "Mist" > /dev/null; then
    echo "✓ Mist is running"
    ps aux | grep "[M]ist" | awk '{print "  PID:", $2, "Started:", $9}'
else
    echo "⚠ Mist is not running"
    echo "  Start Mist before testing the service"
fi

# Test URL scheme
echo ""
echo "=== URL Scheme Test ==="
TEST_FILE="/tmp/mist-debug-test.txt"
echo "Test file created at $(date)" > "$TEST_FILE"
ENCODED=$(python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))" "$TEST_FILE")
TEST_URL="mist://files?$ENCODED"

echo "Created test file: $TEST_FILE"
echo "Test URL: $TEST_URL"
echo ""
read -p "Press Enter to test URL scheme (this will upload the test file)..."

open "$TEST_URL"

echo ""
echo "✓ URL opened"
echo ""
echo "=== Check Results ==="
echo "1. Did you see a notification from Mist?"
echo "2. Was the URL copied to clipboard?"
echo "3. Check Console.app for '[Mist] Received URL' messages"
echo ""
echo "To view logs in Console.app:"
echo "  1. Open Console.app"
echo "  2. Select your Mac in the sidebar"
echo "  3. Search for 'Mist' in the search box"
echo "  4. Look for messages like:"
echo "     [Mist] Received URL: mist://files?..."
echo "     [Mist] Files to upload: ..."
echo ""
echo "Test file remains at: $TEST_FILE"

# Rebuild services database
echo ""
read -p "Rebuild services database? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Rebuilding services database..."
    /System/Library/CoreServices/pbs -flush
    killall Finder
    echo "✓ Services database rebuilt, Finder restarted"
    echo "  Try the service again in a few seconds"
fi
