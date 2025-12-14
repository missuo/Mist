#!/bin/bash

# Test Mist URL Scheme with Multiple Files
# This script tests batch upload functionality

echo "=== Mist Multi-File Upload Test ==="
echo ""

# Create test files in /tmp
TEST_DIR="/tmp/mist-test-$(date +%s)"
mkdir -p "$TEST_DIR"

echo "Creating test files..."
for i in {1..3}; do
    TEST_FILE="$TEST_DIR/test-file-$i.txt"
    echo "This is test file #$i created at $(date)" > "$TEST_FILE"
    echo "✓ Created: $TEST_FILE"
done

# Get all test files
FILES=($TEST_DIR/*.txt)

# URL encode each path and join with commas
ENCODED_PATHS=""
for file in "${FILES[@]}"; do
    ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$file'))")
    if [ -z "$ENCODED_PATHS" ]; then
        ENCODED_PATHS="$ENCODED"
    else
        ENCODED_PATHS="$ENCODED_PATHS,$ENCODED"
    fi
done

# Construct the URL
URL="mist://files?$ENCODED_PATHS"
echo ""
echo "✓ Constructed URL with ${#FILES[@]} files"
echo "  URL length: ${#URL} characters"

# Check if Mist is running
if ! pgrep -x "Mist" > /dev/null; then
    echo ""
    echo "⚠ Warning: Mist is not running!"
    echo "Starting Mist..."
    open -a Mist
    sleep 2
fi

echo ""
echo "Opening URL in Mist..."
open "$URL"

echo ""
echo "=== Test Instructions ==="
echo "1. Check Console.app for '[Mist] Received URL' messages"
echo "2. Verify that all ${#FILES[@]} files are uploaded"
echo "3. Check if all URLs are copied to clipboard (one per line)"
echo "4. Look for batch upload notifications"
echo ""
echo "Test files are in: $TEST_DIR"
echo "Clean up with: rm -rf '$TEST_DIR'"
