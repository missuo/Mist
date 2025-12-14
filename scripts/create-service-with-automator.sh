#!/bin/bash

# Create Mist Upload Service using Automator CLI
# This creates a proper Quick Action that works

SERVICE_NAME="Upload to Mist"
SERVICE_DIR="$HOME/Library/Services"
WORKFLOW_PATH="$SERVICE_DIR/$SERVICE_NAME.workflow"

echo "=== Creating Mist Upload Service with Automator ==="
echo ""

# Create temporary AppleScript to build the workflow
TEMP_SCRIPT="/tmp/create-mist-service.applescript"

cat > "$TEMP_SCRIPT" << 'APPLESCRIPT'
tell application "Automator"
    set newAction to make new workflow with properties {name:"Upload to Mist"}
    
    tell newAction
        -- Set workflow type to service
        set workflowType to service workflow
        
        -- Add Run Shell Script action
        set shellAction to make new action with properties {name:"Run Shell Script"}
        
        -- Configure the shell script
        tell shellAction
            set value of setting "inputMethod" to "as arguments"
            set value of setting "shell" to "/bin/bash"
            set value of setting "COMMAND_STRING" to "#!/bin/bash

LOG=\"/tmp/mist-service.log\"
echo \"=== Service started: $(date)\" >> \"$LOG\"
echo \"Arguments: $@\" >> \"$LOG\"

paths=\"\"
for file in \"$@\"; do
    echo \"File: $file\" >> \"$LOG\"
    encoded=$(/usr/bin/python3 -c \"import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))\" \"$file\" 2>> \"$LOG\")
    [ -z \"$paths\" ] && paths=\"$encoded\" || paths=\"$paths,$encoded\"
done

if [ -n \"$paths\" ]; then
    url=\"mist://files?$paths\"
    echo \"Opening: $url\" >> \"$LOG\"
    /usr/bin/open \"$url\" >> \"$LOG\" 2>&1 || /usr/bin/open -a Mist \"$url\" >> \"$LOG\" 2>&1
fi"
        end tell
    end tell
    
    -- Save the workflow
    save newAction in POSIX file "WORKFLOW_PATH"
    
    close newAction
end tell
APPLESCRIPT

# Replace WORKFLOW_PATH placeholder
sed -i '' "s|WORKFLOW_PATH|$WORKFLOW_PATH|g" "$TEMP_SCRIPT"

# Run the AppleScript
echo "Creating workflow via Automator..."
osascript "$TEMP_SCRIPT"

if [ $? -eq 0 ] && [ -d "$WORKFLOW_PATH" ]; then
    echo "✓ Service created successfully"
    rm "$TEMP_SCRIPT"
    
    # Rebuild services
    /System/Library/CoreServices/pbs -flush
    
    echo ""
    echo "Next steps:"
    echo "1. Enable in System Settings → Keyboard → Services"
    echo "2. Right-click a file in Finder → Services → Upload to Mist"
else
    echo "❌ Failed to create service via Automator"
    echo ""
    echo "Let's try manual method instead..."
    rm "$TEMP_SCRIPT"
    exit 1
fi
APPLESCRIPT

chmod +x "$TEMP_SCRIPT"
