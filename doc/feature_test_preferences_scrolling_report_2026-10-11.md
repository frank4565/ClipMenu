# Preferences scrolling and immediate pane resizing — 2026-10-11

## Changes

- The actual selected SwiftUI pane is hosted in an AppKit scroll view and its
  natural height is measured synchronously before sizing the window. General,
  Menu, Type, Shortcuts, and Updates each use their own content height at the
  existing 760-point width.
- Height is capped to the screen's visible frame, including window chrome and
  a 12-point margin on each side. Overflowing ordinary panes expose a visible
  vertical scrollbar; it hides when the complete pane fits. Switching panes
  resets the ordinary pane's scroll position to the top.
- Tab selection updates the pane, window title, toolbar highlight, and window
  frame in the same call, without animation. The toolbar/top edge stays in place
  unless fitting on screen requires moving it.
- Later content changes can update the height outside the SwiftUI layout pass.
  A presentation revision prevents stale callbacks from earlier tab visits from
  changing the current window during rapid switching.
- Action fills the available viewport and retains independent list scrolling.
- Screen changes and display-parameter changes refit the window. The existing
  preferences window debug report now checks actual visible-screen containment
  instead of accepting any height up to 1200 points.
- Updated manual cases CM-PREF-MENU-LAYOUT, CM-PREF-PANE-SIZE, CM-PREF-001,
  CM-PREF-001G, and CM-PREF-012B. No visible strings changed; localization updates
  were unnecessary.

## Automated verification

- Debug build passed with the ClipMenu scheme; no compiler warnings or errors.
- Focused `ClipMenuTests/MenuPreviewTests` run passed: 21 tests, zero failures.
  Three new regression tests verify:
  - Tall panes cap to a synthetic 1280 × 720-point screen, while short panes
    retain their natural height and larger screens allow heights above 640.
  - The actual General window's scroll document at a simulated 480-point
    viewport exposes a scrollbar and can reach its bottom.
  - First visits to all six tabs finish resizing before the selection call
    returns. No delayed frame change occurs after layout or rapid switching.
    General uses a taller window than Shortcuts.
- The test host uses its separate preferences domain; the new UI tests also
  restore preferences and controller state.
- The Action pane emitted an existing runtime warning that its custom drag
  type `net.clipmenu.action-node` is not exported in the test host's Info.plist.
  It did not cause a build warning or test failure.
- `git diff --check` passed.

Build/test products are in `.derivedData-preferences-fix`. Both commands used
the cached Sparkle package under `.derivedData-warning-cleanup/SourcePackages`
with automatic package resolution and updates disabled. Logs are in
`/private/tmp/clipmenu-preferences-{debug,tests}.log`.

## Local run notes

- Inspected the final Debug build in an isolated QA app, in dark appearance in
  English and Japanese. The QA app used the Automatic scrollbar preference.
- General displayed its complete content through the final Excluded
  Applications button on the large test display, without an unnecessary
  scrollbar. Shortcuts shrank to its short content immediately in both
  languages. The toolbar/top edge stayed in place while switching.
- Type displayed its final PICT controls at its natural height. Action retained
  its independent list scroll areas, and switching from Action back to General
  restored General's complete document correctly.
- No preference controls were edited during these checks. The temporary QA
  instance was closed afterward.

The short-screen and 480-point viewport checks were simulated; this run did not
use the reported physical 13-inch MacBook Air. Light appearance and changing
display resolution while the window is open were not manually retested.
