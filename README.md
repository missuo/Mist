<div align="center">
  <img src="./AppIcon.png" alt="Mist Icon" width="128" height="128">
  <h1>Mist</h1>
  <p><strong>A native macOS menu bar uploader for S3-compatible storage and S.EE</strong></p>

  <p>
    <a href="https://github.com/missuo/Mist/releases/latest"><img src="https://img.shields.io/github/v/release/missuo/Mist" alt="Latest Release"></a>
    <a href="https://github.com/missuo/Mist/blob/main/LICENSE"><img src="https://img.shields.io/github/license/missuo/Mist" alt="License"></a>
    <img src="https://img.shields.io/badge/macOS-14.0%2B-blue" alt="macOS 14.0+">
  </p>
</div>

Mist lives in your menu bar and gets files onto your storage — and their
URLs onto your clipboard — with as little friction as possible. Drop a
file on the icon, paste from the clipboard, or right-click anything in
Finder.

## Features

- **Menu bar first** — drag files onto the icon, upload from the
  clipboard, or pick files; URLs are copied automatically in your
  preferred format (URL, Markdown, HTML, or UBB)
- **Finder integration** — "Upload via Mist" directly in Finder's
  right-click menu, powered by a Finder Sync extension
- **Scriptable** — upload from the command line or any tool via the
  `mist://` URL scheme
- **Six storage providers** — Amazon S3, Wasabi, Cloudflare R2,
  Backblaze B2, MinIO, any S3-compatible endpoint, plus
  [S.EE](https://s.ee) file hosting with a single API token
- **Upload history** — searchable history with thumbnails, hover to
  preview images at full size, click to copy; the last five uploads are
  one click away in the menu bar
- **Image handling** — optional compression and EXIF stripping before
  upload (off by default)
- **iCloud sync** — host configurations follow you across Macs
- **Trustworthy releases** — signed with a Developer ID, notarized by
  Apple, and kept current through Sparkle automatic updates

## Install

**Homebrew**

```bash
brew install owo-network/brew/mist
```

**Manual**

Download `Mist-x.y.z.dmg` from the
[latest release](https://github.com/missuo/Mist/releases/latest) and
drag Mist into Applications.

Requires macOS 14.0 or later on Apple Silicon.

## Getting Started

1. Open **Preferences → Hosts** and add a host
   - S3-compatible providers: region or endpoint, bucket, access key,
     secret key, and optional URL prefix, ACL, and save path template
   - S.EE: just your [API token](https://s.ee/user/developers)
2. Enable the Finder extension when prompted (or later via
   **Enable Finder Extension...** in the menu bar menu)
3. Upload something — drag it onto the menu bar icon, or right-click it
   in Finder and choose **Upload via Mist**

Save path templates support `{filename}`, `{ext}`, `{year}`, `{month}`,
`{day}`, `{timestamp}`, `{random}`, and `{uuid}`.

## Scripting

```bash
open "mist://files?/path/to/image.png"
open "mist://files?/path/to/file1.jpg,/path/to/file2.png"
```

Mist uploads the files to your default host and copies the resulting
URLs to the clipboard.

## Development

```bash
git clone https://github.com/missuo/Mist.git
cd Mist
open Mist.xcodeproj
```

Mist is pure Objective-C on native macOS frameworks; the only dependency
is [Sparkle](https://sparkle-project.org) for automatic updates.
Releases are built, signed, notarized, and published entirely by
[GitHub Actions](.github/workflows/release.yml) on every `v*` tag —
including the Sparkle appcast and the Homebrew cask.

More docs:

- [Finder Extension](docs/finder-extension.md)
- [iCloud Sync](docs/icloud-sync.md)
- [Build and Release Scripts](scripts/README.md)

## Acknowledgments

Mist is built upon the great work of
[uPic](https://github.com/gee1k/uPic). 💙

## License

MIT. See [LICENSE](LICENSE).
