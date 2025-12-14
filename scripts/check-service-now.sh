#!/bin/bash

echo "=== Real-Time Service Check ==="
echo ""
echo "Waiting for service to run..."
echo "Go to Finder and right-click a file, then select Services → Upload to Mist"
echo ""
echo "Press Ctrl+C to stop watching"
echo ""

# Clear old log
rm -f /tmp/mist-service.log

# Watch for log creation and content
while true; do
    if [ -f /tmp/mist-service.log ]; then
        echo ""
        echo "=== Service Log Detected ==="
        cat /tmp/mist-service.log
        echo ""
        echo "=== Checking Mist Status ==="
        if pgrep -x "Mist" > /dev/null; then
            echo "✅ Mist is running"
        else
            echo "❌ Mist is NOT running"
        fi
        echo ""
        echo "=== Console Logs for Mist ==="
        log show --predicate 'process == "Mist"' --last 30s | grep -i "received\|url\|upload" || echo "No relevant logs"
        break
    fi
    sleep 0.5
done
