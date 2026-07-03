# ClipMenu SwiftUI native feature test report - 2026-06-17

## Summary

Test source: `doc/feature_test_cases.md`

Build under test:

```sh
.derivedData/Build/Products/Release/ClipMenu.app
```

Overall result: **partial pass**. The Release app built successfully and passed the exercised launch, status item, clipboard history, max-history trimming, SwiftUI Preferences, SwiftUI Snippet Editor, and quit checks.

This was not a full matrix run. Paste into another app, hotkeys, pasteboard type variants, action execution, snippet editing/paste, import/export, and migration fixture tests were not run.

## Setup

- Date/timezone: 2026-06-17, Asia/Hong_Kong
- Existing ClipMenu processes before launch: none
- Existing history backup:

```sh
/tmp/clipmenu-feature-test-backup-20260617-102736/clips.data.backup
```

- Original history was restored after the run.
- Original `maxHistorySize` was restored after the run: `999`

Release build command:

```sh
xcodebuild -project ClipMenu.xcodeproj -scheme ClipMenu -configuration Release -derivedDataPath .derivedData build
```

Build result: `** BUILD SUCCEEDED **`

Launch command:

```sh
open -n .derivedData/Build/Products/Release/ClipMenu.app
```

Release runtime PID: `74431`

## Results

| ID | Status | Evidence |
| --- | --- | --- |
| CM-LAUNCH-001 | Pass | System Events reported `ClipMenu`, `background only = true`, `visible = false`, `windows = 0`, `menubars = 2`, status help `ClipMenu 0.4.4a13`. |
| CM-LAUNCH-003 | Pass | Selecting `Quit ClipMenu` exited PID `74431`. |
| CM-HIST-001 | Pass | Copying `alpha` showed `1. alpha` in History. |
| CM-HIST-002 | Pass | Copying `alpha`, `beta`, `gamma` showed newest-first ordering. |
| CM-HIST-003 | Pass | Re-copying `alpha` moved it above `gamma` and `beta` without a duplicate visible in the new sample set. |
| CM-HIST-004 | Pass | Temporarily setting `maxHistorySize = 3` and copying `one` through `five` left `five`, `four`, and `three`. |
| CM-HIST-005 | Pass | Copying `line one\\nline two` showed `line one` as the menu title. |
| CM-HIST-006 | Pass | Copying a 60-character numeric string showed `01234567890123456...`. |
| CM-PASTE-010 | Pass | `Clear History` was invoked before the history checks to clear launch-captured clipboard state. |
| CM-PREF-001 | Pass | `Preferences...` opened a window named `General`, backed by the new SwiftUI preferences host. |
| CM-SNIP-001 | Pass | `Edit Snippets...` opened a window named `Snippet Editor`, backed by the new SwiftUI snippet editor host. |

## Raw Observations

```text
history_after_alpha_beta_gamma_alpha=SnippetsFavouritemissing valueHistory1. alpha2. gamma3. betamissing valueClear HistoryEdit Snippets...Preferences...missing valueQuit ClipMenu
history_after_multiline_long=SnippetsFavouritemissing valueHistory1. 01234567890123456...2. line one3. alpha4. gamma5. betamissing valueClear HistoryEdit Snippets...Preferences...missing valueQuit ClipMenu
history_after_max3=SnippetsFavouritemissing valueHistory1. five2. four3. threemissing valueClear HistoryEdit Snippets...Preferences...missing valueQuit ClipMenu
preferences_windows=General
snippet_windows=Snippet Editor
quit_result=PASS exited
```

## Not Run

- First-run login prompt with clean defaults.
- Relaunch persistence.
- Paste into another foreground app.
- Global hotkeys.
- RTF/PDF/file/URL/image pasteboard type rendering.
- Snippet add/edit/reorder/import/export/paste.
- Built-in and JavaScript action execution.
- Login item, update, hotkey, action-tree, and export preferences.
- Migration fixture checks for existing snippets, actions, scripts, and defaults.

## Cleanup

- Test process exited through `Quit ClipMenu`.
- Original `clips.data` was restored from backup.
- Original `maxHistorySize` was restored.
- Final process check found no running `ClipMenu.app/Contents/MacOS/ClipMenu` processes.
