# Mist Services Troubleshooting Guide

## "There was a problem with the input to the Service" Error

This is the most common error when setting up the Mist Upload Service. Here's how to fix it:

### Solution 1: Reinstall with Latest Script

The installation script has been updated multiple times to fix input handling. Make sure you're using the latest version:

```bash
cd /path/to/Mist
./scripts/install-service.sh
```

After installation:
```bash
# Refresh services database
/System/Library/CoreServices/pbs -flush

# Restart Finder
killall Finder
```

### Solution 2: Verify Service Configuration

Check if the service is properly configured:

```bash
plutil -p ~/Library/Services/"Upload to Mist.workflow"/Contents/Info.plist
```

You should see:
- `NSSendFileTypes` with `public.item`, `public.data`, `public.content`
- `NSMessage` = `runWorkflowAsService`

And in `document.wflow`:
```bash
grep -A 2 "serviceInputTypeIdentifier" ~/Library/Services/"Upload to Mist.workflow"/Contents/document.wflow
```

Should show:
```xml
<key>serviceInputTypeIdentifier</key>
<string>com.apple.Automator.fileSystemObject</string>
```

### Solution 3: Check What Files You're Selecting

The service only works with regular files. It may not work with:
- System files or protected directories
- Package bundles (.app, .bundle)
- Special items (Trash, network locations)
- Files with very long paths

Try with a simple text file first:
```bash
echo "test" > ~/Desktop/test.txt
```

Then right-click on `test.txt` in Finder.

### Solution 4: Manual Service Creation (Alternative Method)

If the script doesn't work, create the service manually using Automator:

1. Open **Automator.app**
2. Create a new **Quick Action** (or "Service" in older macOS)
3. Configure at the top:
   - "Workflow receives current" → **files or folders**
   - "in" → **Finder**
4. Add action: **Run Shell Script**
5. Set "Pass input:" to **as arguments**
6. Paste this script:

```bash
#!/bin/bash

paths=""

for file in "$@"; do
    encoded=$(python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))" "$file")
    
    if [ -z "$paths" ]; then
        paths="$encoded"
    else
        paths="$paths,$encoded"
    fi
done

if [ -n "$paths" ]; then
    open "mist://files?$paths"
fi
```

7. Save as "Upload to Mist" (it will save to `~/Library/Services/`)

## Service Doesn't Appear in Menu

### Check if Service Exists

```bash
ls -la ~/Library/Services/
```

You should see `Upload to Mist.workflow`.

### Enable in System Settings

1. Open **System Settings** (or System Preferences)
2. Go to **Keyboard** → **Keyboard Shortcuts** → **Services**
3. Scroll to **Files and Folders** section
4. Find **Upload to Mist** and check the box

### Rebuild Services Database

```bash
/System/Library/CoreServices/pbs -flush
killall Finder
```

Wait 10-15 seconds for Finder to restart, then try again.

### Reset Services Cache (Last Resort)

```bash
# Backup first
cp -R ~/Library/Services ~/Library/Services.backup

# Remove services cache
rm ~/Library/Preferences/pbs.plist
rm ~/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist

# Rebuild
/System/Library/CoreServices/lsregister -kill -r -domain local -domain system -domain user
/System/Library/CoreServices/pbs -flush

# Reinstall service
./scripts/install-service.sh

# Restart
killall Finder
```

## Service Appears But Nothing Happens

### Check if Mist is Running

```bash
ps aux | grep "[M]ist"
```

If not running, start Mist from Applications.

### Test URL Scheme Directly

```bash
# Create a test file
echo "test" > /tmp/test.txt

# Test the URL scheme
open "mist://files?/tmp/test.txt"
```

If this works but the service doesn't, the problem is with the service configuration.

If this doesn't work, the problem is with Mist's URL handler.

### Check Console Logs

Open **Console.app** and search for "Mist". You should see:
- `[Mist] Received URL: mist://files?...`
- `[Mist] Files to upload: ...`
- `[Mist] Processing path: ...`

If you don't see these messages, Mist isn't receiving the URL.

### Verify URL Scheme Registration

```bash
# Find Mist app
mdfind "kMDItemCFBundleIdentifier == 'com.missuo.Mist'"

# Check if it's registered for mist://
defaults read /Applications/Mist.app/Contents/Info.plist CFBundleURLTypes
```

Should show `mist` in `CFBundleURLSchemes`.

## Files Upload But URLs Not Copied

### Check Clipboard Permissions

Make sure Mist has permission to access the clipboard. In **System Settings** → **Privacy & Security** → **Accessibility**, check if Mist is listed and enabled.

### Check Batch Upload Logic

Open Console.app and check if you see:
- `batchUploadTotal` and `batchUploadCompleted` logs
- Upload completion messages

The app should copy URLs after all uploads complete.

## Debugging Tools

### Use the Debug Script

```bash
./scripts/debug-service.sh
```

This will check:
- Service installation
- URL scheme registration
- Mist running status
- Test upload

### Test Service Script Separately

```bash
./scripts/test-service-script.sh
```

This simulates what the service does without using the service system.

### Check Automator Logs

Look for Automator-related errors:

```bash
log show --predicate 'process == "Automator" OR process == "com.apple.Automator"' --last 10m
```

## Common Issues and Solutions

| Issue | Solution |
|-------|----------|
| Service grayed out | Select files, not folders or applications |
| Service runs but no notification | Check Notification permissions for Mist |
| Upload fails | Verify S3 host configuration in Mist preferences |
| Slow upload | Check network connection and S3 endpoint |
| Permission denied | Files may be in protected location - need Full Disk Access |

## Still Not Working?

If none of the above solutions work:

1. **Collect diagnostic information:**
   ```bash
   ./scripts/debug-service.sh > debug-output.txt
   ```

2. **Check system logs:**
   ```bash
   log show --predicate 'subsystem == "com.apple.Services"' --last 1h > services-log.txt
   ```

3. **Try the alternative upload methods:**
   - Drag & drop to menu bar icon
   - Use "Select File..." from menu
   - Use Share Extension
   - Use URL scheme directly from Terminal

4. **Verify prerequisites:**
   - macOS 11.0 or later
   - Python 3 installed (`which python3`)
   - Mist app properly installed in /Applications
   - No third-party security software blocking services

## Version Information

The install script creates version 1.1 of the service with these key configurations:

- **Input Method**: Arguments (`inputMethod=0`)
- **Input Type**: Files or folders (`com.apple.Automator.fileSystemObject`)
- **Accepted Types**: `public.item`, `public.data`, `public.content`
- **Output**: None (URLs go to clipboard)

To check your installed version:
```bash
plutil -p ~/Library/Services/"Upload to Mist.workflow"/Contents/Info.plist | grep CFBundleVersion
```
