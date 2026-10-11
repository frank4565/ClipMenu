# Snippet editor appearance — 2026-10-11

The folder sidebar used a fixed pale blue background while folder labels
followed the system appearance. This left light text on a light sidebar in dark
mode, including in the first Swift release's README screenshot.

The sidebar now uses the semantic macOS window background color. The Groups
heading and empty-library labels also use semantic foreground colors, and the
custom Groups heading redraws when its effective appearance changes. No
localized strings changed.

Validation:

- Debug `xcodebuild` succeeded without compiler warnings or errors.
- Actual native editor inspection passed in dark appearance and in a separate
  QA app forced to light appearance. Both used isolated bundle identifiers,
  preference domains, support directories, and synthetic snippet libraries.
- Folder names, the Groups heading, selected snippet rows, and content text
  remained readable with a populated library in both appearances.
- Empty-library inspection passed in both appearances: the No Folders and No
  Snippet Selected titles, icons, and explanatory text remained readable.
- The README snippet-editor screenshot was recaptured from the corrected
  native dark editor with synthetic Templates and Development folders.
- All four README screenshots were exported to RGBA PNG with transparent
  exterior corners and smooth window edges. Screenshot pixels outside the
  corner regions were checked against the original captures and remain exact.
- Source review confirmed the APIs remain compatible with the macOS 12 target.
  The development machine supplied the native appearance checks; macOS 12 and
  a live system appearance transition were not separately exercised.
- Release readiness: the Debug build passed again after updating the project to
  0.5.1 (build 6.1.99), without compiler warnings or errors. All 27 release-helper
  tests passed, including the round trip with the pinned official Sparkle signer.

Build log: `build/snippet-appearance-debug-build.log`.
0.5.1 readiness build log: `build/release-v0.5.1-debug-build.log`.
Native QA captures: `build/snippet-appearance-qa/{dark,light}-{populated,empty}.png`.
README capture: `doc/screenshots/snippet-editor.png`.
