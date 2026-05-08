# Mist

<div align="center">
  <img src="./AppIcon.png" alt="Mist Icon" width="128" height="128">
  <p><strong>A native macOS menu bar uploader for S3-compatible storage and SM.MS image hosting</strong></p>

  <p>
    <b>English</b> | <a href="README_CN.md">简体中文</a>
  </p>
</div>

## Overview

Mist is a lightweight, native macOS menu bar application that simplifies uploading images and files to cloud destinations. With drag-and-drop uploads, modular providers (S3-compatible services and SM.MS image hosting), batch support, and automatic clipboard integration, Mist streamlines your workflow for sharing files quickly and efficiently.

## Features

### Core Functionality
- **🚀 Quick Upload**: Drag and drop files directly to the menu bar icon
- **📋 Auto Clipboard**: Automatically copies uploaded file URLs to clipboard
- **🔄 Batch Upload**: Upload multiple files simultaneously with progress tracking
- **🖱️ Finder Services**: Upload directly from Finder via right-click Services
- **📱 URL Scheme**: Upload files via `mist://` URL scheme for automation

### Upload Provider Support
- Amazon S3
- Wasabi
- Cloudflare R2
- Backblaze B2
- MinIO
- Custom S3-compatible endpoints
- SM.MS image hosting (token-based, image-only)

### Advanced Features
- **☁️ iCloud Sync**: Synchronize configurations across all your Apple devices
- **🎨 Image Processing**: 
  - On-the-fly image compression with adjustable quality
  - EXIF metadata removal for privacy
  - Modern format support: **AVIF (macOS 13+)**, **WebP (macOS 11+)**, **HEIC (macOS 10.13+)**, JPEG, and PNG
  - Intelligent format fallback for older macOS versions
- **⚙️ Multi-Host Management**: 
  - Manage multiple host configurations
  - Quick switch between different hosts
  - Duplicate configurations with one click
- **🎯 Flexible Path Templating**: Customize upload paths with variables like `{filename}`, `{ext}`, `{year}`, `{month}`, `{day}`
- **🔐 Secure Storage**: Credentials stored securely in macOS Keychain
- **📊 Upload History**: Track successful uploads with clickable links

## Installation

### Download
Download the latest version from the [Releases](https://github.com/missuo/Mist/releases) page.

### Requirements
- macOS 11.0 (Big Sur) or later
- Apple Silicon (M1/M2/M3) or Intel processor

### Setup
1. Download and open `Mist.dmg`
2. Drag Mist to your Applications folder
3. Launch Mist from Applications or Spotlight
4. Click the Mist icon in the menu bar to access preferences

## Configuration

### Adding a Host

1. Click the Mist menu bar icon
2. Select **Preferences** → **Hosts**
3. Click the **+** button to add a new host
4. Configure provider-specific settings:

#### Basic Settings
- **Name**: A friendly name for this configuration
- **Provider**: Choose S3-compatible providers or SM.MS
- **Region**: Required for AWS S3 (auto-adjusts per provider)
- **Bucket**: S3 bucket name (hidden for SM.MS)
- **Access Key / Secret Key**: S3 credentials (hidden for SM.MS)
- **Token**: SM.MS API token (only visible for SM.MS)

#### Advanced Settings
- **Custom Endpoint**: Override default endpoint (for custom S3 services)
- **Custom Domain**: Use a custom CDN domain for uploaded file URLs
- **Save Path Template**: Customize the upload path structure
  - `{filename}`: Original filename without extension
  - `{ext}`: File extension
  - `{year}`, `{month}`, `{day}`: Date components
  - `{timestamp}`: Unix timestamp
  - Example: `images/{year}/{month}/{filename}.{ext}`
- **ACL**: Set object access control (public-read, private, etc.)

*Note*: SM.MS uploads only require the API token; S3-specific fields (bucket, keys, ACL, path, domain) are hidden and not used.

### Managing Hosts

- **Set Default**: Click the ★ star button to set a host as default
- **Duplicate**: Click the duplicate button to copy an existing configuration
- **Delete**: Select a host and click the − minus button to remove it

### General Settings

- **Output Format**: Choose image format (JPEG, PNG, WebP, or keep original)
- **Compression Factor**: Adjust compression quality (0-90). Supports **AVIF**, **WebP**, **HEIC**, and **JPEG**.
- **Remove EXIF**: Strip metadata from images for privacy
- **iCloud Sync**: Enable to sync configurations across devices

## Usage

### Upload via Drag & Drop
1. Drag one or more files to the Mist menu bar icon
2. Files will be uploaded automatically
3. URLs are copied to clipboard when complete
4. Click the notification to open the URL

### Upload via Services (Right-Click Menu)
Install the Mist Upload Service for direct Finder integration:

```bash
./scripts/install-service.sh
```

After installation and enabling in System Settings:
1. Right-click on one or more files in Finder
2. Select **Services** → **Upload to Mist**
3. Files upload automatically and URLs are copied to clipboard

See [SERVICES.md](SERVICES.md) for detailed setup instructions.

**Troubleshooting**: If you see "There was a problem with the input to the Service", see [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for solutions.

### Upload via URL Scheme
Automate uploads using the `mist://` URL scheme:

```bash
# Upload a single file
open "mist://files?/path/to/image.png"

# Upload multiple files
open "mist://files?/path/to/file1.jpg,/path/to/file2.png"
```

### Quick Actions
- Click **Open Last Upload** to open the most recently uploaded file
- View upload history in the menu
- Use **Upload from File...** to browse and select files

## iCloud Sync

Mist supports syncing configurations across all your Apple devices using iCloud.

### Setup
1. Ensure you're signed in to iCloud on all devices
2. Enable **iCloud Sync** in Preferences → General
3. All host configurations and settings will sync automatically

### What Gets Synced
- All host configurations (S3 providers and SM.MS)
- Default host selection
- Image processing settings
- Output format preferences

### Privacy Note
Sensitive credentials (Access Keys and Secret Keys) are synced via iCloud. Ensure you trust the devices connected to your iCloud account.

## Security

- **Keychain Integration**: Credentials are stored in macOS Keychain
- **App Sandbox**: Runs in a sandboxed environment for security
- **No Analytics**: Mist does not collect any usage data or analytics
- **Local Processing**: All image processing happens on-device

## Permissions

Mist requires the following permissions:

- **Network**: To upload files to configured providers
- **File Access**: To read files you choose to upload
- **Notifications**: To notify you when uploads complete
- **iCloud**: (Optional) To sync configurations across devices

## Development

### Building from Source

```bash
# Clone the repository
git clone https://github.com/missuo/Mist.git
cd Mist

# Open in Xcode
open Mist.xcodeproj

# Build and run
# Press Cmd+R in Xcode
```

### Project Structure
```
Mist/
├── App/                    # Application lifecycle and delegates
├── Controllers/            # View controllers for UI
├── Models/                 # Data models (S3 config, regions)
├── Services/               # Core services (upload, provider system, config, iCloud sync)
├── Resources/              # Assets, icons, and resources
```

### Dependencies
Mist is built with native macOS frameworks:
- Cocoa
- Foundation
- CloudKit (for iCloud sync)
- UniformTypeIdentifiers
- UserNotifications

## Troubleshooting

### Uploads Failing
- Verify your S3 credentials are correct
- Check bucket permissions (upload permission required)
- Ensure network connectivity
- Verify the bucket region matches your configuration
- For SM.MS, confirm your API token is valid

### iCloud Sync Not Working
- Confirm you're signed in to iCloud
- Check that iCloud Drive is enabled in System Preferences
- Verify network connection
- Try toggling iCloud Sync off and on

### Services Not Appearing
- Re-run `./scripts/install-service.sh`
- Open System Settings → Keyboard → Keyboard Shortcuts → Services and enable **Upload to Mist**
- Run `/System/Library/CoreServices/pbs -flush` then `killall Finder`

### URLs Not Copying to Clipboard
- Check System Preferences → Security & Privacy → Automation
- Ensure Mist has permission to control your Mac

## Roadmap

- [ ] Video upload support with preview generation
- [ ] FTP/SFTP protocol support
- [ ] Advanced image editing before upload
- [ ] Screenshot capture integration
- [ ] Custom keyboard shortcuts
- [ ] CLI tool for automation

## Contributing

Contributions are welcome! Please feel free to submit issues, fork the repository, and create pull requests.

### Guidelines
1. Fork the project
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'feat: add some amazing feature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with native macOS frameworks
- Inspired by the need for simple, efficient file sharing workflows
- Thanks to all contributors and users

## Contributors

<a href="https://github.com/missuo/mist/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=missuo/mist" alt="Contributors" />
</a>

## Support

- 🐛 Report bugs via [GitHub Issues](https://github.com/missuo/Mist/issues)
- 💬 Discuss features in [Discussions](https://github.com/missuo/Mist/discussions)
- ⭐ Star this repo if you find it useful!

---

<div align="center">
  Made with ❤️ by <a href="https://github.com/missuo">Vincent Yang</a>
</div>
