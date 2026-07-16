# iCloud Sync

Mist can sync its configuration across your Macs through iCloud Key-Value
Storage (`NSUbiquitousKeyValueStore`). Sync is opt-in: enable it in
Preferences → General → "Sync Hosts Configuration with iCloud".

## What Gets Synced

- Host configuration list
- Default host ID
- Output format setting
- Compression quality setting
- Remove-EXIF setting

## How It Works

- **Automatic upload**: every configuration save is pushed to iCloud
- **Automatic load**: on launch, configuration is loaded from iCloud first
  (when sync is enabled)
- **Live updates**: changes made on another device arrive via
  `NSUbiquitousKeyValueStoreDidChangeExternallyNotification` and are applied
  immediately
- **Local cache**: local configuration keeps working even with iCloud
  disabled — local storage is `NSUserDefaults` (App Group), iCloud is the
  backup

Conflicts are resolved by the system with a last-writer-wins strategy: the
newest data replaces older data on all devices.

## API

Implementation lives in `MSTiCloudSyncManager` and is integrated through
`MSTConfigManager`:

```objective-c
// Enable / disable sync
[MSTConfigManager sharedManager].iCloudSyncEnabled = YES;

// Check availability (requires an iCloud account)
BOOL available = [MSTConfigManager sharedManager].iCloudAvailable;

// Observe configuration changes (including those arriving from iCloud)
[[NSNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(configDidChange:)
           name:MSTConfigDidChangeNotification
         object:nil];
```

## Notes

1. **iCloud account**: the user must be signed in to iCloud for sync to work
2. **Network**: sync needs connectivity; offline changes sync automatically
   once the network returns
3. **Storage limit**: `NSUbiquitousKeyValueStore` allows 1 MB per app, which
   is plenty for configuration data
4. **Privacy**: credentials (access keys, secret keys, tokens) sync along
   with host configurations — they are stored in the user's private iCloud
   key-value store

## Troubleshooting

**iCloud unavailable** — check that the user is signed in to iCloud and the
app has the iCloud Key-Value Storage entitlement.

**Data not syncing** — check that `iCloudSyncEnabled` is on, the network is
reachable, and look for errors in the console log (`[iCloud Sync]` prefix).

**Quota exceeded** — a `NSUbiquitousKeyValueStoreQuotaViolationChange` error
means the stored data outgrew the 1 MB limit; reduce the number of host
configurations, or migrate to CloudKit if configurations ever need to grow
beyond it.
