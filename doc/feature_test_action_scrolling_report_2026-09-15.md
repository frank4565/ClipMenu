# Action preferences scrolling — 2026-09-15

## Change

- Removed the outer Action tab scroll view and constrained its layout to the
  available window size with a geometry reader.
- Disabled automatic hosting-controller window sizing on macOS 13 and later,
  matching the existing snippet editor approach. Preferences retains its
  configured 760-by-640-point content size.
- Both action lists use the remaining height and scroll independently. Their
  headers stay outside the scrolling content. The previous 220-point minimum
  no longer forces the Action Menu below the window when its inspector opens.
- Behavior controls and inspector fields retain their required height.
- No localized strings changed.

## Verification

- Clean Debug build passed (`ClipMenu` scheme).
- Opened the rebuilt app in dark appearance on Preferences > Action.
- Confirmed the accessibility tree has a non-scrolling outer container and two
  inner scroll areas.
- Selected JavaScript and scrolled Available Actions to the bottom: its scroll
  position changed from 0 to 1 while Action Menu stayed at 0.
- Scrolled the expanded Action Menu to the bottom: its position changed from
  0 to 1 while Available Actions stayed at 1.
- Selected Trim.js to show the name, type, and path inspector. The Action Menu
  shrank to the remaining space, and its bottom rows remained reachable by
  scrolling. Both panel bottoms remained inside the window.
- Scrolled over blank space beside Behavior; the window content did not move.
- Left the rebuilt Debug app open on Action preferences.
- Light appearance and macOS versions before 13 were not manually retested.

## Follow-up: freeze during repeated scrolling

The user reported a freeze after scrolling between the lists. A two-second
sample of the frozen process showed the main thread continuously updating the
SwiftUI layout graph, including lazy row layout and prefetch updates.

The Action tab now gives its content an explicit width and height from the
geometry reader. ActionTreePanel uses a regular VStack so scrolling does not
repeatedly create and measure lazy rows while the surrounding layout changes.
Independent list scrolling and the fixed outer window are preserved.

Validation after the fix:

- Clean Debug build passed and the rebuilt app was restarted.
- Performed 24 scroll gestures across both lists, including repeated direction
  changes with a JavaScript action inspector visible and expanded folders.
- Verified both scroll positions reached the bottom, then switched to an empty
  category, switched to General and back, selected an action, and scrolled again.
- The app remained responsive. A second two-second sample showed the main
  thread waiting normally for events in all 1,724 samples, with no layout loop.
- Left the corrected Debug app running on Action preferences.

The regular stack creates all action row views; very large custom action
collections were not performance-tested.

## Follow-up: compact spacing and directional controls

- Constrained the middle toolbar to 36 points and reduced the horizontal gaps
  to 10 points so the two lists receive the remaining width.
- Replaced Add/Remove plus and minus icons with right/left arrows, placed
  together above folder creation and the reorder controls.
- Kept the existing action handlers and localized tooltips, and added explicit
  accessibility labels using the same localized strings.
- Clean Debug build passed. Visually verified the compact layout in the running
  app and confirmed accessibility exposes Add as arrow.right and Remove as
  arrow.left. Repeated eight scroll gestures across both lists with the
  JavaScript inspector open; the app stayed responsive.
- Add/remove handlers were unchanged and were not invoked on the user's action
  collection during this visual check.

## Follow-up: centered category tabs

Centered the Built-in / JavaScript / User's segmented picker over the Available
Actions list. A clean Debug build passed, and a screenshot of the relaunched app
confirmed equal space on either side of the picker within the left panel width.

## Follow-up: aligned column headings

Moved the Action Menu heading above its selection inspector so it remains level
with Available Actions. Clean Debug build passed. Selected Capitalize.js in the
running app and visually confirmed that both headings stay on the same baseline
while the inspector is visible.
