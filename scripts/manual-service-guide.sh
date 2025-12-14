#!/bin/bash

cat << 'EOF'
╔════════════════════════════════════════════════════════════════╗
║          Manual Service Creation Guide for Mist               ║
╚════════════════════════════════════════════════════════════════╝

The automatic script created a corrupted workflow. Let's create it manually:

STEP 1: Open Automator
─────────────────────
1. Press Cmd+Space and type "Automator"
2. Press Enter to open Automator

STEP 2: Create New Quick Action
────────────────────────────────
1. Click "New Document"
2. Select "Quick Action" (or "Service" on older macOS)
3. Click "Choose"

STEP 3: Configure Workflow Settings
────────────────────────────────────
At the top of the window, configure:
1. "Workflow receives current" → select "files or folders"
2. "in" → select "Finder.app"
3. Color: Blue (matches system services)

STEP 4: Add Shell Script Action
────────────────────────────────
1. In the left panel, find "Run Shell Script" action
2. Drag it to the right panel
3. Configure:
   - "Shell": /bin/bash
   - "Pass input": as arguments ⚠️ IMPORTANT!

STEP 5: Paste the Script
─────────────────────────
Delete the placeholder text and paste this:

EOF

cat << 'SCRIPT'
#!/bin/bash

LOG="/tmp/mist-service.log"
echo "=== Service started: $(date)" >> "$LOG"
echo "Arguments: $@" >> "$LOG"

paths=""
for file in "$@"; do
    echo "File: $file" >> "$LOG"
    encoded=$(/usr/bin/python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))" "$file" 2>> "$LOG")
    [ -z "$paths" ] && paths="$encoded" || paths="$paths,$encoded"
done

if [ -n "$paths" ]; then
    url="mist://files?$paths"
    echo "Opening: $url" >> "$LOG"
    /usr/bin/open "$url" >> "$LOG" 2>&1 || /usr/bin/open -a Mist "$url" >> "$LOG" 2>&1
    echo "Done" >> "$LOG"
fi
SCRIPT

cat << 'EOF'

STEP 6: Save the Service
────────────────────────
1. Press Cmd+S
2. Save as: "Upload to Mist"
3. It will save to ~/Library/Services/ automatically

STEP 7: Enable the Service
───────────────────────────
1. Open System Settings (or System Preferences)
2. Go to: Keyboard → Keyboard Shortcuts → Services
3. Scroll down to "Files and Folders"
4. Find "Upload to Mist" and check the box ✓

STEP 8: Test
────────────
1. Open Finder
2. Select a file (e.g., a text file on Desktop)
3. Right-click → Services → Upload to Mist
4. Run: ./scripts/view-service-log.sh

╔════════════════════════════════════════════════════════════════╗
║  IMPORTANT: Make sure "Pass input" is set to "as arguments"   ║
║             NOT "to stdin" (this was the bug!)                 ║
╚════════════════════════════════════════════════════════════════╝

Press Enter when you've created the service...
EOF

read -r

echo ""
echo "Checking if service was created..."
if [ -d "$HOME/Library/Services/Upload to Mist.workflow" ]; then
    echo "✅ Service found!"
    echo ""
    echo "Rebuilding services database..."
    /System/Library/CoreServices/pbs -flush
    echo "✓ Done"
    echo ""
    echo "Now try it in Finder!"
else
    echo "❌ Service not found yet"
    echo "Make sure you saved it as 'Upload to Mist'"
fi
