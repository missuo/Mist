# Quick Start Guide - Mist Services

## Install (30 seconds)

```bash
cd /path/to/Mist
./scripts/install-service.sh
/System/Library/CoreServices/pbs -flush
killall Finder
```

## Enable (System Settings)

1. System Settings → Keyboard → Keyboard Shortcuts → Services
2. Find "Upload to Mist" under "Files and Folders"
3. Check the box ✅

## Use

1. Select file(s) in Finder
2. Right-click → Services → Upload to Mist
3. URLs copied to clipboard ✅

## Troubleshooting

### "There was a problem with the input"
```bash
./scripts/install-service.sh  # Reinstall
/System/Library/CoreServices/pbs -flush && killall Finder
```

### Service doesn't appear
- Log out and log back in
- Check System Settings → Services
- Run: `/System/Library/CoreServices/pbs -flush`

### Nothing happens
- Make sure Mist is running
- Test: `open "mist://files?/tmp/test.txt"`
- Check Console.app for "[Mist] Received URL"

## Test

```bash
# Quick test
./scripts/test-url-scheme.sh

# Debug
./scripts/debug-service.sh
```

## Help

- Setup: [services.md](services.md)
- Troubleshooting: [troubleshooting.md](troubleshooting.md)
