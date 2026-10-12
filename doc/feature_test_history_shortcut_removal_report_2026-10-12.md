# History shortcut removal — 2026-10-12

Removed the hidden history-only global shortcut, previously documented as
Command–Control–V. The two shortcuts in Preferences remain the supported menu
shortcuts: the full ClipMenu menu and the Snippets menu. Clipboard history remains
available in the full menu.

The README lists those two defaults. CM-PASTE-004 now covers the absence of
history-only shortcut registration with clean and legacy preferences, and
CM-PREF-011 covers customization of the two supported shortcuts. Image-hover
preview instructions use the full menu. Historical parity notes retain their
earlier observations with a prominent notice that the removed shortcut and its
old verification claims are obsolete.

Validation:

- Validation started on 2026-10-12 and completed on 2026-10-13 in Asia/Hong_Kong.
- Documentation audit found no remaining current claim that the hidden shortcut
  is supported. Mentions in acceptance cases describe its removal; the dated
  parity log identifies its older evidence as obsolete.
- The final Debug rebuild succeeded after localization cleanup, and localization
  lint and `git diff --check` passed. Removed nine obsolete Japanese strings for
  the retired shortcut; English had no matching obsolete entries.
- The focused Testing run passed 51 tests with zero
  failures: 24 MenuPreview, 20 PreferenceNormalization, and 7 PreferenceSnapshot
  tests. A test-host loader stall in the Documents build was stopped; the
  successful retry used `/private/tmp/ClipMenuShortcutTests-20261012`.
- Six affected Debug runtime reports passed in an isolated app with its own
  preference domain and support directories: HotKeyParity, HotKeyCustomization,
  HotKeyMenuPresentation, ShortcutsPreferences, LegacyPreferencesMigration, and
  ControllerPublicActions. Real Carbon registration returned only IDs `[1, 3]`
  for the full menu and Snippets menu; the parity report recorded
  `retiredHistoryShortcutIgnored = true`. Menu dispatch captured two popups.
- An additional broad DefaultsShape report returned `matchesExpected = false`
  because `actionsPlistExists` was false in the fresh empty support directory.
  Its legacy-hotkey and split-hotkey expectations passed. The action-storage
  behavior is outside this shortcut change.
- Physical keyboard triggering was not exercised. Registration and menu
  dispatch were verified through the running isolated Debug app; the installed
  release app was not replaced.

Evidence: `/private/tmp/clipmenu-history-shortcut-removal-build-final.log`,
`/private/tmp/clipmenu-history-shortcut-removal-tests-tmp.log`, and
the per-hook `report.json` files under
`/var/folders/vh/n4vt6kz13y32yy_f23g5qs3m0000gn/T/clipmenu-history-shortcut-removal-jm5cl1mt`.
