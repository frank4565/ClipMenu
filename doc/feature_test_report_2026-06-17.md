# ClipMenu migrated feature test report - 2026-06-17

## Summary

Test source: `doc/feature_test_cases.md`

Build under test: `.derivedData/Build/Products/Debug/ClipMenu.app`, rebuilt from the current checkout with:

```sh
xcodebuild -project ClipMenu.xcodeproj -scheme ClipMenu -configuration Debug -derivedDataPath .derivedData build
```

Result: **build passed**, but the full manual acceptance suite was **not completed**. The migrated app can be launched under an approved GUI/debug context, but black-box UI automation by process name intersected with an already-running installed ClipMenu instance and exposed/modified live user history. Testing was stopped to avoid further state changes.

## Environment

- Date/timezone: 2026-06-17, Asia/Hong_Kong
- Host: macOS with Xcode 17.0-era toolchain (`DTXcode` 17F42 in built app plist)
- Built bundle id: `com.naotaka.ClipMenu`
- Built app path: `.derivedData/Build/Products/Debug/ClipMenu.app`
- Existing installed app detected: `/Applications/ClipMenu.app/Contents/MacOS/ClipMenu`

## Commands and Observations

| Area | Result | Evidence |
| --- | --- | --- |
| Build | Pass | `xcodebuild ... build` completed with `** BUILD SUCCEEDED **`. Warnings included unsupported traditional headermap style and bundle identifier mismatch against empty `PRODUCT_BUNDLE_IDENTIFIER`. |
| Project discovery | Pass | `xcodebuild -list -project ClipMenu.xcodeproj` reported target and scheme `ClipMenu`. |
| Direct sandbox launch | Blocked | Running `.derivedData/.../ClipMenu.app/Contents/MacOS/ClipMenu` inside the managed sandbox aborted immediately with `Program crashed: Signal 6`. |
| Approved debugger launch | Pass | `lldb --batch ... run` launched the debug app and it stayed alive until explicitly terminated. Runtime logs included `linkd.autoShortcut` connection errors and one AppKit layout recursion warning. |
| App type | Pass | Built `Info.plist` contains `LSUIElement = 1`; System Events reported the process as `background only = true`, `visible = false`, and with no windows. |
| Status item | Pass | System Events found a ClipMenu status item at `menu bar 2`, item 1, with help text `ClipMenu 0.4.3`. |
| Clipboard stimulus | Partial | `printf 'alpha' \| pbcopy` succeeded only with approval. Opening the ClipMenu menu later showed `1. alpha` at the top of history. |
| Test isolation | Fail | Attempting to run the debug app with `HOME=/tmp/clipmenu-test-home.sJoMlu` did not provide reliable isolation for UI automation. The active installed ClipMenu process was also present, and `tell process "ClipMenu"` could target live user state. |

## Executed Test Case Results

| ID | Status | Notes |
| --- | --- | --- |
| CM-LAUNCH-001 | Partial pass | Verified no Dock-style foreground UI/main window and verified a status item exists. The exact menu-bar visual state was observed through accessibility, not screenshots. |
| CM-LAUNCH-002 | Not run | Clean-default first-run login prompt was not safely validated because isolation was unreliable and a live installed ClipMenu instance was present. |
| CM-LAUNCH-003 | Not run | Quit via menu was not exercised to avoid triggering save paths against live history. Debug instances were terminated by PID. |
| CM-LAUNCH-004 | Not run | Persistence testing was skipped after isolation failure. |
| CM-HIST-001 | Partial pass | `alpha` appeared as the first menu history item after `pbcopy`. Because the active installed app was also running, this cannot be attributed cleanly to only the migrated debug build. |

## Suite Status by Section

| Section | Status | Reason |
| --- | --- | --- |
| Clipboard history | Blocked after CM-HIST-001 partial | Stateful history tests require an isolated app profile and unambiguous target process. |
| Paste and menu operation | Not run | Would require selecting menu items, synthesizing paste, and changing preferences against live UI. |
| Pasteboard types and rendering | Not run | Requires safe pasteboard/image/file fixtures and menu/UI inspection in isolated state. |
| Snippets | Not run | Requires editing persisted snippet storage; skipped to avoid live user data changes. |
| Actions | Not run | Requires invoking modified-click/action menus and pasteboard mutation; skipped after process ambiguity. |
| Preferences | Not run | Requires changing persisted defaults/login item/update settings; skipped after isolation failure. |
| Migration data checks | Not run | Requires controlled legacy fixtures in Application Support and defaults domains. |
| Non-regression expectations | Not run | Requires exercising malformed pasteboard data, excluded apps, menu rebuilds, and error dialogs in isolation. |

## Blocking Issues for Completing the Suite

1. **Process ambiguity:** An installed `/Applications/ClipMenu.app` was already running with the same process name and bundle id as the debug build. AppleScript commands such as `tell process "ClipMenu"` are not safe enough to target only the migrated build.
2. **Profile isolation was incomplete:** Launching under `HOME=/tmp/clipmenu-test-home.sJoMlu` did not prevent interaction with existing ClipMenu UI/state during automation.
3. **Sandbox restrictions:** Direct launch, pasteboard writes, process listing, unified log access, and System Events inspection required elevated execution. Direct sandbox launch aborts with Signal 6, while approved debugger launch stays alive.
4. **Live user-state contamination:** The test pasteboard value `alpha` appeared in ClipMenu history while the installed app was running. No cleanup was attempted to avoid further unintended mutation.

## Recommended Next Test Setup

- Quit the installed `/Applications/ClipMenu.app` before testing.
- Use a distinct bundle identifier/product name for the migrated test build, or automate by PID/accessibility object rather than process name.
- Run in a clean macOS test account or VM snapshot.
- Reset only the test account's ClipMenu files and defaults before the suite:
  - `~/Library/Application Support/ClipMenu/clips.data`
  - `~/Library/Application Support/ClipMenu/Snippets.xml`
  - `~/Library/Application Support/ClipMenu/actions.plist`
  - defaults domain `com.naotaka.ClipMenu`
- Re-run the full matrix from `doc/feature_test_cases.md` after isolation is confirmed.
