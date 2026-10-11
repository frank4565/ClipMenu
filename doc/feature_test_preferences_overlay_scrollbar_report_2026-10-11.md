# Preferences overlay scrollbar — 2026-10-11

General and the other ordinary preferences panes now use the native AppKit
overlay scrollbar instead of the legacy scrollbar. The indicator is thin,
appears during scrolling, and fades when idle. Vertical scrolling and the
screen-height cap remain enabled. Action retains its independent list scrolling.
No localized strings changed.

The existing compact-General regression test no longer requires the scrollbar
view to be permanently visible. It still verifies overflow, the 480-point
viewport cap, and scrolling to the last part of the document.

Validation:

- Debug build succeeded without compiler warnings or errors.
- All three existing focused checks passed: compact General scroll reachability,
  immediate per-tab resizing, and toolbar click latency. The 24 toolbar samples
  had a median handler time of 14.536 ms and a maximum of 19.476 ms.
- Native UI inspection used an isolated English QA app in dark appearance.
  General displayed every section and its last control without a permanent
  scrollbar track on the development display. Switching to Shortcuts and back
  retained the short/tall pane heights and complete General content.
- Short-screen reachability was checked by the existing synthetic viewport test;
  native indicator fade timing was not separately timed. The physical MacBook
  Air remains the target for the beta.4 appearance check.

Evidence: `/private/tmp/clipmenu-overlay-scrollbar-debug.log` and
`/private/tmp/clipmenu-overlay-scrollbar-tests.log`.

The local beta.4 package uses universal Release configuration and bundle build
6.0.4, with the same ad-hoc signing and package verification workflow as beta.3.
