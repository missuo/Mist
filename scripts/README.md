# Mist Scripts

## Build and Release

### `build_release.sh` — quick build

Fast unsigned Release build for local testing.

```bash
./scripts/build_release.sh
```

**Output**: `build/Build/Products/Release/Mist.app` (unsigned, local testing only)

### `sign_and_notarize.sh` — full signing and notarization

The complete production pipeline. It builds the app and then delegates to
`.github/scripts/package-app.sh`, the same script the release CI uses, so
local and CI releases are signed identically.

```bash
export APPLE_ID="your-email@example.com"
export APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"   # app-specific password
./scripts/sign_and_notarize.sh
```

**Steps**:
1. Build the Release configuration (unsigned)
2. Sign the app with the Developer ID certificate, including
   Sparkle.framework's internal components
3. Submit to Apple's notarization service and wait (typically 5–15 minutes)
4. Staple the notarization ticket
5. Create the Sparkle update ZIP and a signed, notarized DMG

**Output**:
- `build/Build/Products/Release/Mist.app` — signed and notarized app
- `build/Build/Products/Release/Mist.zip` — Sparkle update package
- `build/Build/Products/Release/Mist.dmg` — signed and notarized installer

> Releases are normally published by CI: push a `v*` tag and
> `.github/workflows/release.yml` does all of the above plus the GitHub
> Release and Sparkle appcast update. See [docs/signing.md](../docs/signing.md).

## Security Best Practices

Never commit passwords to Git. Use environment variables:

```bash
# In ~/.zshrc
export MIST_NOTARIZATION_PASSWORD="xxxx-xxxx-xxxx-xxxx"
```

or a Keychain profile (recommended):

```bash
# One-time setup
xcrun notarytool store-credentials "mist-notarization" \
    --apple-id "your-email@example.com" \
    --team-id "NCFNX3LJ83" \
    --password "xxxx-xxxx-xxxx-xxxx"

# Then submit with the stored credentials
xcrun notarytool submit app.zip --keychain-profile "mist-notarization" --wait
```

## Troubleshooting

```bash
# List available signing identities
security find-identity -v -p codesigning

# Inspect an app's signature
codesign -dv --verbose=4 build/Build/Products/Release/Mist.app

# Verify notarization / Gatekeeper acceptance
spctl --assess --type execute --verbose=4 build/Build/Products/Release/Mist.app

# Fetch a notarization log (ID comes from the submission output)
xcrun notarytool log <submission-id> \
    --apple-id "your-email@example.com" \
    --team-id "NCFNX3LJ83" \
    --password "xxxx-xxxx-xxxx-xxxx"
```

For the full signing and notarization guide, see
[docs/signing.md](../docs/signing.md).
