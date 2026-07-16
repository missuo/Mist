# Finder Extension

Mist ships a Finder Sync extension (`MistFinder.appex`) that adds
**Upload via Mist** directly to Finder's right-click menu — no digging
through the Services submenu.

## Enabling

1. Launch Mist once (the extension registers with the system on first launch)
2. Open **System Settings → General → Login Items & Extensions →
   Extensions → Added Extensions** (on older macOS:
   **Privacy & Security → Extensions → Finder Extensions**)
3. Enable **MistFinder** under Finder extensions

After enabling, right-click any file in Finder and choose
**Upload via Mist**. Multiple selections upload as a batch, and the
resulting URLs are copied to the clipboard in your configured output
format.

## How It Works

- The extension (`MistFinder/MSTFinderSync.m`) subclasses `FIFinderSync`
  and watches `/`, so the menu item is available for any selection
- On click, it percent-encodes the selected paths and opens
  `mist://files?<path1>,<path2>,...` — the same URL scheme the app
  already handles — which launches Mist if needed and starts the upload
- The extension is sandboxed (required for Finder Sync extensions) and
  contains no upload logic or credentials itself

## Troubleshooting

**The menu item doesn't appear**
- Check the extension is enabled in System Settings (see above)
- Check it is registered: `pluginkit -m -p com.apple.FinderSync` should
  list `nz.owo.Mist.MistFinder`
- Relaunch Finder after enabling: `killall Finder`

**Uploads don't start**
- Make sure Mist is configured with at least one host
- Test the URL scheme directly:
  `open "mist://files?/tmp/test.png"`
