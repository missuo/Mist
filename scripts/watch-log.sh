#!/bin/bash

echo "Watching service log (Ctrl+C to stop)..."
echo "Go to Finder and right-click a file, select Services → Upload to Mist"
echo ""

# Watch log file
tail -f /tmp/mist-service.log 2>/dev/null &
TAIL_PID=$!

# Also watch for new file creation
while [ ! -f /tmp/mist-service.log ]; do
    sleep 0.5
done

# File appeared, show it
echo "=== Log appeared ==="
cat /tmp/mist-service.log
echo ""
echo "=== Watching for updates (Ctrl+C to stop) ==="

wait $TAIL_PID
