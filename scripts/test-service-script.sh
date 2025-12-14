#!/bin/bash

# Test the shell script that the service uses
# This simulates what happens when the service runs

echo "=== Testing Service Shell Script ==="
echo ""

# Create test files
TEST_FILE1="/tmp/test1.txt"
TEST_FILE2="/tmp/test2.txt"
echo "Test file 1" > "$TEST_FILE1"
echo "Test file 2" > "$TEST_FILE2"

echo "Created test files:"
echo "  - $TEST_FILE1"
echo "  - $TEST_FILE2"
echo ""

# Simulate what the service does
echo "Simulating service script..."
echo ""

paths=""

for file in "$TEST_FILE1" "$TEST_FILE2"; do
    echo "Processing: $file"
    # URL encode the path using Python
    encoded=$(python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))" "$file")
    echo "  Encoded: $encoded"
    
    if [ -z "$paths" ]; then
        paths="$encoded"
    else
        paths="$paths,$encoded"
    fi
done

echo ""
echo "Final URL: mist://files?$paths"
echo ""

read -p "Open this URL to test? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if pgrep -x "Mist" > /dev/null; then
        open "mist://files?$paths"
        echo "✓ URL opened"
        echo ""
        echo "Check Console.app for '[Mist] Received URL' messages"
    else
        echo "❌ Mist is not running. Start Mist first."
    fi
fi

echo ""
echo "Clean up test files:"
echo "  rm $TEST_FILE1 $TEST_FILE2"
