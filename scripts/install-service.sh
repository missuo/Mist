#!/bin/bash

# Install Mist Upload Service
# This script creates an Automator Quick Action for uploading files to Mist

SERVICE_NAME="Upload to Mist"
SERVICE_DIR="$HOME/Library/Services"
WORKFLOW_PATH="$SERVICE_DIR/$SERVICE_NAME.workflow"

echo "Installing Mist Upload Service..."

# Create Services directory if it doesn't exist
mkdir -p "$SERVICE_DIR"

# Remove existing service if present
if [ -d "$WORKFLOW_PATH" ]; then
    echo "Removing existing service..."
    rm -rf "$WORKFLOW_PATH"
fi

# Create the workflow structure
mkdir -p "$WORKFLOW_PATH/Contents"

# Create Info.plist
cat > "$WORKFLOW_PATH/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSServices</key>
    <array>
        <dict>
            <key>NSMenuItem</key>
            <dict>
                <key>default</key>
                <string>Upload to Mist</string>
            </dict>
            <key>NSMessage</key>
            <string>runWorkflowAsService</string>
            <key>NSSendFileTypes</key>
            <array>
                <string>public.data</string>
                <string>public.content</string>
                <string>public.item</string>
            </array>
            <key>NSReturnTypes</key>
            <array/>
        </dict>
    </array>
    <key>CFBundleIdentifier</key>
    <string>com.apple.Automator.UploadToMist</string>
    <key>CFBundleName</key>
    <string>Upload to Mist</string>
    <key>CFBundleVersion</key>
    <string>1.1</string>
    <key>CFBundlePackageType</key>
    <string>BNDL</string>
</dict>
</plist>
EOF

# Create document.wflow
cat > "$WORKFLOW_PATH/Contents/document.wflow" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>AMApplicationBuild</key>
    <string>523</string>
    <key>AMApplicationVersion</key>
    <string>2.10</string>
    <key>AMDocumentVersion</key>
    <string>2</string>
    <key>actions</key>
    <array>
        <dict>
            <key>action</key>
            <dict>
                <key>AMAccepts</key>
                <dict>
                    <key>Container</key>
                    <string>List</string>
                    <key>Optional</key>
                    <false/>
                    <key>Types</key>
                    <array>
                        <string>com.apple.cocoa.path</string>
                    </array>
                </dict>
                <key>AMActionVersion</key>
                <string>1.1.2</string>
                <key>AMApplication</key>
                <array>
                    <string>Automator</string>
                </array>
                <key>AMParameterProperties</key>
                <dict>
                    <key>source</key>
                    <dict/>
                </dict>
                <key>AMProvides</key>
                <dict>
                    <key>Container</key>
                    <string>List</string>
                    <key>Types</key>
                    <array>
                        <string>com.apple.cocoa.path</string>
                    </array>
                </dict>
                <key>ActionBundlePath</key>
                <string>/System/Library/Automator/Run Shell Script.action</string>
                <key>ActionName</key>
                <string>Run Shell Script</string>
                <key>ActionParameters</key>
                <dict>
                    <key>COMMAND_STRING</key>
                    <string>#!/bin/bash

# Log file for debugging
LOG="/tmp/mist-service.log"
echo "=== Mist Service Started at $(date) ===" >> "$LOG"

# Receive file paths as arguments: $1, $2, $3, etc.
# Build comma-separated list of URL-encoded paths

paths=""

for file in "$@"; do
    echo "Processing file: $file" >> "$LOG"
    
    # URL encode the path using Python
    encoded=$(/usr/bin/python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))" "$file" 2>> "$LOG")
    
    if [ -z "$paths" ]; then
        paths="$encoded"
    else
        paths="$paths,$encoded"
    fi
done

# Open mist:// URL scheme with all file paths
if [ -n "$paths" ]; then
    url="mist://files?$paths"
    echo "Opening URL: $url" >> "$LOG"
    
    # Try multiple methods to open the URL
    /usr/bin/open "$url" >> "$LOG" 2>&1
    
    # Also try launching Mist directly if open fails
    if [ $? -ne 0 ]; then
        echo "open command failed, trying to launch Mist directly" >> "$LOG"
        /usr/bin/open -a Mist "$url" >> "$LOG" 2>&1
    fi
    
    echo "Service completed" >> "$LOG"
else
    echo "No paths to upload" >> "$LOG"
fi
</string>
                    <key>CheckedForUserDefaultShell</key>
                    <true/>
                    <key>inputMethod</key>
                    <integer>1</integer>
                    <key>shell</key>
                    <string>/bin/bash</string>
                    <key>source</key>
                    <string></string>
                </dict>
                <key>BundleIdentifier</key>
                <string>com.apple.RunShellScript</string>
                <key>CFBundleVersion</key>
                <string>1.1.2</string>
                <key>CanShowSelectedItemsWhenRun</key>
                <false/>
                <key>CanShowWhenRun</key>
                <true/>
                <key>Category</key>
                <array>
                    <string>AMCategoryUtilities</string>
                </array>
                <key>Class Name</key>
                <string>RunShellScriptAction</string>
                <key>InputUUID</key>
                <string>A1B2C3D4-E5F6-7890-1234-567890ABCDEF</string>
                <key>Keywords</key>
                <array>
                    <string>Shell</string>
                    <string>Script</string>
                    <string>Command</string>
                    <string>Run</string>
                    <string>Unix</string>
                </array>
                <key>OutputUUID</key>
                <string>F1E2D3C4-B5A6-9876-5432-10FEDCBA9876</string>
                <key>UUID</key>
                <string>12345678-ABCD-EF01-2345-6789ABCDEF01</string>
                <key>UnlocalizedApplications</key>
                <array>
                    <string>Automator</string>
                </array>
                <key>arguments</key>
                <dict>
                    <key>0</key>
                    <dict>
                        <key>default value</key>
                        <integer>0</integer>
                        <key>name</key>
                        <string>inputMethod</string>
                        <key>required</key>
                        <string>0</string>
                        <key>type</key>
                        <string>0</string>
                        <key>uuid</key>
                        <string>0</string>
                    </dict>
                    <key>1</key>
                    <dict>
                        <key>default value</key>
                        <false/>
                        <key>name</key>
                        <string>CheckedForUserDefaultShell</string>
                        <key>required</key>
                        <string>0</string>
                        <key>type</key>
                        <string>0</string>
                        <key>uuid</key>
                        <string>1</string>
                    </dict>
                    <key>2</key>
                    <dict>
                        <key>default value</key>
                        <string></string>
                        <key>name</key>
                        <string>source</string>
                        <key>required</key>
                        <string>0</string>
                        <key>type</key>
                        <string>0</string>
                        <key>uuid</key>
                        <string>2</string>
                    </dict>
                    <key>3</key>
                    <dict>
                        <key>default value</key>
                        <string></string>
                        <key>name</key>
                        <string>COMMAND_STRING</string>
                        <key>required</key>
                        <string>0</string>
                        <key>type</key>
                        <string>0</string>
                        <key>uuid</key>
                        <string>3</string>
                    </dict>
                    <key>4</key>
                    <dict>
                        <key>default value</key>
                        <string>/bin/sh</string>
                        <key>name</key>
                        <string>shell</string>
                        <key>required</key>
                        <string>0</string>
                        <key>type</key>
                        <string>0</string>
                        <key>uuid</key>
                        <string>4</string>
                    </dict>
                </dict>
                <key>isViewVisible</key>
                <integer>1</integer>
            </dict>
            <key>isViewVisible</key>
            <integer>1</integer>
        </dict>
    </array>
    <key>connectors</key>
    <dict/>
    <key>workflowMetaData</key>
    <dict>
        <key>serviceInputTypeIdentifier</key>
        <string>com.apple.Automator.fileSystemObject</string>
        <key>serviceOutputTypeIdentifier</key>
        <string>com.apple.Automator.nothing</string>
        <key>serviceApplicationBundleID</key>
        <string>com.apple.finder</string>
        <key>workflowTypeIdentifier</key>
        <string>com.apple.Automator.servicesMenu</string>
    </dict>
</dict>
</plist>
EOF

# Set correct permissions
chmod 755 "$WORKFLOW_PATH"
chmod 644 "$WORKFLOW_PATH/Contents/Info.plist"
chmod 644 "$WORKFLOW_PATH/Contents/document.wflow"

echo "✓ Service installed at: $WORKFLOW_PATH"
echo ""
echo "Next steps:"
echo "1. Log out and log back in (or restart)"
echo "2. Right-click on a file in Finder"
echo "3. Go to Services > Upload to Mist"
echo ""
echo "Note: You may need to enable the service in System Settings:"
echo "  System Settings > Keyboard > Keyboard Shortcuts > Services"
echo "  Look for 'Upload to Mist' under 'Files and Folders'"
