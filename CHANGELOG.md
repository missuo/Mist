# Changelog

All notable user-facing changes to Mist are documented here.

The release workflow embeds each release's section (matched by the `## <version>`
heading) into the Sparkle appcast, so it appears as formatted release notes in
the in-app update dialog.

## 1.0.14 - 2026-07-16

### Added

- Automatic updates via Sparkle: Mist now checks for new versions every 6 hours, and you can check manually with "Check for Updates..." in the menu bar.
- Releases are signed with a Developer ID certificate and notarized by Apple, so downloads open without Gatekeeper warnings.
- Finder extension: "Upload via Mist" now appears directly in Finder's right-click menu (enable MistFinder in System Settings → Extensions). This replaces the Automator-based Services integration, which lived one level deep in the Services submenu.
- Provider icons now show inside the provider dropdown and the menu bar Host submenu.

### Fixed

- Image compression is now truly off by default. Older builds stored a legacy compression value of 100, which silently re-encoded uploaded images (roughly 75% JPEG quality); that value is now treated as "off", so images upload untouched unless you explicitly pick a quality of 10-90 in Preferences.
