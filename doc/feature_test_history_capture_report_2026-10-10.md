# Clipboard history capture — 2026-10-10

## Findings and changes

- The Debug app's saved `maxHistorySize` was 1. Distinct copied texts were
  appended, then immediately trimmed to the newest entry. The Release app's
  setting was 20.
- Debug preferences also retained a `ClipMenuDebugReportTests-.../support`
  directory override and other test fixtures. Tests previously shared the
  everyday Debug app's preferences domain, so interrupted tests could leave
  their temporary values behind.
- Backed up the Debug preferences in the ignored build directory, restored
  its history limit to 20, and removed the stale support-directory override.
  An explicitly configured one-item limit remains supported.
- Added a Testing configuration and selected it for the ClipMenu scheme's
  Test action. It builds `ClipMenuTestHost.app` using the separate
  `com.naotaka.ClipMenu.TestHost` preferences domain. Existing Debug and
  Release settings are unchanged. Testing targets macOS 12, matching the
  current Xcode SDK's supported minimum, and skips startup permission prompts.
- The max-history normalization report now restores preferences before
  restoring history. Synchronous reports snapshot and restore the complete
  persistent preferences domain and exact clip-store state, including IDs,
  timestamps, duplicate archive records, and the unsaved-changes flag.

## Verification

- Debug build passed using the ClipMenu scheme.
- All 11 focused XCTest cases passed in the new Testing configuration:
  the nine ClipStore cases and two history-restoration regressions.
- Regression capture uses a temporary named pasteboard and the application's
  capture/filter logic. Three original entries survive a report that lowers
  the limit to one, and two further distinct copies leave all five intact.
- A separate regression preserves multiple loaded records with the same
  duplicate key but different IDs and timestamps. The store cases verify
  duplicate promotion, normal appending, trimming, and the intentional
  one-item limit.
- Compared the complete Debug preferences before and after the first focused
  run: they were unchanged. Verified the built test host's bundle identifier.
- The rebuilt Debug app launched and a process sample showed its main thread
  waiting for events. A manual menu/copy check could not be completed because
  native UI automation timed out while inspecting the menu-bar app.
- Project plist validation and `git diff --check` passed. The full test suite
  and automatic-paste UI tests were not run.
