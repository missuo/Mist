# Mist Services Integration

This document describes how to use Mist with macOS Services (right-click menu) to upload files directly from Finder.

## Installation

Run the installation script:

```bash
./scripts/install-service.sh
```

This will create an Automator Quick Action called "Upload to Mist" in your `~/Library/Services` directory.

## Enabling the Service

After installation, you may need to enable the service:

1. Open **System Settings** (or **System Preferences** on older macOS)
2. Go to **Keyboard** > **Keyboard Shortcuts** > **Services**
3. Scroll down to **Files and Folders**
4. Check the box next to **Upload to Mist**

## Usage

### Single File Upload

1. Right-click on a file in Finder
2. Select **Services** > **Upload to Mist**
3. The file will be uploaded and the URL will be copied to your clipboard

### Multiple File Upload

1. Select multiple files in Finder (Cmd+Click or Shift+Click)
2. Right-click on the selection
3. Select **Services** > **Upload to Mist**
4. All files will be uploaded and URLs will be copied to your clipboard (one per line)

## How It Works

The service works by:

1. Receiving selected file paths from Finder
2. URL-encoding the paths
3. Opening a `mist://files?path1,path2,path3` URL
4. The Mist app intercepts this URL and uploads the files
5. URLs are copied to clipboard and a notification is shown

## Troubleshooting

### Service doesn't appear in menu

- Log out and log back in (or restart your Mac)
- Check if the service is enabled in System Settings > Keyboard > Keyboard Shortcuts > Services
- Make sure Mist.app is running
- Try rebuilding Services database: `/System/Library/CoreServices/pbs -flush`

### Service appears but nothing happens

- Check Console.app for error messages
- Make sure Mist has Full Disk Access if you're trying to upload files from restricted locations
- Verify that Mist.app is properly handling the `mist://` URL scheme
- Test the URL scheme directly: `open "mist://files?/tmp/test.txt"`

### "There was a problem with the input to the Service" error

This error usually means the service isn't receiving file paths correctly. The installation script has been updated to fix this:

- Run `./scripts/install-service.sh` again to reinstall with the correct configuration
- Make sure you're selecting actual files (not folders or special items)
- The service now uses `inputMethod=0` (arguments) instead of stdin

### Files not uploading

- Make sure you have configured a host in Mist preferences
- Check that the files are readable (not in a restricted location without Full Disk Access)
- Look for notifications from Mist about upload status
- Open Console.app and filter for "Mist" to see detailed logs

## Uninstallation

To remove the service:

```bash
rm -rf ~/Library/Services/"Upload to Mist.workflow"
```

Then log out and log back in.

## Technical Details

The service uses:

- **Automator Quick Action**: Creates a system service visible in Finder's right-click menu
- **URL Scheme**: `mist://files?<url-encoded-paths>` to communicate with the app
- **Shell Script**: Encodes file paths and constructs the URL
- **NSAppleEventManager**: Handles URL events in the main app

### URL Format

```
mist://files?path1,path2,path3
```

Where each path is URL-encoded. Example:

```
mist://files?/Users/name/file1.png,/Users/name/Documents/file2.jpg
```

### Code Flow

1. User selects files in Finder
2. Automator service receives file paths via stdin
3. Shell script URL-encodes paths and constructs `mist://` URL
4. `open` command launches URL
5. macOS routes URL to Mist.app (registered via CFBundleURLTypes)
6. `MSTAppDelegate` receives URL via `handleURLEvent:withReplyEvent:`
7. App parses URL and calls `uploadFilesAtPaths:`
8. Files are uploaded using `MSTS3Uploader`
9. Results are copied to clipboard and notification is shown
