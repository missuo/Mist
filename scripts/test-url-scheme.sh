#!/bin/bash

# Test Mist URL Scheme Handler
# This script tests the mist://files URL scheme with a test file

echo "=== Mist URL Scheme Test ==="
echo ""

# Create a test file in /tmp
TEST_FILE="/tmp/mist-test-$(date +%s).txt"
echo "This is a test file created at $(date)" > "$TEST_FILE"
echo "✓ Created test file: $TEST_FILE"

# URL encode the path
ENCODED_PATH=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$TEST_FILE'))")
echo "✓ Encoded path: $ENCODED_PATH"

# Construct the URL
URL="mist://files?$ENCODED_PATH"
echo "✓ URL: $URL"
echo ""

# Check if Mist is running
if ! pgrep -x "Mist" > /dev/null; then
    echo "⚠ Warning: Mist is not running!"
    echo "Starting Mist..."
    open -a Mist
    sleep 2
fi

echo "Opening URL in Mist..."
open "$URL"

echo ""
echo "=== Test Instructions ==="
echo "1. Check if Mist receives the URL (watch Console.app for '[Mist] Received URL')"
echo "2. Verify that the file uploads"
echo "3. Check if the URL is copied to clipboard"
echo "4. Look for upload notification"
echo ""
echo "Test file will remain at: $TEST_FILE"
echo "You can manually delete it later with: rm '$TEST_FILE'"
