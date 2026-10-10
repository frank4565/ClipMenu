# Menu preferences layout — 2026-09-15

## Changes

- Aligned Menu checkboxes with the section headings instead of reserving an
  empty 204-point label column.
- Moved checkbox explanations into hover help and indented the dependent
  numbering and clear-history confirmation options.
- Placed the preview beside the Menu Items controls, with a visible Menu
  Preview heading, system control background, and rounded border.
- Replaced the hard-coded QA folder name with localized Example Folder text.
- Kept font mode and point size on one row, indented beneath their parent
  checkbox. Tooltip length is also indented beneath its parent checkbox.
- Added the two new preview strings to English and Japanese resources.

## Verification

- Debug build passed using the ClipMenu scheme and build/MenuReview derived
  data directory. Xcode required execution outside the sandbox for its Swift
  preview compiler plugin.
- Both localization files passed plutil validation; git diff --check passed.
- Opened the exact rebuilt ClipMenuDebug.app in English and dark appearance.
  Layout, Menu Items, Tooltips, and Font all fit in the standard window.
  Accessibility reports no scrolling controls for the pane.
- Inspected the checkbox alignment, dependent indentation, preview border,
  and single-row font controls. A floating overlay obscured part of the
  screenshot; accessibility confirmed the preview heading and Example Folder.
- Turned numbering off: the zero-based numbering option became disabled and
  preview numbering disappeared. Restored numbering to its original value.
- Enabled font changes: the mode picker became enabled while point size stayed
  disabled in Fit to the icon size mode. Restored the original disabled state.
- Japanese and light appearance were not manually retested.
- Left the updated development build open on Menu preferences.

## Follow-up: shortcut modifiers and hover tooltips

- Preview shortcuts now include the Command symbol (for example, ⌘1), matching
  the actual menu's Command modifier.
- Removed the inline tooltip text and attached native hover help to the history
  preview row. It respects the tooltip toggle and configured character limit.
- Debug build and git diff --check passed. The relaunched app shows ⌘1 with no
  separate T row. Accessibility exposes T as Help with the current one-character
  limit. Disabling tooltips removes that Help; re-enabling restores it. The
  original preference was restored after verification.
- An unobstructed screenshot confirmed the final preview and compact layout.
- No localized text changed in this follow-up.

## Follow-up: visible tooltip sample

- Restored the tooltip inside the preview at the user's request, with a localized
  Tooltip heading and a compact inset background. Up to three lines are visible;
  hover help retains the complete text within the configured character limit.
- Preserved the requested 200-character setting and Command shortcut symbols.
- Added Tooltip to the English and Japanese localization resources.
- Debug build and localization validation passed. Inspected the running English
  preview: the Tooltip heading and complete sample sentence are visible beneath
  the history row, and hover Help remains available.

## Follow-up: shared preview column

- Moved Menu Preview out of the Menu Items section into a separate column beside
  the complete settings stack. Its heading aligns with the top Layout heading.
- Layout, Menu Items, Tooltips, and Font now share one vertical stack with
  consistent 18-point section spacing. Preview height no longer determines the
  gap between Menu Items and Tooltips.
- Debug build and git diff --check passed. Inspected the restarted English app
  in dark appearance: all controls fit without scrolling, the preview retains
  its tooltip sample and Command shortcut, and Menu Items flows directly into
  Tooltips with normal section spacing.
- No localized strings or preference values changed in this follow-up.

## Follow-up: non-scrolling, fitted window — 2026-09-16

- Removed the Menu pane's ScrollView and measure its natural content height at
  the existing 760-point width. The window follows that height, preserving its
  top edge and fixed user-resize limits. Other tabs retain their standard size.
- Removed the old window resize delegate veto; content minimum and maximum
  sizes enforce the fixed user size while allowing programmatic fitting.
- Debug build and git diff --check passed. In the running English app, Menu's
  measured content size was 760 by 580 points rather than 760 by 640 points.
  The screenshot showed all controls with normal bottom padding.
- Accessibility exposes a plain container with no scroll area. A downward
  scroll gesture did not move the content.
- Switched to Action and back: Action restored the 640-point content height,
  while Menu returned to 580 points. The app remained responsive.
- Temporary measurement logging was removed and the final Debug build passed.
- Japanese and light appearance were not manually retested.
