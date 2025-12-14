#!/bin/bash

# Test the service shell script directly
# This simulates what Automator should do

echo "=== Direct Service Script Test ==="
echo ""

# Create a test file
TEST_FILE="/tmp/test-$(date +%s).txt"
echo "Test content" > "$TEST_FILE"
echo "Created test file: $TEST_FILE"
echo ""

# Run the exact same script that's in the service
LOG="/tmp/mist-service.log"
rm -f "$LOG"

echo "Running service script..."
/bin/bash << EOF
LOG="/tmp/mist-service.log"
echo "Started: \$(date)" >> "\$LOG"
echo "Args: \$@" >> "\$LOG"
paths=""
for f in "\$@"; do
  encoded=\$(/usr/bin/python3 -c "import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1]))" "\$f" 2>>"\$LOG")
  [ -z "\$paths" ] && paths="\$encoded" || paths="\$paths,\$encoded"
done
if [ -n "\$paths" ]; then
  url="mist://files?\$paths"
  echo "URL: \$url" >> "\$LOG"
  /usr/bin/open "\$url" >/dev/null 2>&1 &
  echo "Opened" >> "\$LOG"
fi
exit 0
EOF "$TEST_FILE"

echo ""
echo "=== Log Output ==="
cat "$LOG"
echo ""
echo "=== Check if Mist received it ==="
sleep 1
if pgrep -x "Mist" > /dev/null; then
    echo "✅ Mist is running"
    echo "Check Console.app for '[Mist] Received URL' messages"
else
    echo "❌ Mist is not running"
fi
