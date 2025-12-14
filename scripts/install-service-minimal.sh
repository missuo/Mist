#!/bin/bash

# Minimal Service Installation
# Creates a simpler, validated workflow

SERVICE_NAME="Upload to Mist"
SERVICE_DIR="$HOME/Library/Services"
WORKFLOW_PATH="$SERVICE_DIR/$SERVICE_NAME.workflow"

echo "Installing Mist Upload Service (minimal version)..."

# Remove old version
if [ -d "$WORKFLOW_PATH" ]; then
    echo "Removing existing service..."
    rm -rf "$WORKFLOW_PATH"
fi

# Create workflow structure
mkdir -p "$WORKFLOW_PATH/Contents"

# Create Info.plist
cat > "$WORKFLOW_PATH/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleIdentifier</key>
	<string>com.apple.Automator.UploadToMist</string>
	<key>CFBundleName</key>
	<string>Upload to Mist</string>
	<key>CFBundleVersion</key>
	<string>1.2</string>
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
				<string>public.item</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
EOF

# Create minimal document.wflow
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
					<string>LOG="/tmp/mist-service.log"
{
echo "=== Debug Info ==="
echo "Date: $(date)"
echo "PWD: $PWD"
echo "USER: $USER"
echo "Arg count: $#"
echo "Args: $@"
echo "Arg1: $1"
echo "Arg2: $2"
echo "All args:"
for arg in "$@"; do
  echo "  - $arg"
done
echo ""

if [ $# -eq 0 ]; then
  echo "ERROR: No arguments received!"
  echo "This means Automator is not passing file paths."
  exit 1
fi

paths=""
for f in "$@"; do
  echo "Processing: $f"
  encoded=$(/usr/bin/python3 -c "import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1]))" "$f")
  [ -z "$paths" ] &amp;&amp; paths="$encoded" || paths="$paths,$encoded"
done

if [ -n "$paths" ]; then
  url="mist://files?$paths"
  echo "Opening URL: $url"
  /usr/bin/open "$url" &amp;
  echo "Command sent"
fi
} &gt;&gt; "$LOG" 2&gt;&amp;1
exit 0
</string>
					<key>CheckedForUserDefaultShell</key>
					<true/>
					<key>inputMethod</key>
				<integer>1</integer>
					<key>shell</key>
					<string>/bin/bash</string>
				</dict>
				<key>BundleIdentifier</key>
				<string>com.apple.RunShellScript</string>
			</dict>
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
		<key>workflowTypeIdentifier</key>
		<string>com.apple.Automator.servicesMenu</string>
	</dict>
</dict>
</plist>
EOF

# Set permissions
chmod 755 "$WORKFLOW_PATH"
chmod 644 "$WORKFLOW_PATH/Contents/Info.plist"
chmod 644 "$WORKFLOW_PATH/Contents/document.wflow"

echo "✓ Service installed"

# Validate the workflow
if /usr/bin/plutil -lint "$WORKFLOW_PATH/Contents/Info.plist" > /dev/null 2>&1; then
    echo "✓ Info.plist is valid"
else
    echo "❌ Info.plist validation failed"
fi

if /usr/bin/plutil -lint "$WORKFLOW_PATH/Contents/document.wflow" > /dev/null 2>&1; then
    echo "✓ document.wflow is valid"
else
    echo "❌ document.wflow validation failed"
fi

# Rebuild services
/System/Library/CoreServices/pbs -flush
echo "✓ Services database refreshed"

echo ""
echo "Next steps:"
echo "1. Enable in System Settings → Keyboard → Services"
echo "2. Test by right-clicking a file in Finder"
echo "3. Check log: ./scripts/view-service-log.sh"
