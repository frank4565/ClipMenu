# ClipMenu migrated feature test rerun report - 2026-06-17

## Summary

Test source: `doc/feature_test_cases.md`

Before rerun, the installed app at `/Applications/ClipMenu.app/Contents/MacOS/ClipMenu` was stopped. The migrated app was rebuilt and tested from:

```sh
.derivedData/Build/Products/Debug/ClipMenu.app
```

Overall result: **partial pass with blockers**. The migrated build launches as a menu-bar app, exposes a status item, captures text clipboard changes, opens Preferences and Snippet Editor, and renders long clipboard titles truncated in the menu. A clean full-suite run was still not possible because the app loaded the real existing ClipMenu history despite launching the process with a temporary `HOME`.

## Environment and Setup

- Date/timezone: 2026-06-17, Asia/Hong_Kong
- Installed app stopped: PID `86724` (`/Applications/ClipMenu.app/Contents/MacOS/ClipMenu`)
- Rebuild command:

```sh
xcodebuild -project ClipMenu.xcodeproj -scheme ClipMenu -configuration Debug -derivedDataPath .derivedData build
```

- Build result: `** BUILD SUCCEEDED **`
- Runtime command shape:

```sh
lldb --batch \
  -o 'settings set target.env-vars HOME=/tmp/clipmenu-rerun-home.b1l9Xj' \
  -o run \
  -o 'bt all' \
  -- .derivedData/Build/Products/Debug/ClipMenu.app/Contents/MacOS/ClipMenu
```

- Migrated runtime PID: `62696`
- Debug process was terminated after the run.

## Key Runtime Observations

| Area | Result | Evidence |
| --- | --- | --- |
| Installed app isolation | Pass | Process listing showed no `/Applications/ClipMenu.app/Contents/MacOS/ClipMenu` process after kill. |
| Build | Pass | `xcodebuild ... build` completed successfully. |
| Launch | Pass | System Events saw process `ClipMenu` with unix id `62696`, `background only = true`, `visible = false`, no windows, and two menu bars. |
| Status item | Pass | Status item found at `menu bar 2`, item 1, with help text `ClipMenu 0.4.4a13`. |
| First-run data isolation | Fail | Even with temporary `HOME=/tmp/clipmenu-rerun-home.b1l9Xj`, the app loaded the existing large ClipMenu history, including hundreds of prior items. |
| Clipboard capture | Pass | After dismissing the menu and waiting, `codex-unique-20260617-rerun` appeared as the newest history item. |
| Duplicate handling | Partial pass | Copy sequence `alpha`, `beta`, `gamma`, `alpha` resulted in `alpha`, `gamma`, `beta` near the top, with only one visible `alpha` among the new samples. Existing persisted history prevents a clean count across the full store. |
| Long title truncation | Pass | A 60-character numeric string appeared as `01234567890123456...`, consistent with the configured 20-character menu limit. |
| Menu grouping | Pass under existing settings | Existing history displayed inline items 1-20 and folder ranges `21 - 30`, `31 - 40`, etc. |
| Preferences window | Pass | Choosing `Preferences...` opened a window named `General`. |
| Snippet Editor | Pass | Choosing `Edit Snippets...` opened a window named `Snippet Editor`. |
| Quit menu item | Fail or debugger-blocked | Choosing `Quit ClipMenu` twice from the status menu did not terminate PID `62696`; it was stopped by PID afterward. Because the process was running under `lldb --batch`, this should be rechecked outside the debugger. |

Runtime logs also included:

- `linkd.autoShortcut` connection errors during app startup.
- `Unable to obtain a task name port right for pid 419`.
- Nib loading warnings:
  - `Failed to connect (actionTypeSegmentedControll) outlet from (ActionNodeController) to (NSSegmentedControl)`
  - `Failed to connect (delegate) outlet from (NSControl) to (PrefsWindowController)`
- Repeated `NSToolbarItem.minSize` / `maxSize` deprecation warnings when opening Preferences.

## Executed Test Case Results

| ID | Status | Notes |
| --- | --- | --- |
| CM-LAUNCH-001 | Pass | App runs as background-only `LSUIElement` style process, no main window, status item visible through accessibility. |
| CM-LAUNCH-002 | Blocked | Clean defaults could not be validated because the app still loaded existing ClipMenu state under temporary `HOME`. |
| CM-LAUNCH-003 | Fail / needs non-debug rerun | `Quit ClipMenu` menu item did not terminate the debug-run process after two attempts. |
| CM-LAUNCH-004 | Blocked | Persistence cannot be cleanly tested without isolated Application Support/defaults. |
| CM-HIST-001 | Pass | Unique plain text copied with `pbcopy` appeared in History. |
| CM-HIST-002 | Pass | New samples showed newest-first behavior for observed values. |
| CM-HIST-003 | Partial pass | Re-copying `alpha` moved it above `gamma` and `beta`, with one visible `alpha` among the new sample area. Full uniqueness cannot be guaranteed against existing persisted history. |
| CM-HIST-004 | Blocked | Max-history preference changes would affect existing real ClipMenu settings/state. |
| CM-HIST-005 | Blocked | Multiline sample was copied while the menu was open and did not produce a reliable observable result. Needs isolated rerun. |
| CM-HIST-006 | Pass | Long copied text was truncated with `...`; pasted-content preservation was not tested. |
| CM-HIST-007 | Not run | Requires controlled unsupported pasteboard data. |
| CM-HIST-008 | Not run | Requires changing excluded-app preferences. |
| CM-HIST-009 | Not run | Requires selecting/pasting older item into another app. |
| CM-HIST-010 | Not run | Requires changing reorder preference and selecting/pasting older item. |
| CM-PASTE-009 | Partial pass | Existing current settings showed inline history followed by range submenus. Configurable inline/folder-size behavior was not changed. |
| CM-PREF-001 | Pass | Preferences opened to `General`. |
| CM-SNIP-001 | Pass | Snippet Editor opened. |

## Section Status

| Section | Status | Reason |
| --- | --- | --- |
| Launch and lifecycle | Partial | Launch passed; quit via menu did not terminate under debugger; clean first-run/persistence blocked by real state loading. |
| Clipboard history | Partial | Plain text capture, ordering, duplicate move, long-title truncation, and existing foldered menu were observed. Clean trimming/multiline/unsupported/excluded-app tests remain blocked or not run. |
| Paste and menu operation | Mostly not run | Selecting clips and synthesizing paste would affect the active user session; not run without a disposable account/target app. |
| Pasteboard types and rendering | Not run | Requires controlled RTF/PDF/file/image fixtures and preference changes. |
| Snippets | Partial | Editor opens. Add/edit/import/export/paste tests were not run because storage isolation failed. |
| Actions | Not run | Requires invoking action menus and mutating pasteboard/target app state. |
| Preferences | Partial | Preferences opens. Preference mutation tests were skipped to avoid modifying real settings. |
| Migration data checks | Not run | Requires controlled legacy fixture files and isolated defaults/app-support paths. |
| Non-regression expectations | Not run | Requires broader malformed-data and error-dialog scenarios in an isolated profile. |

## Blockers Remaining

1. **Application Support/defaults isolation is still unresolved.** The temporary `HOME` did not prevent the migrated process from loading existing ClipMenu history.
2. **Running under `lldb` may affect quit behavior.** Direct sandbox launch aborts, while approved debugger launch runs; `Quit ClipMenu` should be retested using a normal GUI launch in a controlled account.
3. **Stateful feature cases remain risky in this user account.** Tests that clear history, edit snippets/actions, change hotkeys, toggle login items, or alter update settings should be run only in a clean macOS test account or VM snapshot.

## Recommended Next Run

- Use a separate macOS test account or VM snapshot.
- Ensure no installed ClipMenu is running.
- Remove/reset only the test account's ClipMenu support files and defaults.
- Launch the migrated app normally, not under `lldb`, if the environment permits.
- Then run the full `doc/feature_test_cases.md` suite, including destructive/history-clearing and preference mutation cases.
