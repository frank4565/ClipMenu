# Preferences content sizing — 2026-09-16

## Changes

- Removed the shared outer ScrollView from General, Type, Shortcuts, and Updates.
  Menu also uses the shared measurement path instead of its separate callback.
- Measure the natural height of each pane at the existing 760-point width and
  cache heights by tab. The window fits the selected pane and retains fixed
  user-resize limits. Programmatic changes keep the window on the visible screen
  when its measured size fits that screen.
- Action keeps a 640-point content viewport with scrolling inside its two lists;
  its surrounding pane remains fixed.
- Arranged Type's eight clipboard types in two columns, placed Images and Icons
  side by side, and compacted their previews. All file-type mapping controls
  remain in the full-width section below. This prevents the original tall Type
  layout from extending beyond the available screen.
- Preserved preference bindings, localized strings, and the existing Action list
  behavior. Row label widths are configurable for the two compact Type columns;
  other rows retain their previous 190-point label width.

## Verification

- Debug build passed using the ClipMenu scheme; git diff --check passed.
- Visually inspected General, Menu, Type, Action, Shortcuts, and Updates in the
  running English app in dark appearance.
- General, Menu, Type, Shortcuts, and Updates expose a plain outer accessibility
  container with no scroll area. Action exposes only its inner list scroll areas.
- Shortcuts and Updates shrink to their short content; General grows to show all
  its sections. Type shows its heading through the final PICT mapping row.
- Scrolling over Type did not move the pane. Returning from Type to Menu restored
  Menu's compact window height, preview, and bottom Font controls.
- No preference values were intentionally changed during these layout checks.
- Japanese, light appearance, and smaller displays were not manually retested.
- Left the final development build open on Menu.
