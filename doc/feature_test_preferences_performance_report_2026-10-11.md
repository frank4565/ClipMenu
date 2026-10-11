# Preferences tab switching performance — 2026-10-11

## Issue and change

After the beta.2 screen-height and immediate-resize fixes, clicking another
preferences tab still delayed the actual pane switch. Two sources of synchronous
work remained: replacing the SwiftUI pane and measuring its natural size on each
click, and applying all runtime preferences when only the remembered tab changed.

The preferences controller now prepares and retains all six pane hosts, measures
ordinary panes once, and uses the cached height when switching. Only the active
pane receives the new viewport frame. Window dimensions still follow each tab's
content and remain capped to the screen's usable height with vertical scrolling.
Changing only the selected-tab preference no longer rebuilds history menus or
registers hotkeys again. Real preference changes still apply, and duplicate
notifications are ignored.

Retaining panes also preserves pending edits. Reopening preferences refreshes
drafts and the available action catalog without discarding committed action-menu
edits or leaving a reserved-action selection attached to an obsolete identifier.
Cached Type controls and paste-permission status refresh when their underlying
state changes. No localized strings changed.

## Measurements

`testPreferenceToolbarClickLatency` invokes the actual toolbar action through
`NSApp.sendAction`. It measures only the synchronous handler, with settling time
outside the timed interval. Each run includes 24 clicks across all six tabs,
including first visits and repeated switches.

| Same local test host | Median | Maximum |
| --- | ---: | ---: |
| Before performance changes | 134.524 ms | 385.142 ms |
| Final implementation | 13.993 ms | 16.858 ms |

The test asserts that the selected pane and window frame are correct immediately,
that the frame does not change later, and that repeated switches retain identical
hosting views, appearance counts, and natural-size measurement counts. These
numbers measure handler work on the development Mac, not end-to-end display
latency on the reported 13-inch MacBook Air.

## Validation

- Full ClipMenuTests run: 74 tests passed, including all eight preference
  normalization tests and checks that real shortcut changes apply once while
  selected-tab-only changes perform no runtime preference work.
- After the final active-pane frame optimization and the additional action-reopen
  regression test, all 24 MenuPreviewTests passed. Coverage includes immediate
  sizing, synthetic short-screen scrolling, a 480-point Action viewport, pending
  excluded-app edits, and committed actions/reserved selection after reopening.
- Final Debug build succeeded with no compiler warnings or errors.
- Native UI inspection of an isolated English, dark-appearance QA app covered all
  six tabs. General, Type, Menu, and Updates retained complete content; Shortcuts
  used its shorter natural height; Action retained its independent list viewport.
- With General hidden, changing its paste preference updated the control and
  status when it became visible again. With Type hidden, changing the rich-text
  icon preference updated its local control state on return; Reset restored it.
- A temporary Action folder survived switching away and back, then closing and
  reopening preferences with its inspector selection intact. The temporary folder
  was removed and the QA app quit after verification.

The QA app used a separate bundle identifier, defaults domain, and support
directory. The physical MacBook Air remains the target for the next beta retest.
The existing TestHost runtime message about the action drag type is unrelated to
these changes.

## Local evidence

- `/private/tmp/clipmenu-tab-latency-before.log`
- `/private/tmp/clipmenu-tab-latency-final-tests.log`
- `/private/tmp/clipmenu-tab-latency-final-menu-tests.log`
- `/private/tmp/clipmenu-tab-latency-final-debug.log`

The beta.3 package uses Release configuration, universal arm64 and x86_64
architectures, and bundle build 6.0.3. Packaging records the exact local source
snapshot and independently verifies ZIP extraction, mounted DMG contents,
architectures, checksums, and the local ad-hoc signatures.
