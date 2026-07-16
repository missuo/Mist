#!/bin/bash
# Package Mist.app for release: codesign, notarize, staple, zip, and build a DMG.
#
# Usage: package-app.sh <app-path> <output-zip> <output-dmg>
#
# Behavior is controlled by environment variables:
#   CODESIGN_IDENTITY                        Developer ID identity used for signing.
#                                            Falls back to ad-hoc signing when unset
#                                            (local builds without certificates).
#   APPLE_ID, APPLE_APP_PASSWORD,
#   APPLE_TEAM_ID                            When all set (and CODESIGN_IDENTITY is set),
#                                            the app and DMG are notarized and stapled.
#   SPARKLE_BIN, SPARKLE_PRIVATE_KEY_FILE    When both set, the output zip is signed with
#                                            Sparkle's sign_update and a <zip>.sparkle.json
#                                            metadata file is written for appcast generation.
set -euo pipefail

APP_PATH="$1"
OUTPUT_ZIP="$2"
OUTPUT_DMG="$3"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR/../.."

test -d "$APP_PATH"

# Apple's timestamp service is occasionally flaky; retry codesign a few
# times before giving up.
sign() {
  local attempt
  for attempt in 1 2 3; do
    if codesign "$@"; then
      return 0
    fi
    echo "codesign failed (attempt $attempt/3), retrying in 5s..." >&2
    sleep 5
  done
  return 1
}

if [ -n "${CODESIGN_IDENTITY:-}" ]; then
  echo "Signing with identity: $CODESIGN_IDENTITY"
  SIGN_FLAGS=(--force --options runtime --timestamp --sign "$CODESIGN_IDENTITY")

  # Sparkle's helper executables and XPC services live inside the framework
  # and must be signed individually before the framework bundle itself.
  SPARKLE_FW="$APP_PATH/Contents/Frameworks/Sparkle.framework"
  if [ -d "$SPARKLE_FW" ]; then
    sign "${SIGN_FLAGS[@]}" "$SPARKLE_FW/Versions/B/Autoupdate"
    sign "${SIGN_FLAGS[@]}" "$SPARKLE_FW/Versions/B/Updater.app"
    for xpc in "$SPARKLE_FW"/Versions/B/XPCServices/*.xpc; do
      [ -e "$xpc" ] || continue
      sign "${SIGN_FLAGS[@]}" --preserve-metadata=entitlements "$xpc"
    done
  fi

  # Sign nested code first (frameworks and dylibs, if any), then the outer bundle.
  # No entitlements: the app is not sandboxed, and the iCloud KVS entitlement
  # requires a Developer ID provisioning profile the CI build does not have —
  # signing with it but without a profile would make macOS refuse to launch
  # the app.
  while IFS= read -r -d '' nested; do
    sign "${SIGN_FLAGS[@]}" "$nested"
  done < <(find "$APP_PATH/Contents" -depth \( -name "*.dylib" -o -name "*.framework" \) -print0)

  # The Finder Sync extension must be sandboxed, so sign it with its
  # entitlements file (the unsigned CI build carries no entitlements to
  # preserve).
  FINDER_APPEX="$APP_PATH/Contents/PlugIns/MistFinder.appex"
  if [ -d "$FINDER_APPEX" ]; then
    sign "${SIGN_FLAGS[@]}" \
      --entitlements "$REPO_ROOT/MistFinder/MistFinder.entitlements" \
      "$FINDER_APPEX"
  fi

  sign "${SIGN_FLAGS[@]}" "$APP_PATH"
else
  echo "CODESIGN_IDENTITY not set; using ad-hoc signature"
  codesign --force --deep --sign - "$APP_PATH"
fi

codesign --verify --deep --strict --verbose=2 "$APP_PATH"

notarize() {
  local artifact="$1"
  echo "Submitting $artifact for notarization"
  local submit_json
  submit_json=$(xcrun notarytool submit "$artifact" \
    --apple-id "$APPLE_ID" \
    --password "$APPLE_APP_PASSWORD" \
    --team-id "$APPLE_TEAM_ID" \
    --wait --timeout 30m \
    --output-format json)
  echo "$submit_json"

  local submission_id status
  submission_id=$(echo "$submit_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')
  status=$(echo "$submit_json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["status"])')
  if [ "$status" != "Accepted" ]; then
    echo "Notarization failed with status: $status" >&2
    xcrun notarytool log "$submission_id" \
      --apple-id "$APPLE_ID" \
      --password "$APPLE_APP_PASSWORD" \
      --team-id "$APPLE_TEAM_ID" >&2 || true
    exit 1
  fi
}

HAVE_NOTARY_CREDS=0
if [ -n "${CODESIGN_IDENTITY:-}" ] && [ -n "${APPLE_ID:-}" ] && [ -n "${APPLE_APP_PASSWORD:-}" ] && [ -n "${APPLE_TEAM_ID:-}" ]; then
  HAVE_NOTARY_CREDS=1
fi

if [ "$HAVE_NOTARY_CREDS" = 1 ]; then
  NOTARIZE_ZIP="$(mktemp -d)/notarize.zip"
  ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$NOTARIZE_ZIP"
  notarize "$NOTARIZE_ZIP"
  rm -f "$NOTARIZE_ZIP"

  xcrun stapler staple "$APP_PATH"
  xcrun stapler validate "$APP_PATH"
  spctl --assess --type execute --verbose=2 "$APP_PATH"
elif [ -n "${CODESIGN_IDENTITY:-}" ]; then
  echo "Notarization credentials not set; skipping notarization" >&2
fi

# The Sparkle update zip contains the stapled app.
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$OUTPUT_ZIP"

# DMG for manual downloads.
rm -f "$OUTPUT_DMG"
hdiutil create -volname "Mist" -srcfolder "$APP_PATH" -ov -format UDZO "$OUTPUT_DMG"
if [ -n "${CODESIGN_IDENTITY:-}" ]; then
  sign --sign "$CODESIGN_IDENTITY" --timestamp "$OUTPUT_DMG"
fi
if [ "$HAVE_NOTARY_CREDS" = 1 ]; then
  notarize "$OUTPUT_DMG"
  xcrun stapler staple "$OUTPUT_DMG"
fi

if [ -n "${SPARKLE_BIN:-}" ] && [ -n "${SPARKLE_PRIVATE_KEY_FILE:-}" ]; then
  echo "Signing $OUTPUT_ZIP for Sparkle"
  SIGN_OUTPUT=$("$SPARKLE_BIN/sign_update" -f "$SPARKLE_PRIVATE_KEY_FILE" "$OUTPUT_ZIP")
  ED_SIGNATURE=$(printf '%s' "$SIGN_OUTPUT" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p')
  if [ -z "$ED_SIGNATURE" ]; then
    echo "ERROR: failed to extract sparkle:edSignature" >&2
    echo "$SIGN_OUTPUT" >&2
    exit 1
  fi

  ZIP_LENGTH=$(stat -f%z "$OUTPUT_ZIP")
  APP_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
  APP_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP_PATH/Contents/Info.plist")
  MIN_SYSTEM_VERSION=$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" "$APP_PATH/Contents/Info.plist")

  ED_SIGNATURE="$ED_SIGNATURE" ZIP_LENGTH="$ZIP_LENGTH" APP_VERSION="$APP_VERSION" \
  APP_BUILD="$APP_BUILD" MIN_SYSTEM_VERSION="$MIN_SYSTEM_VERSION" OUTPUT_ZIP="$OUTPUT_ZIP" \
  python3 - <<'PY'
import json, os
with open(os.environ["OUTPUT_ZIP"] + ".sparkle.json", "w") as f:
    json.dump({
        "signature": os.environ["ED_SIGNATURE"],
        "length": int(os.environ["ZIP_LENGTH"]),
        "version": os.environ["APP_VERSION"],
        "build": os.environ["APP_BUILD"],
        "minimum_system_version": os.environ["MIN_SYSTEM_VERSION"],
    }, f, indent=2)
PY
fi

echo "Packaged $OUTPUT_ZIP and $OUTPUT_DMG"
