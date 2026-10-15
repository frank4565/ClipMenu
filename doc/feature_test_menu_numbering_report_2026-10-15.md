# Menu sequence numbering — 2026-10-15

Removed the special case that displayed the tenth history item's sequence as
`0.` when the inline count or folder size was ten. One-based labels now continue
through `10.` in both locations. Command+0 remains the tenth history item's
shortcut. No localized text changed.

Validation:

- Debug `xcodebuild` succeeded without compiler warnings.
- The running Debug app's MenuNumberingSurface report passed all seven checks
  using a separate bundle identifier and an isolated support directory.
- Ten inline history items and the first ten-item history submenu both ended
  with `10. num-2`; both tenth items retained the `0` Command key equivalent.
- Eleven-item one-based history, zero-based history, unnumbered history, and
  snippet numbering also matched their expectations.
- CM-PASTE-006 now explicitly covers ten-item sequences. Verification inspected
  native AppKit menu titles and key equivalents; physical key presses were not
  exercised.

Evidence: `/private/tmp/clipmenu-menu-numbering-build.log` and
`/private/tmp/clipmenu-menu-numbering-se0500cq/report.json`.
