# Mist App Signing and Notarization Guide

## Overview

To distribute Mist.app on macOS outside the App Store, you need to:
1. Sign it with a **Developer ID Application** certificate
2. Have Apple verify it through **notarization**
3. **Staple** the notarization ticket to the app

## Automated Release (GitHub Actions, recommended)

Pushing a `v*` tag runs `.github/workflows/release.yml`, which handles the whole
process:

1. Imports the Developer ID certificate into a temporary keychain
2. Builds the Release configuration
3. Runs `.github/scripts/package-app.sh` to sign (including Sparkle.framework's
   internal components), notarize, and staple
4. Produces `Mist.zip` (for Sparkle updates) and `Mist.dmg` (for manual
   downloads) and uploads both to the GitHub Release
5. Signs the zip with Sparkle's `sign_update` (EdDSA) and commits the new
   version entry to `docs/appcast.xml` on main, embedding the release's
   `CHANGELOG.md` section as the release notes shown in the update dialog

To publish a release:

```bash
# 1. Bump MARKETING_VERSION and CURRENT_PROJECT_VERSION in Xcode
# 2. Add a "## <version>" section to CHANGELOG.md (shown in the update dialog)
# 3. Commit, then:
git tag v1.0.14
git push origin v1.0.14
```

> **Note**: `CURRENT_PROJECT_VERSION` (CFBundleVersion) must be incremented for
> every release — Sparkle uses it to decide whether an update is available.
> If a version has no `CHANGELOG.md` section, the update dialog falls back to
> a link to the GitHub release notes.

### Required GitHub Secrets (same fields as the koe repository)

| Secret | Description |
|---|---|
| `MACOS_CERTIFICATE_P12` | Developer ID Application certificate (base64-encoded .p12) |
| `MACOS_CERTIFICATE_PASSWORD` | Password for the .p12 |
| `APPLE_ID` | Apple Developer account email |
| `APPLE_APP_PASSWORD` | App-specific password (for notarytool) |
| `APPLE_TEAM_ID` | Developer team ID (`NCFNX3LJ83`) |
| `SPARKLE_ED25519_PUBLIC_KEY` | Sparkle update signing public key (injected into Info.plist at CI build time) |
| `SPARKLE_ED25519_PRIVATE_KEY` | Sparkle update signing private key (contents exported via `generate_keys -x`) |

## Sparkle Automatic Updates

The app embeds [Sparkle](https://sparkle-project.org) (SPM dependency). It
checks for updates every 6 hours automatically, and users can also trigger a
check from the "Check for Updates..." menu item.

- Feed URL (`SUFeedURL`): `https://raw.githubusercontent.com/missuo/Mist/main/docs/appcast.xml`
- EdDSA public key (`SUPublicEDKey`): `Mist/Info.plist` contains the public key
  matching the private key in the local Keychain (convenient for local
  debugging); CI overwrites it with the `SPARKLE_ED25519_PUBLIC_KEY` secret so
  it always matches `SPARKLE_ED25519_PRIVATE_KEY`
- The appcast is maintained automatically by the release workflow's `appcast`
  job — do not edit `docs/appcast.xml` by hand

To export/import the Sparkle private key on another machine:

```bash
# Get the tools from a Sparkle release: https://github.com/sparkle-project/Sparkle/releases
./bin/generate_keys -x sparkle_ed25519.key   # export
./bin/generate_keys -f sparkle_ed25519.key   # import
```

## Prerequisites

### 1. Developer Certificate

Make sure you have a **Developer ID Application** certificate:

```bash
# List available signing identities
security find-identity -v -p codesigning
```

You should see output like:
```
1) ABC123... "Developer ID Application: Your Name (YOUR_TEAM_ID)"
```

If not, create one at [Apple Developer](https://developer.apple.com/account/resources/certificates/list).

### 2. App-Specific Password

`notarytool` requires an app-specific password:

1. Go to [appleid.apple.com](https://appleid.apple.com)
2. Sign in with your Apple ID
3. Under "Security", click "App-Specific Passwords"
4. Click "Generate Password" and enter a name (e.g. "Mist Notarization")
5. Save the generated password (format: xxxx-xxxx-xxxx-xxxx)

### 3. Configuration

Record the following:
- **Apple ID**: your Apple Developer account email
- **Team ID**: `NCFNX3LJ83` (already configured in the Xcode project)
- **Developer ID**: the full certificate name from step 1
- **App Password**: the app-specific password from step 2

## Option 1: Local Automated Script

```bash
export APPLE_ID="your-email@example.com"
export APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"
./scripts/sign_and_notarize.sh
```

The script handles:
- ✓ Building the Release configuration
- ✓ Signing the app (including Sparkle.framework's internal components, using
  the same logic as CI)
- ✓ Submitting for notarization and stapling the ticket
- ✓ Creating a signed and notarized ZIP and DMG

Afterwards you get:
- `build/Build/Products/Release/Mist.app` - signed and notarized app
- `build/Build/Products/Release/Mist.zip` - Sparkle update package
- `build/Build/Products/Release/Mist.dmg` - signed and notarized installer

## Option 2: Manual Steps

### Step 1: Build the Release configuration

```bash
xcodebuild clean build \
    -project Mist.xcodeproj \
    -scheme Mist \
    -configuration Release \
    -derivedDataPath build \
    CODE_SIGNING_ALLOWED=NO
```

### Step 2: Sign the app

Normally `.github/scripts/package-app.sh` does all of this. By hand:

```bash
# Sign Sparkle's helpers first, then the framework, then the main app
codesign --force --options runtime --timestamp \
    --sign "Developer ID Application: Your Name (TEAM_ID)" \
    "build/Build/Products/Release/Mist.app/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate"
codesign --force --options runtime --timestamp \
    --sign "Developer ID Application: Your Name (TEAM_ID)" \
    "build/Build/Products/Release/Mist.app/Contents/Frameworks/Sparkle.framework/Versions/B/Updater.app"
for xpc in "build/Build/Products/Release/Mist.app/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/"*.xpc; do
  codesign --force --options runtime --timestamp --preserve-metadata=entitlements \
      --sign "Developer ID Application: Your Name (TEAM_ID)" "$xpc"
done
codesign --force --options runtime --timestamp \
    --sign "Developer ID Application: Your Name (TEAM_ID)" \
    "build/Build/Products/Release/Mist.app/Contents/Frameworks/Sparkle.framework"

# Then the main app
codesign --force --options runtime --timestamp \
    --sign "Developer ID Application: Your Name (TEAM_ID)" \
    "build/Build/Products/Release/Mist.app"

# Verify the signature
codesign --verify --deep --strict --verbose=2 "build/Build/Products/Release/Mist.app"
```

### Step 3: Create a ZIP for notarization

```bash
cd build/Build/Products/Release
ditto -c -k --sequesterRsrc --keepParent Mist.app Mist.zip
cd -
```

### Step 4: Submit for notarization

```bash
xcrun notarytool submit build/Build/Products/Release/Mist.zip \
    --apple-id "your-email@example.com" \
    --team-id "NCFNX3LJ83" \
    --password "xxxx-xxxx-xxxx-xxxx" \
    --wait
```

This outputs something like:
```
Submission ID received
  id: 12345678-1234-1234-1234-123456789012
Successfully uploaded file
  id: 12345678-1234-1234-1234-123456789012
  path: build/Build/Products/Release/Mist.zip
Waiting for processing to complete...
Current status: Accepted
```

### Step 5: Staple the notarization ticket

```bash
xcrun stapler staple "build/Build/Products/Release/Mist.app"
```

### Step 6: Verify

```bash
spctl --assess --type execute --verbose=4 "build/Build/Products/Release/Mist.app"
```

You should see:
```
build/Build/Products/Release/Mist.app: accepted
source=Notarized Developer ID
```

### Step 7: Create a DMG (optional)

```bash
# Create the DMG
hdiutil create -volname "Mist" \
    -srcfolder "build/Build/Products/Release/Mist.app" \
    -ov -format UDZO \
    "build/Build/Products/Release/Mist.dmg"

# Sign the DMG
codesign --sign "Developer ID Application: Your Name (TEAM_ID)" \
    --timestamp \
    "build/Build/Products/Release/Mist.dmg"

# Notarize the DMG
xcrun notarytool submit "build/Build/Products/Release/Mist.dmg" \
    --apple-id "your-email@example.com" \
    --team-id "NCFNX3LJ83" \
    --password "xxxx-xxxx-xxxx-xxxx" \
    --wait

# Staple the DMG
xcrun stapler staple "build/Build/Products/Release/Mist.dmg"

# Verify the DMG
spctl --assess --type open --context context:primary-signature \
    --verbose=4 "build/Build/Products/Release/Mist.dmg"
```

## Troubleshooting

### 1. "The application cannot be opened"

**Cause**: the app is not correctly signed or notarized.

**Fix**:
- Make sure `--options runtime` was used
- Make sure notarization succeeded and the ticket was stapled
- Run the verification commands to check the status

### 2. Notarization fails

**Cause**: missing Hardened Runtime or other issues.

**Fix**:
```bash
# View the detailed notarization log
xcrun notarytool log <submission-id> \
    --apple-id "your-email@example.com" \
    --team-id "NCFNX3LJ83" \
    --password "xxxx-xxxx-xxxx-xxxx"
```

### 3. Entitlements

Distribution builds are signed **without** an entitlements file: the app is not
sandboxed, and the iCloud KVS entitlement in `Mist/Mist.entitlements` requires
a Developer ID provisioning profile — signing with it but without a profile
would make macOS refuse to launch the app.

### 4. Inspect signature details

```bash
# View signing information
codesign -dv --verbose=4 "build/Build/Products/Release/Mist.app"

# View all signed components
codesign -dv --deep "build/Build/Products/Release/Mist.app"

# View entitlements
codesign -d --entitlements - "build/Build/Products/Release/Mist.app"
```

## Distributing to Users

Once signed and notarized, you can:

1. **Distribute the .app directly**
   - Compress it into a ZIP
   - Users can unzip and run it directly

2. **Distribute the DMG** (recommended)
   - More polished install experience
   - Users drag the app to the Applications folder

3. **Via GitHub Releases**
   - The release workflow uploads the DMG and ZIP automatically
   - Users can download and run without warnings, and existing installs
     update themselves through Sparkle

## Security Notes

⚠️ **Never commit the app-specific password to Git**

Use environment variables or the Keychain:

```bash
# Option 1: environment variable
export APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"

# Option 2: store in the Keychain
xcrun notarytool store-credentials "mist-notarization" \
    --apple-id "your-email@example.com" \
    --team-id "NCFNX3LJ83" \
    --password "xxxx-xxxx-xxxx-xxxx"

# Then use the stored credentials
xcrun notarytool submit app.zip --keychain-profile "mist-notarization" --wait
```

## References

- [Apple Developer: Notarizing macOS Software](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [Customizing the Notarization Workflow](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution/customizing_the_notarization_workflow)
- [Code Signing Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/Introduction/Introduction.html)
- [Sparkle Documentation](https://sparkle-project.org/documentation/)
