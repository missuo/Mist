# Mist

<div align="center">
  <img src="./AppIcon.png" alt="Mist Icon" width="128" height="128">
  <p><strong>A native macOS menu bar uploader for S3-compatible storage and S.EE image hosting</strong></p>

  <p>
  </p>
</div>

## Overview

Mist is a lightweight macOS menu bar app for uploading images and files. It supports drag-and-drop uploads, Finder Services, the `mist://` URL scheme, S3-compatible storage, and S.EE image hosting.

## Features

- Drag files onto the menu bar icon to upload
- Automatically copy uploaded URLs to the clipboard
- Upload multiple files with progress tracking
- Upload from Finder through macOS Services
- Upload from scripts with `mist://`
- Compress images, remove EXIF metadata, and convert formats locally
- Sync host configuration with iCloud
- Store credentials in macOS Keychain

## Providers

- Amazon S3
- Wasabi
- Cloudflare R2
- Backblaze B2
- MinIO
- Custom S3-compatible endpoints
- S.EE image hosting

## Install

Download the latest build from [Releases](https://github.com/missuo/Mist/releases), open `Mist.dmg`, and drag Mist into Applications.

Requirements:

- macOS 11.0 or later
- Apple Silicon or Intel Mac

## Configure

Open **Preferences** -> **Hosts** and add a host.

For S3-compatible providers, configure:

- Region or custom endpoint
- Bucket
- Access Key and Secret Key
- Optional URL prefix, ACL, HTTPS, and save path template

For S.EE, only the API token is required. S3-only fields are hidden when S.EE is selected.

Save path templates support:

- `{filename}`
- `{ext}`
- `{year}`, `{month}`, `{day}`
- `{timestamp}`
- `{random}`
- `{uuid}`

## Usage

Drag one or more files onto the Mist menu bar icon. Mist uploads them and copies the resulting URL or URLs to the clipboard.

Finder integration: enable the **MistFinder** extension in System Settings -> General -> Login Items & Extensions -> Extensions, then right-click any file in Finder and choose **Upload to Mist**. See [docs/finder-extension.md](docs/finder-extension.md) for details.

URL scheme:

```bash
open "mist://files?/path/to/image.png"
open "mist://files?/path/to/file1.jpg,/path/to/file2.png"
```

## Development

```bash
git clone https://github.com/missuo/Mist.git
cd Mist
open Mist.xcodeproj
```

Mist is built with native macOS frameworks, including Cocoa, Foundation, CloudKit, UniformTypeIdentifiers, and UserNotifications.

## Documentation

- [Signing, Notarization, and Releases](docs/signing.md)
- [Finder Extension](docs/finder-extension.md)
- [iCloud Sync](docs/icloud-sync.md)
- [Build and Release Scripts](scripts/README.md)

## License

MIT. See [LICENSE](LICENSE).
