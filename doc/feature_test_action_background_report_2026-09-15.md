# Action preferences list backgrounds — 2026-09-15

## Change

Available Actions and Action Menu now share a system control background, an
8-point rounded border, and a minimum panel height of 220 points. Empty titles
no longer leave a blank strip above the column header. The border does not
intercept selection or drag-and-drop events. No localized text changed.

## Verification

- Debug clean build passed with Xcode (`ClipMenu` scheme).
- Opened the rebuilt Debug app on Preferences > Action in dark appearance.
- Visually confirmed both panel borders enclose the headers, rows, and unused
  space; the empty User's category remains inside its panel with legible text.
- Selected a built-in action and confirmed its highlight and inspector appeared.
- Collapsed the Case and Trim folders and confirmed their disclosure controls
  continued to work.
- Returned to Built-in and left the updated Action tab open.
- Light appearance and drag-and-drop were not manually retested.

Incremental builds returned success but produced an app without an accessible
Preferences window during this run. A clean build restored normal launch; the
final app was verified from that clean build.
