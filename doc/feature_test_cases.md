# ClipMenu feature test cases

These cases define acceptance coverage for validating a migrated ClipMenu implementation against the current macOS app. They were derived from launching `/Applications/ClipMenu.app` and inspecting the app controllers, preferences, bundled scripts, and localized UI.

## Scope

ClipMenu is a menu-bar clipboard manager. The migrated app should preserve:

- Clipboard history capture, deduplication, ordering, type filtering, and persistence.
- Menu-bar access, global hotkeys, menu formatting, paste behavior, and clear history behavior.
- Snippet folders, snippets, enablement, ordering, import/export, and snippet paste.
- Built-in and JavaScript actions, including modified-click action behavior.
- Preferences for general operation, menu layout, stored pasteboard types, actions, snippets, updates, and login item behavior.

## Test data

Use a clean macOS test account or reset these files before a clean-run suite:

- `~/Library/Application Support/ClipMenu/clips.data`
- `~/Library/Application Support/ClipMenu/Snippets.xml`
- `~/Library/Application Support/ClipMenu/actions.plist`
- User defaults for bundle id `com.naotaka.ClipMenu`

Suggested sample content:

- Plain text: `alpha`, `beta`, `gamma`, `  padded text  `, `line one\nline two`, and a long string over 50 characters.
- Rich text: bold or colored text from TextEdit.
- File paths: two files copied from Finder.
- URL: `https://example.com/clipmenu?a=1&b=two words`
- Image: a small copied PNG/TIFF-compatible image.
- JavaScript action inputs: `Hello World`, `<b>bold</b>`, `one   two\tthree`, `ClipMenu`.

## Launch and lifecycle

| ID | Feature | Steps | Expected result |
| --- | --- | --- | --- |
| CM-LAUNCH-001 | Launch as menu-bar app | Open `/Applications/ClipMenu.app`. | App starts without a Dock icon, menu-bar status item is visible, and no main window appears. |
| CM-LAUNCH-002 | First-run login prompt | Start with clean user defaults. Launch the app. | The app prompts whether to launch ClipMenu on system startup unless the prompt has been suppressed. Selecting either option stores the preference. |
| CM-LAUNCH-003 | Quit | Open the ClipMenu menu and choose `Quit ClipMenu`. | App exits. If save-history-on-quit is enabled, history is saved before termination. |
| CM-LAUNCH-004 | Relaunch persistence | Copy several text items, quit, relaunch. | Previous history is restored from `clips.data` when save-history-on-quit is enabled and max-history trimming is honored. |

## Clipboard history

| ID | Feature | Steps | Expected result |
| --- | --- | --- | --- |
| CM-HIST-001 | Plain text capture | Copy `alpha`, wait longer than the observe interval, open ClipMenu. | `alpha` appears in the History section. |
| CM-HIST-002 | Multiple item ordering | Copy `alpha`, `beta`, `gamma` in order. | History shows newest first: `gamma`, `beta`, `alpha`. |
| CM-HIST-003 | Duplicate handling | Copy `alpha`, `beta`, then `alpha` again. | Only one `alpha` item exists; its last-used date moves it to the newest position. |
| CM-HIST-004 | Max history trimming | Set max history size to 3. Copy 5 unique text items. | Only the 3 newest clips remain. Older clips are removed. |
| CM-HIST-005 | Multiline title | Copy `line one\nline two`. | Menu title displays only the first line, while selecting the clip pastes the full multiline content. |
| CM-HIST-006 | Long title truncation | Set menu character limit to 20. Copy a string longer than 20 characters. | Menu title is trimmed and ends with `...`; pasted content remains complete. |
| CM-HIST-007 | Empty or unsupported pasteboard | Copy data of a disabled or unsupported pasteboard type. | No new history item is added. |
| CM-HIST-008 | Excluded app | Add an app bundle id to the exclude list. Copy text while that app is frontmost. | No history item is captured from the excluded app. |
| CM-HIST-009 | Reorder after pasting enabled | Enable reorder-after-pasting. Select an older history item. | Selected item is pasted and moves to the top of history. |
| CM-HIST-010 | Reorder after pasting disabled | Disable reorder-after-pasting. Select an older history item. | Selected item is pasted and history ordering stays based on creation date. |

## Paste and menu operation

| ID | Feature | Steps | Expected result |
| --- | --- | --- | --- |
| CM-PASTE-001 | Select clip from menu | Focus a text field in another app, open ClipMenu, choose a history item. | The item is copied to the system pasteboard and Command+V is synthesized into the target app. |
| CM-PASTE-002 | Disable automatic paste | Disable `Input "Command + V" after menu item selection`. Select a history item. | The item becomes the current system pasteboard content but is not automatically pasted. |
| CM-PASTE-003 | Main hotkey | Press the configured main ClipMenu hotkey. Default is Command+Shift+V. | Full ClipMenu menu appears at the cursor location. |
| CM-PASTE-004 | History hotkey | Press the configured History hotkey. Default is Command+Control+V. | History-only menu appears. |
| CM-PASTE-005 | Snippets hotkey | Press the configured Snippets hotkey. Default is Command+Shift+B. | Snippets-only menu appears when snippets exist. |
| CM-PASTE-006 | Numeric labels | Enable numbered menu items. Open ClipMenu. | Clips and snippets are prefixed with list numbers. |
| CM-PASTE-007 | Zero-based labels | Enable `Menu items' title starts with 0`. Open ClipMenu. | Numbered items start at `0.` instead of `1.`. |
| CM-PASTE-008 | Numeric key equivalents | Enable numeric key equivalents and open the menu. Press a number matching a visible item. | The matching item is selected without mouse interaction. |
| CM-PASTE-009 | Foldered history menu | Set inline count to 2 and folder size to 3. Copy at least 8 items. | First 2 clips are inline; remaining clips are grouped into range submenus of up to 3 items each. |
| CM-PASTE-010 | Clear history menu item | Ensure clear-history menu item is enabled. Copy text, open ClipMenu, choose `Clear History`. | Confirmation appears if enabled; confirming removes all history items and disables Clear History until new clips exist. |
| CM-PASTE-011 | Clear history suppression | In the clear-history alert, check suppression and confirm. Trigger clear again after adding clips. | The confirmation alert no longer appears and preference is persisted. |

## Pasteboard types and rendering

| ID | Feature | Steps | Expected result |
| --- | --- | --- | --- |
| CM-TYPE-001 | Plain text type | Enable only Plain Text. Copy text and then an image. | Text is stored; image-only copy is ignored. |
| CM-TYPE-002 | RTF type | Enable RTF. Copy styled text from TextEdit. | Clip is stored with RTF data and can be pasted preserving rich text into rich-text targets. |
| CM-TYPE-003 | PDF type | Enable PDF. Copy PDF content from a compatible source. | PDF clip is stored and displayed with configured type icon/label. |
| CM-TYPE-004 | Filenames type | Enable Filenames. Copy files in Finder. | Filenames clip is stored and can be pasted or action-converted to POSIX/HFS paths. |
| CM-TYPE-005 | URL type | Enable URL. Copy a URL. | URL clip is stored and displayed with URL type labeling/icon behavior. |
| CM-TYPE-006 | TIFF/PICT image type | Enable image types and `Show Image`. Copy a small image. | Image clip appears with thumbnail constrained by configured width and height. |
| CM-TYPE-007 | Disable image display | Disable `Show Image` and copy an image. | Image clip is still stored when its type is enabled, but the menu does not show the thumbnail. |
| CM-TYPE-008 | Type labels | Toggle `Show labels to indicate item types`. | Type labels appear/disappear in menu item titles consistently. |
| CM-TYPE-009 | Menu icons | Toggle `Show Icon in the Menu` and change icon size 16/32/48. | Icons appear/disappear and size changes without breaking menu selection or paste. |
| CM-TYPE-010 | Tooltips | Enable tooltips and copy a long text item. Hover the item. | Tooltip shows the full or preference-limited content. |

## Snippets

| ID | Feature | Steps | Expected result |
| --- | --- | --- | --- |
| CM-SNIP-001 | Open snippet editor | Choose `Edit Snippets...`. | Snippet Editor window opens and becomes active. |
| CM-SNIP-002 | Add folder | In Snippet Editor, add a folder named `QA`. | Folder appears in the source list and is saved after closing. |
| CM-SNIP-003 | Add snippet | Select `QA`, add a snippet titled `Greeting` with content `Hello from snippet`. | Snippet appears in the table and is saved. |
| CM-SNIP-004 | Paste snippet | Focus a target text field, open ClipMenu, choose `QA > Greeting`. | `Hello from snippet` is pasted. |
| CM-SNIP-005 | Empty snippet content default | Create a snippet title while content is empty. | Content is filled from title after editing, except for the default `untitled snippet` title. |
| CM-SNIP-006 | Disable snippet | Disable `Greeting`. Open ClipMenu. | Disabled snippet is not shown and cannot be selected. |
| CM-SNIP-007 | Disable folder | Disable `QA`. Open ClipMenu. | Folder and all snippets under it are hidden. |
| CM-SNIP-008 | Reorder folders | Drag snippet folders in the editor. Close and reopen. | Folder order persists and menu order matches. |
| CM-SNIP-009 | Move snippet between folders | Drag a snippet from one folder to another. | Snippet moves, indexes are renumbered, and the destination menu shows it. |
| CM-SNIP-010 | Search snippets | Use the Snippet Editor search field with All, Title, and Content scopes. | Results filter according to selected scope. |
| CM-SNIP-011 | Export snippets | Choose `Export Snippets...` and save XML. | XML file contains folders, snippets, titles, content, indexes, and enabled state. |
| CM-SNIP-012 | Import snippets | Import a previously exported XML into a clean store. | Imported folders/snippets appear and can be pasted. Invalid XML shows an error. |

## Actions

| ID | Feature | Steps | Expected result |
| --- | --- | --- | --- |
| CM-ACT-001 | Action menu availability | Copy text, open ClipMenu, right-click or Control-click a history item. | Action menu opens for the selected clip. |
| CM-ACT-002 | Built-in remove action | Invoke `Remove` on a history item. | The item is removed from history without pasting. |
| CM-ACT-003 | Paste as plain text | Copy styled RTF text. Invoke `Paste as Plain Text`. | Plain string content is pasted without rich formatting. |
| CM-ACT-004 | Paste as POSIX file path | Copy files from Finder. Invoke `Paste as File Path`. | POSIX paths are pasted, one path per line. |
| CM-ACT-005 | Paste as HFS file path | Copy files from Finder. Invoke `Paste as HFS File Path`. | HFS-style paths are pasted, one path per line. |
| CM-ACT-006 | Action filtering by type | Open action menu for a plain text clip, a file clip, and a snippet. | Only actions valid for that item type are enabled/shown. JavaScript actions are available only for string-like content. |
| CM-ACT-007 | Disable actions globally | Disable `Enable Action`. Try modified-click on a clip. | Modified-click behavior does not invoke actions; normal selection/paste occurs. |
| CM-ACT-008 | Invoke single action immediately | Configure exactly one action and enable immediate invocation. Open action menu behavior for a clip. | The single action runs immediately instead of showing an action menu. |
| CM-ACT-009 | Shift/Option/Command modified-click mappings | Map each modified-click preference to a distinct action. Use each modifier while selecting a clip. | The configured action runs for each modifier. |
| CM-ACT-010 | Bundled JavaScript case actions | Run `UPPERCASE`, `lowercase`, `Capitalize`, and `Title Case` on text. | Output text matches the selected case transform and is pasted. |
| CM-ACT-011 | Trim and collapse actions | Run `Trim`, `LTrim`, `RTrim`, and `Collapse Spaces` on sample padded text. | Whitespace is transformed according to action name. |
| CM-ACT-012 | Surround actions | Run quote, bracket, brace, and Japanese surround actions. | Text is wrapped with the selected delimiters. |
| CM-ACT-013 | HTML actions | Run strip tags, escape/unescape HTML, URI encode/decode, Markdown to HTML, and character/decimal conversions. | Output matches each transformation. |
| CM-ACT-014 | Crypt actions | Run MD5, SHA-1, Base64 encode, and Base64 decode on known inputs. | Output matches known hashes/encodings. |
| CM-ACT-015 | Japanese conversion actions | Run kana and zenkaku/hankaku conversions on representative Japanese strings. | Output matches the expected conversion. |
| CM-ACT-016 | User JavaScript action discovery | Add a `.js` action under `~/Library/Application Support/ClipMenu/script/action`, relaunch or reload actions. | User action appears under the user's action section and can transform text. |
| CM-ACT-017 | Missing script error | Configure an action pointing to a missing script. Invoke it. | App shows `The script you selected does not exist` and does not modify pasteboard content. |
| CM-ACT-018 | Script exception error | Add an action script that throws. Invoke it. | App shows script error/exception feedback and does not crash. |

## Preferences

| ID | Feature | Steps | Expected result |
| --- | --- | --- | --- |
| CM-PREF-001 | Open preferences | Choose `Preferences...`. | Preferences window opens with General, Menu, Action, Snippets, Shortcuts, and Updates areas available. |
| CM-PREF-002 | Observe interval | Change clipboard observation interval, copy a value, time capture. | Clipboard polling follows the configured interval after preferences close. |
| CM-PREF-003 | Stored type toggles | Toggle each stored type and copy matching/non-matching content. | Only enabled types are captured. If all types are disabled, no clips are captured. |
| CM-PREF-004 | Save history on quit | Toggle save-history-on-quit, add history, quit, relaunch. | Enabled preserves history; disabled does not persist new quit-time history. |
| CM-PREF-005 | Export history single file | Configure single-file export and separator, export text history. | File contains text clips in sorted order separated by selected separator. Non-text clips are skipped. |
| CM-PREF-006 | Export history multiple files | Configure multiple-file export and export text history to a folder. | Each text clip is written as a numbered `.txt` file. |
| CM-PREF-007 | Snippet menu position | Set snippets above clips, below clips, and none. Open ClipMenu each time. | Snippet section appears in selected position or is hidden. |
| CM-PREF-008 | Font size behavior | Enable menu font size changes via icon size and selected point size. | Menu font size changes according to preference without truncating or preventing selection. |
| CM-PREF-009 | Login item toggle | Toggle `Launch on Login`. | App is added to or removed from login items and preference state matches. |
| CM-PREF-010 | Update preferences | Toggle automatic update checks and pre-release update checks. | Preferences persist and the updater feed switches between release and pre-release URLs. |
| CM-PREF-011 | Hotkey customization | Change main/history/snippets hotkeys, close preferences, use new hotkeys. | Old hotkeys are unregistered and new hotkeys trigger the correct menus. |
| CM-PREF-012 | Action tree editing | Add/remove/reorder action folders and actions in preferences. Close and relaunch. | Action tree persists in `actions.plist`; removed/disabled actions no longer appear. |

## Migration data checks

| ID | Feature | Steps | Expected result |
| --- | --- | --- | --- |
| CM-MIG-001 | Existing history archive | Start migrated app with a representative legacy `clips.data`. | Migrated history loads supported clips, preserves newest-first order, and trims to max-history preference. |
| CM-MIG-002 | Existing snippets XML | Start migrated app with a representative legacy `Snippets.xml`. | Folders, snippets, order, content, and enabled states are preserved. |
| CM-MIG-003 | Existing actions plist | Start migrated app with a representative legacy `actions.plist`. | Built-in, bundled JavaScript, user JavaScript, and folder structure are preserved or safely migrated. |
| CM-MIG-004 | Existing user scripts | Place user scripts and libraries under the legacy Application Support script folders. | Migrated app discovers user actions and can run scripts with expected library resolution. |
| CM-MIG-005 | Existing preferences | Import legacy user defaults. | Preferences map to migrated controls and behavior, including hotkeys, menu formatting, type filters, and action settings. |

## Non-regression expectations

- The app must not crash when pasteboard content is missing, disabled, malformed, or from an excluded app.
- Selecting clips/snippets/actions must preserve the previous frontmost target app for paste.
- Menu rebuilds after preference, history, action, or snippet changes must reflect new state without requiring a full app restart unless the legacy app also required it.
- Error dialogs for missing scripts, bad XML, failed exports, and failed saves must be visible and must not corrupt existing data.
