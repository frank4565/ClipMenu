# Image hover preview — 2026-10-10

## Findings and changes

- Image history rows previously displayed only their configured thumbnails.
  There was no larger preview on hover.
- Added a floating native panel after a 250 ms highlight delay. The panel
  uses the stored original image, preserves its aspect ratio, fits within
  480 × 360 points plus padding, and does not enlarge small images.
- The preview appears beside the menu when space permits and stays within
  the pointer's screen. Exact menu-window bounds are read through public
  Core Graphics metadata, with a conservative fallback around the pointer.
- The panel does not take keyboard focus or intercept mouse events. Changing
  the highlighted row, selecting an item, closing an owning or ancestor menu,
  or rebuilding history dismisses it.
- History-folder submenus now receive the same hover delegate callbacks.
  `Show Image` controls image previews independently of the text-tooltip
  preference. No preference values were changed.
- Added the accessible preview label in English and Japanese, and added
  manual case CM-TYPE-006A.

## Verification

- Debug build passed using the ClipMenu scheme.
- All 15 MenuPreviewTests passed in the isolated Testing configuration.
  Eight new cases cover original-image rendering, event-tracking timers,
  dismissal, preference gates, invalid image data, submenu delegates,
  aspect ratio, small images, and screen-edge placement.
- The timer regression drives the native event-tracking run-loop mode,
  ensuring the preview can appear while a menu tracks events.
- Rendered the actual native preview panel using a deterministic 960 × 640
  four-color TIFF fixture. Inspected the retained `image-hover-preview`
  XCTest attachment: all four regions are visible, with a proportional
  480 × 320-point image and a rounded padded panel.
- English and Japanese strings passed plist validation; `git diff --check`
  passed.
- The user confirmed the larger image preview appears when hovering in the
  updated build. Separate manual checks of both menu entry points and screen
  edges were not completed. Automated lifecycle checks invoke menu delegate
  callbacks; the full test suite and automatic-paste UI tests were not run.

Local build logs, test results, and the rendered attachment are in the ignored
`build/image-hover-review/` directory.

## Follow-up after the preview did not appear

- The running Xcode Debug app had been built and launched at 23:35, before
  the image-preview implementation. The separate verified Debug build was
  produced at 23:44 and did not replace the running Xcode process.
- Release preferences enable image display and disable text tooltips.
  Removed the unnecessary text-tooltip gate so this configuration also
  shows image previews. Added a regression with text tooltips disabled.
- Rebuilt and relaunched the application from the existing Xcode scheme.
  Confirmed the new process and executable were created at 23:49:59 and
  the loaded build contains `ImageHoverPreviewController`.
- All 15 focused tests passed again, including the text-tooltip-disabled
  regression, in `TooltipIndependentTests.xcresult`.
- The user confirmed “Preview appears” after the updated app was launched.
