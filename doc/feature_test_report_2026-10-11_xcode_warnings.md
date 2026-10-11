# Xcode warning cleanup verification — 2026-10-11

Environment: macOS 26.7 (25G229), Apple Silicon, Xcode 27.0 (27A266a).

## Changes

- Replaced deprecated `NSWorkspace.icon(forFileType:)` calls with content-type
  icon lookups. Shared helpers resolve legacy four-character HFS codes,
  filename extensions, declared/dynamic UTIs, and quoted HFS preference values.
- Replaced the deprecated source-list selection setting with
  `NSTableView.style = .sourceList` in the snippet folder browser.
- Skipped unused App Intents metadata extraction with
  `LM_SKIP_METADATA_EXTRACTION = YES`. No target defines App Intents.
- Set `COPY_PHASE_STRIP = NO` for both app targets' Release configurations.
  This preserves Sparkle's signed embedded binaries. The separate `Strip`
  task still processes ClipMenu's Release executable.
- Set both test targets' minimum macOS version to 14.0, matching the installed
  XCTest, XCTest Swift support, and XCUIAutomation binaries. Application
  targets have a minimum macOS version of 12.0.

## Results

The initial clean Debug build emitted 25 deprecation warnings and one unused
App Intents metadata warning. Release verification exposed five signed-binary
copy warnings; test verification exposed five XCTest deployment-version linker
warnings. All were resolved through API or build-setting changes.

| Check | Result |
| --- | --- |
| Clean `ClipMenu` Debug build | Passed, zero warnings |
| Clean `ClipMenu` Release build | Passed, zero warnings; arm64 and x86_64 |
| Clean `ClipMenu (deployment)` Release build | Passed, zero warnings; arm64 and x86_64 |
| `ClipMenuTests`, Testing configuration | 66 passed, zero failures; build emitted zero warnings |
| Project plist and `git diff --check` | Passed |

Builds used `-derivedDataPath .derivedData-warning-cleanup`. Tests used
`-configuration Testing -destination 'platform=macOS,arch=arm64'
-only-testing:ClipMenuTests`, with temporary DerivedData at
`/private/tmp/clipmenu-warning-tests` and the previously verified Sparkle cache
at `/private/tmp/clipmenu-sparkle-validation/SourcePackages`.

Build and test logs are in `/private/tmp/clipmenu-warnings-{debug,release,deployment,tests}.log`.

## Icon and native UI verification

- A native scratch probe compared old and new icon rendering at 32 pixels.
  Rendered pixel hashes matched for `TEXT`, `fold`, `ofld`, `clpt`, `clpu`,
  `gurl`, `PDF `, and an arbitrary `ABCD` HFS code.
- Three new unit tests independently verify known HFS mappings, arbitrary HFS
  metadata on an actual temporary file, and extension/UTI/quoted-HFS preferences.
- A native outline-view fixture applied the repository's row metrics and
  compared both source-list APIs. Row/header geometry, 20-point rows,
  14-point indentation, icon/text frames, and selection state matched.
  Aqua and Dark Aqua images were byte-identical for both inactive and
  emphasized selection. Probe results and images are under
  `/private/tmp/clipmenu-outline-*`.

No visible strings changed, so localization updates were unnecessary.
