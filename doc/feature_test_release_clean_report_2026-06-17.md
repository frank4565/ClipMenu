# ClipMenu Release clean-history feature test report - 2026-06-17

## Summary

Test source: `doc/feature_test_cases.md`

Build under test:

```sh
.derivedData/Build/Products/Release/ClipMenu.app
```

Overall result: **stronger partial pass**. This run used a normal Release launch instead of `lldb`, stopped all existing ClipMenu processes first, backed up and removed the existing `clips.data`, and used ClipMenu's own `Clear History` command to clean in-memory history before exercising clipboard-history cases.

The Release app passed launch/status-item checks, clean history clearing, plain text capture, newest-first ordering, duplicate promotion, max-history trimming, multiline menu-title rendering, long-title truncation, Preferences opening, and Snippet Editor opening. The main observed failure is that `Quit ClipMenu` did not terminate the Release process.

## Setup

- Date/timezone: 2026-06-17, Asia/Hong_Kong
- Existing ClipMenu processes: none running before Release launch.
- History backup created:

```sh
/tmp/clipmenu-release-test-backup-20260617/clips.data.backup
```

- Live history removed before launch:

```sh
~/Library/Application Support/ClipMenu/clips.data
```

- History restored after test. Restored file size: `327M`.
- Original `maxHistorySize` restored after test: `999`.

Release build command:

```sh
xcodebuild -project ClipMenu.xcodeproj -scheme ClipMenu -configuration Release -derivedDataPath .derivedData build
```

Build result: `** BUILD SUCCEEDED **`

Build notes:

- Xcode reported static analyzer issues in:
  - `Source/DBPrefsWindowController/DBPrefsWindowController.m`
  - `Source/FolderNode.m`
  - `Source/ScriptableClip.m`
- Xcode repeated the warning about traditional headermap style.

Launch command:

```sh
open -n .derivedData/Build/Products/Release/ClipMenu.app
```

Release runtime PID: `30124`

## Key Observations

| Area | Result | Evidence |
| --- | --- | --- |
| Release build | Pass | Release configuration built successfully. |
| Normal launch | Pass | App launched normally with `open -n`; no debugger was used. |
| Menu-bar app behavior | Pass | System Events reported PID `30124`, `background only = true`, `visible = false`, no windows, and two menu bars. |
| Status item | Pass | Release status item was accessible from menu bar 2. |
| Initial clean history | Partial | Removing `clips.data` prevented legacy history from loading, but the app immediately captured the current system pasteboard on launch. |
| Clear History | Pass | `Clear History` removed the launch-captured item; menu then showed an empty History section and Clear History became disabled-looking/empty of items. |
| Plain text capture | Pass | Copied text appeared in History. |
| Ordering | Pass | New copied samples appeared newest first. |
| Duplicate handling | Pass | Copying `alpha`, `beta`, `gamma`, then `alpha` showed one `alpha`, moved above `gamma` and `beta`. |
| Multiline title | Pass | `line one\nline two` appeared as `line one` in the menu. Paste preservation was not tested. |
| Long title truncation | Pass | A 60-character numeric string appeared as `01234567890123456...`. |
| Max history trimming | Pass | With `maxHistorySize = 3`, copying five unique values left only `five`, `four`, and `three`. |
| Preferences | Pass | `Preferences...` opened a window named `General`. |
| Snippet Editor | Pass | `Edit Snippets...` opened a window named `Snippet Editor`. |
| Quit | Fail | `Quit ClipMenu` did not terminate PID `30124` after the menu item was selected. The process was stopped by PID after recording the failure. |

## Executed Test Case Results

| ID | Status | Notes |
| --- | --- | --- |
| CM-LAUNCH-001 | Pass | Release app starts as a background menu-bar app with status item and no main window. |
| CM-LAUNCH-002 | Not run | First-run login prompt was not tested because existing preferences were intentionally preserved. |
| CM-LAUNCH-003 | Fail | `Quit ClipMenu` menu item did not terminate the normally launched Release process. |
| CM-LAUNCH-004 | Not run | Relaunch persistence was not tested; original history was restored after the run. |
| CM-HIST-001 | Pass | Plain text capture worked. |
| CM-HIST-002 | Pass | Multiple items displayed newest first. |
| CM-HIST-003 | Pass | Duplicate `alpha` moved to newest position without showing a second `alpha`. |
| CM-HIST-004 | Pass | Temporarily setting max history to 3 trimmed five copied values to the three newest. |
| CM-HIST-005 | Pass | Multiline menu title showed only first line. |
| CM-HIST-006 | Pass | Long title was truncated with `...`. |
| CM-HIST-007 | Not run | Unsupported/disabled pasteboard type was not exercised. |
| CM-HIST-008 | Not run | Excluded-app behavior was not exercised. |
| CM-HIST-009 | Not run | Reorder-after-pasting enabled behavior was not exercised. |
| CM-HIST-010 | Not run | Reorder-after-pasting disabled behavior was not exercised. |
| CM-PASTE-010 | Pass | Clear History menu item removed all current history items after confirmation. |
| CM-PREF-001 | Pass | Preferences opened to `General`. |
| CM-SNIP-001 | Pass | Snippet Editor opened. |

## Not Run

The following sections remain largely untested in this run:

- Paste behavior into another app.
- Hotkeys.
- Pasteboard type-specific rendering for RTF, PDF, filenames, URLs, and images.
- Snippet add/edit/reorder/import/export/paste behavior.
- Built-in and JavaScript actions.
- Preference mutation beyond the temporary `maxHistorySize` change.
- Migration fixtures for legacy snippets/actions/scripts/defaults.
- Error dialogs and malformed data non-regression cases.

## Cleanup

- Release test process PID `30124` was killed after `Quit ClipMenu` failed.
- Original `clips.data` was restored from `/tmp/clipmenu-release-test-backup-20260617/clips.data.backup`.
- `maxHistorySize` was restored to `999`.
- Final process check found no running `ClipMenu.app/Contents/MacOS/ClipMenu` processes.
