#!/bin/bash

# View Mist Service Log
LOG="/tmp/mist-service.log"

echo "=== Mist Service Log Viewer ==="
echo ""

if [ ! -f "$LOG" ]; then
    echo "❌ Log file not found: $LOG"
    echo ""
    echo "This means the service hasn't run yet."
    echo "Try right-clicking a file in Finder and selecting Services → Upload to Mist"
    exit 1
fi

echo "📄 Log file: $LOG"
echo "📊 File size: $(du -h "$LOG" | cut -f1)"
echo "📅 Last modified: $(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$LOG")"
echo ""
echo "=== Log Contents ==="
echo ""
cat "$LOG"
echo ""
echo "=== End of Log ==="
echo ""
echo "Commands:"
echo "  Clear log: rm $LOG"
echo "  Watch log: tail -f $LOG"
echo "  Monitor:   watch -n 1 cat $LOG"
