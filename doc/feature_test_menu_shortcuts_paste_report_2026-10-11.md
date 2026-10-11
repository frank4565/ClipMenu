# Menu shortcuts and automatic paste — 2026-10-11

## Scope and environment

- Reported on a MacBook Air running macOS 27.0.1: Command-number selection inside the menu failed, and Safari's address bar received an automatic paste only after another keyboard event.
- Local validation: macOS 26.7.1, Xcode with the macOS 27.0 SDK.
- Base revision: `d7b0c59d55ea06e760d9505ddc33630e38872806`; these changes are pending on `swiftui-native`.

## First test package: both bugs persisted

The user tested `ClipMenu-0.5.1-shortcut-paste-test.zip` (version 0.5.1, build 6.1.99) on the MacBook Air and reported that both bugs remained. Command–1 left the menu open. Safari's delayed paste also persisted. The first package's passing builds and 81 unit tests did not establish a fix on the affected machine.

That attempt used a scoped Carbon dispatcher handler and a default-mode paste handoff. Its native-menu probe injected queued Carbon and Cocoa events; it did not establish delivery of physical keyboard events through the same handler. The revised implementation below replaces those approaches.

First archive SHA-256: `d9564a98189e1726a366671c300ce0380dfc171351e01096df79bc1ee5cc71cc`.

## Revised implementation

- A scoped active Quartz session event tap handles Command-number selection while a ClipMenu menu is open, using the existing Accessibility grant. It matches enabled numbered items through event characters and the current keyboard layout, consumes the selected key's down/up events, then queues one ordinary menu action after the tap callback returns. Closing the menu cancels stale queued selections. Cleanup retains only pending selected-key releases for a bounded interval. If the tap cannot be installed, native menu key equivalents remain available.
- Keyboard selections bypass modified-click actions. Modifier changes preserve the preceding mouse interaction for Command-click actions.
- Paste resolves the keyboard-layout key and captures the destination on main. Handoff blocks and readiness timers run in common modes and the captured current mode, with explicit menu-state checks before activation or posting. An already-frontmost destination is not reactivated.
- Paste requires the exact captured destination process to be frontmost, no open ClipMenu menu, and physically released modifier keys. A monotonic 2.5-second deadline cancels expired requests even when a callback runs late. Locked request generations cancel superseded work.
- The readiness check and event posting run in one main run-loop callback. A `combinedSessionState` source sends Command down, paste-key down/up, and Command up through the normal session keyboard stream. Production uses one transport; the deprecated Accessibility keyboard fallback is limited to an explicitly forced Debug experiment.
- Optional diagnostics record monotonic timestamps, run-loop modes, stages, process IDs, permission state, and relevant Command-number key codes in `~/Library/Logs/ClipMenu/menu-paste.log`. They omit clipboard contents, item titles, and ordinary typed text. A serial background queue writes and caps the log; event callbacks perform no file writes or waits.

Apple documents that [local event monitors can be bypassed by nested menu tracking](https://developer.apple.com/documentation/appkit/nsevent/addlocalmonitorforevents(matching:handler:)) and that [sources and timers wait until their run-loop mode is active](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Multithreading/RunLoopManagement/RunLoopManagement.html). The macOS SDK's `CGEventSource.h` recommends `combinedSessionState` for applications posting within a login session. These constraints informed beta 1; its affected-machine result is recorded below.

## Revised validation

| Check | Result |
| --- | --- |
| Final revised Debug build | **Passed.** `build/menu-keyboard-paste-debug-revised.log`. |
| Final revised Testing unit suite | **84 passed, 0 failures.** `build/menu-keyboard-paste-unit-revised.log`; test products under `/private/tmp` avoid the earlier Documents library-loader stall. |
| Quartz shortcut regressions | Passed through controlled event-handler calls: Command–1/0, zero-based and foldered items, event character matching, one queued selection, selected-key release consumption, stale-selection cancellation, unrelated keys, and modified-click separation. Actual physical keyboard delivery remains a separate integration check. |
| Paste preparation and scheduling regressions | Passed: balanced events using the captured key, preparation while main is occupied, handoff and timers in idle tracking and a custom mode outside the common set, expired readiness rejection, physical-modifier gating, and exact destination matching. |
| Native CUA menu baseline | **Not reached.** The first isolated fixture exposed its Preferences window but no accessible status item. Attaching a separate hotkey fixture stalled for 557.5 seconds; its launcher never created a readiness report, and the attempt was stopped before keyboard input. Original clipboard representations were restored and compared byte for byte. Both owned fixtures were stopped; temporary fixtures and clipboard backups were removed. This establishes no native shortcut result. Cleanup metadata: `build/menu-native-cleanup-report.json`. |
| Approved isolated native QA | **Passed with physical keyboard input on macOS 26.7.1.** The user opened the native menu with Control–Option–Y, selected Command–1, released all keys, and stayed idle for five seconds. The menu closed and Safari displayed the synthetic fixture before any further input. The scoped event tap recorded the real Command–1 and dispatched one menu action. |
| Safari and TextEdit automatic paste | **Safari Command–1 passed locally; mouse selection and TextEdit remain unverified end to end.** The original four automated UI cases skipped because the normal Debug app lacked Accessibility/Post Events permission. The later physical case used the separately approved QA app. |
| Original clipboard-only Command–1 UI case | **Unverified end to end.** XCTest reported an invalid `(inf, inf, 0, 0)` menu bar display rectangle and failed before shortcut selection. This is a test-input failure, not a successful menu result. |
| Revised universal Release build | **Passed** for `arm64` and `x86_64`; log: `build/menu-keyboard-paste-release-revised.log`. |
| Revised local test archive | **Verified:** `ClipMenu-0.5.2-beta.1-menu-paste-test.zip`, version **0.5.2-beta.1**, build **6.2.1**. Ad-hoc signature, architectures, update feed/public key, diagnostic flag, and bundled license notices verified before packaging and after extraction. No GitHub release/tag created. |

Earlier integration logs remain under ignored `build/`: `menu-keyboard-paste-ui-tests.log` and `menu-command-number-ui-test-final.log`. Their permission skips and event-synthesis failures are verification limitations, not successful bug checks.

### Approved physical test

The final Debug executable was copied into a native QA bundle with identifier `com.clipmenu.fixed-paste-qa.20261011`, separate preferences and history, and a distinct ad-hoc designated requirement. The user approved temporary Accessibility access and authenticated locally in System Settings. Existing ClipMenu and ClipMenuDebug permission toggles were on before and after the addition; they were not changed.

CUA attachment took 449.77 seconds before the QA app launched. Its generated global-shortcut input did not reach Carbon's hotkey handler, and the SystemUIServer status-menu route timed out. A simpler shortcut configured through the native recorder also failed with generated input. These failures occurred before Command–1 and do not establish an application shortcut failure. The user then performed the physical sequence in the empty Safari test window and confirmed that the menu closed and text appeared during the five-second idle period.

The QA process log records Command–1 at monotonic time `26862.189` in `NSEventTrackingRunLoopMode`, one successful action dispatch, selected-key release at `26862.330`, exact Safari destination/frontmost PID `1239`, and released physical modifiers before session posting at `26862.355`. Posting completed at `26862.357`: **166 ms from Command–1 to posting**, with no subsequent user input required. The fixture text was `clipmenu-qa-physical-command-one-20261011`; no original clipboard text was logged.

The local pass does not replace validation on the reported MacBook Air running macOS 27.0.1. A later CUA AX read did not independently confirm the pasted text, so the visible-result evidence is the user's observation before further input, corroborated by the timing log.

Cleanup completed: every original clipboard item/type/data byte was restored and verified; the private backup and exact owned Safari window were removed. The original Safari window and existing ClipMenu permission toggles were preserved. The QA app's temporary Accessibility grant was reset for its unique bundle ID. LaunchServices required registering a byte-identical copy outside `/private/tmp` before `tccutil` could resolve that ID. A fresh QA launch (PID `14359`, uptime `27305.248`) reported `ax=false post=false`, and General showed **Needs Access**. Native Quit stopped the test process. Both temporary QA registrations/directories and the isolated preference domain were then removed. Safe result metadata: `build/menu-keyboard-paste-native-verification-20261011.json`.

## Beta 1 MacBook Air result: selection works, automatic paste expires

The user reported that Command-number now dismisses the menu and copies the correct item on macOS 27.0.1. Manual Command–V pastes that item, but automatic paste still fails. The supplied beta 1 log corroborates successful numeric matching and action dispatch after Accessibility becomes available.

The failed granted attempts do not reach `paste-check`, `paste-post-session`, or `paste-post-complete`. For example, generation 7 requests paste at uptime `24028.198` and reaches handoff at `24028.208`; its readiness callback runs at `24031.080`, **2.882 seconds after the request**, and cancels against the 2.5-second deadline. Generations 3 and 6 also expire after mouse/menu selection, so the failure is not limited to the numeric event tap. Initial launch and selection attempts lacked access, but later tap installation and numeric dispatch show that access changed during the run.

This establishes delayed readiness scheduling before any synthetic paste events are sent. It does not establish a changed macOS permission API, rejection of posted events, or App Nap as the specific cause. The first post-handoff callback and selected-key release sometimes run only when another menu/input event arrives.

## Beta 2 scheduling revision

- Replace main run-loop readiness timers with a serial background queue using a user-initiated deadline. On expiry, enqueue the state check in the main loop's current and common modes and explicitly wake the main loop. Destination checks and event posting remain on main.
- Hold a `ProcessInfo` user-initiated activity for the pending paste to prevent macOS from deferring this user operation when the accessory app becomes idle. Allow system sleep. End it on dispatch, cancellation, supersession, termination, or deinit; an independent background watchdog also releases it at the 2.5-second deadline even if main is blocked. Stale watchdogs cannot end a newer request's activity.
- Keep the existing destination/modifier/menu guards, expiry deadline, permission checks, and keyboard transport. No late paste is allowed after the deadline.
- Add diagnostic activity stages and background deadline/main callback lateness, plus fresh Accessibility/Post Events preflight values. This distinguishes a late background deadline from a delayed main callback on the affected machine without recording clipboard content.

Apple recommends [declaring user-initiated activity to prevent work deferral](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/PrioritizeWorkAtTheAppLevel.html). App Nap is a possible contributor to the observed delay, rather than a confirmed diagnosis. Regression tests exercise idle default, tracking, and non-common run-loop modes; a blocked-main background trigger; and bounded, generation-safe activity cleanup. They do not reproduce macOS 27 App Nap or establish an end-to-end MacBook Air pass.

### Beta 2 validation

| Check | Result |
| --- | --- |
| Debug build | **Passed.** `build/menu-keyboard-paste-beta2-debug.log`. |
| Final Testing unit suite | **89 passed, 0 failures.** `build/menu-keyboard-paste-beta2-unit-final.log`; no compiler warnings. |
| New scheduling and activity regressions | **Passed.** Independent background deadline while main is blocked; main callbacks in idle default, tracking, and non-common modes; watchdog expiry with main blocked; superseded watchdog isolation; repeated completion. |
| Independent source review | No actionable activity lifecycle race or cleanup defect found; generation and token state use the same lock, and AppKit work remains on main. |
| Universal Release build | **Passed** for `arm64` and `x86_64`, version **0.5.2-beta.2**, build **6.2.2**. `build/menu-keyboard-paste-beta2-release.log`. |
| Packaged and extracted app | **Verified.** Ad-hoc host signature, nested signatures, both architectures, version/build, unchanged update feed/public key, bounded diagnostic flag, and license notices. `build/menu-keyboard-paste-beta2-package.log` and `build/menu-keyboard-paste-beta2/verification.json`. |
| Affected MacBook Air | **Failed automatic paste with beta 2.** The follow-up log below isolates timely background scheduling followed by delayed main delivery. The beta 1 local macOS 26 pass does not establish a macOS 27 result. |

## Beta 2 MacBook Air result: background deadline is timely, main delivery is late

The appended beta 2 log confirms version `0.5.2-beta.2`, process `17274`. Access changes from `ax=false post=false` at launch to `ax=true post=false` at paste request. Numeric selection again matches and dispatches successfully, but automatic paste still fails. The mouse-selected attempt also fails after removing its event tap.

| Stage | Command-number, generation 1 | Mouse, generation 2 |
| --- | --- | --- |
| Paste requested / activity begun | `24886.047` | `24896.405` |
| Main handoff / readiness scheduled | `24886.057` | `24896.414` |
| Background deadline | `24886.109`, **2.6 ms late** | `24896.466`, **1.9 ms late** |
| Background activity watchdog ends | `24888.664` | `24899.022` |
| Main callback finally runs | `24888.931`, **2824.0 ms late** | `24899.315`, **2850.9 ms late** |
| Result | `paste-cancel-expired-readiness` | `paste-cancel-expired-readiness` |

Both granted attempts stop before `paste-check` or event posting. The permission guard, layout lookup, and destination handoff finish before the delay; no activation is necessary. The independent background deadline succeeds, so replacing the timer and holding an activity did not resolve delivery into the main event loop. This evidence does not identify a permission API change or prove App Nap; it narrows the failure to a delayed main callback, which may reflect AppKit's event wait or synchronous application work.

## Beta 3 AppKit delivery revision

The revision delivers a private application-defined event into ClipMenu's own AppKit queue and handles its callback on main. The existing Core Foundation block remains a fallback, sharing an exactly-once callback so the two paths cannot duplicate paste. Only identifiers are retained in queued events/CF blocks; the callback registry expires independently of main. Creation and posting use a separate background wake queue so an AppKit lock wait cannot delay readiness or registry expiry. This private event does not synthesize keyboard or mouse input, activate the app, or enter Safari's event queue. Destination, physical modifier, menu, generation, and deadline guards remain in force.

New regression coverage exercises an actual `NSApplication.nextEvent` wait and dispatch, supplementing the earlier Core Foundation run-loop tests. Diagnostic stages identify private event posting/receipt and main-loop waiting state, plus clipboard capture, history persistence, menu rebuilding, defaults application, and selection durations. The subsequent MacBook Air log establishes whole-history synchronous persistence as the blocker, as recorded below.

Apple documents that [`NSApplication.postEvent(_:atStart:)` can enqueue events from subthreads](https://developer.apple.com/documentation/appkit/nsapplication/postevent(_:atstart:)). The beta 3 affected-machine result failed because application work blocked main after handoff.

### Beta 3 validation

| Check | Result |
| --- | --- |
| Final Debug build | **Passed.** `build/menu-keyboard-paste-beta3-debug-delivery-final.log`. |
| Final Testing unit suite | **94 passed, 0 failures.** `build/menu-keyboard-paste-beta3-unit-delivery-final.log`; no compiler warnings. |
| Actual AppKit event wait | **Passed locally in 41 ms**, including a final CF fallback check. The test drains old private events, waits through `NSApplication.nextEvent`, requires receipt of a new private event within 400 ms, dispatches it normally, and checks that the callback runs once. It also verifies the host is `CMApplication`. This is scheduler integration coverage, not a Safari paste result on macOS 27. |
| One-shot delivery and lifetime | **Passed.** Event-first, CF-first, duplicate event, unrelated event, and expired callback cases; captured objects release through background expiry with main blocked. Existing modifier, exact-destination, menu, and monotonic-deadline guards also pass. |
| Custom-mode regression | The initial beta 3 run caught a failure when AppKit posting ran synchronously inside a CF entry observer. Moving event creation/posting to the background resolved it; all original assertions remain. The 20-test scheduling subset and final 94-test suite pass. |
| Independent source review | No actionable startup, threading, callback ownership, exactly-once, or expiry defect found. `CMApplication` is explicitly used at startup and set as the principal class. |
| Final universal Release build | **Passed** for `arm64` and `x86_64`, version **0.5.2-beta.3**, build **6.2.3**. `build/menu-keyboard-paste-beta3-release-final.log`; no compiler warnings. |
| Delivered package | **Verified after extraction.** Ad-hoc host/nested signatures, both architectures, version/build, `CMApplication` principal class, unchanged update feed/public key, bounded diagnostic flag, and license notices. `build/menu-keyboard-paste-beta3-package.log` and `build/menu-keyboard-paste-beta3/verification.json`. |
| Affected MacBook Air | **Failed automatic paste.** The beta 3 log identifies synchronous clipboard-history saving and menu rebuilding as the main-thread blocker. |

## Beta 3 MacBook Air result: history saving blocks paste

The appended beta 3 log identifies version `0.5.2-beta.3`, process `18053`. Both Command-number selections match and dispatch. Accessibility is granted at paste request (`ax=true post=false`), and the main handoff runs promptly. ClipMenu then observes the pasteboard generation written by its own history selection, captures it again, synchronously saves the entire history, and rebuilds the menu again.

| Stage | Generation 1 | Generation 2 |
| --- | --- | --- |
| Selection and initial reorder/menu rebuild | **452.2 ms** | **452.1 ms** |
| Main poll starts | `25990.258` | `26002.734` |
| Clipboard capture | **0.2 ms** | **0.2 ms** |
| Whole-history persistence on main | **2468.2 ms** | **2494.6 ms** |
| Second menu rebuild on main | **445.1 ms** | **437.7 ms** |
| Total main poll duration | **2913.8 ms** | **2932.7 ms** |
| Background readiness lateness | **2.3 ms** | **1.4 ms** |
| Result | Callback expires before main becomes available | Callback expires before main becomes available |

This is a confirmed application-work delay. The log never reaches paste posting, so it does not establish a changed macOS permission API or a failure to deliver posted keys. The private AppKit wake event arrives after the blocking poll; replacing wake mechanisms alone cannot resolve this path.

## Beta 4 history persistence revision

- A history selection acknowledges the exact pasteboard ownership generation returned by `declareTypes`, avoiding redundant capture, full-history save, and menu rebuild. A later external ownership generation remains eligible for capture. Existing clip IDs, payloads, creation dates, and the user's reorder setting remain intact.
- Whole-history encoding, legacy archive construction, and atomic writes run on a serial background queue using immutable snapshots and captured destination URLs. Completions clear dirty state only for the matching revision. Synchronous final saves, loads, and history deletion remain ordered after queued writes, preventing stale writes from overwriting final history or resurrecting deleted files.
- Clipboard polling and menu rebuilding defer while a paste request is active. Selection starts paste before rebuilding a reordered menu. The deferred menu update resumes on main after completion or cancellation. Snippet and transformed action outputs remain unacknowledged for normal capture after paste, preserving history filters and excluded-app behavior.
- Capture saves and timer autosaves use background persistence. Save failures keep history dirty for retry; a background failure cannot open a focus-stealing alert during a newer paste. The existing exact-destination, physical-modifier, menu, deadline, and single-dispatch guards remain.

### Beta 4 validation

| Check | Result |
| --- | --- |
| Debug build | **Passed.** `build/menu-keyboard-paste-beta4-debug.log`. |
| Full Testing unit suite | **111 passed, 0 failures.** `build/menu-keyboard-paste-beta4-unit.log`. No compiler warnings. The deliberate semaphore-blocked writer fixture produced one Thread Performance Checker priority-inversion warning; production paste does not wait on that semaphore. |
| Clipboard ownership/controller regressions | **Passed, 9 new cases.** Real selection and polling on named pasteboards: exact ownership token; no recapture/rebuild for existing clips; reordering on/off; later external copy; snippet capture; pending-paste capture deferral; eventual menu rebuild; excluded-app and disabled-type behavior. Preferences, the shared controller, and named boards are restored/released by fixtures. |
| Background persistence regressions | **Passed, 8 new cases.** Main work executes with a deliberately blocked writer; same-revision requests share a write; older completion preserves newer dirty state; final save/delete/load order after queued writes; destination is captured and changing it preserves dirty state; failure remains dirty and retries. Temporary directories and writer gates are cleaned up. |
| Source review | Deferred rebuild has both a waking AppKit callback and a retained main-queue fallback, so wake expiry cannot permanently drop cleanup. Both use the same flag guard. Snapshot preparation retains value data and computes ordering on main; JSON, image archive construction, and writes run exclusively on the serial worker. Autosave allows only one outstanding request, and failures cannot steal focus from a pending paste. |
| Universal Release build | **Passed** for `arm64` and `x86_64`, version **0.5.2-beta.4**, build **6.2.4**. `build/menu-keyboard-paste-beta4-release.log`; no compiler warnings. |
| Delivered package | **Verified after extraction.** Ad-hoc host/nested signatures, both architectures, version/build, `CMApplication` principal class, unchanged update feed/public key, bounded diagnostic flag, and license notices. `build/menu-keyboard-paste-beta4-package.log` and `build/menu-keyboard-paste-beta4/verification.json`. |
| Affected MacBook Air | **User-confirmed working with beta 4.** After receiving the verified package and the Safari Command–1 retest instructions, the user reported “it works now.” This confirms resolution of the reported failure on the affected setup (MacBook Air, macOS 27.0.1, Safari address bar). No temporary Accessibility grant was added locally. |

The affected-machine result is the user's beta 4 confirmation, alongside the 111 passing local regressions. Mouse selection, hotkey-menu selection, TextEdit, and the other extended cases were not separately reported in that confirmation and remain additional coverage.

## 0.5.2 release validation

The stable release uses version `0.5.2`, build `6.2.99`, with the production app source and principal-class setting unchanged from the user-confirmed beta 4. The local production candidate built from clean commit `0127a3c0173cc5845c68725c97876985849d8954` passed universal architecture, ad-hoc and nested signature, bundle version, license, and extracted-package checks. Its normal Info.plist does not enable menu-paste diagnostics. All 27 release-helper tests passed, including the official Sparkle signing round trip with a fixed test key.

The initial hosted Validate runs (`38152977292` and `38152989069`) passed Debug compilation but failed three scheduling tests. Two assumed one embedded CF wait would last until a 10 ms background trigger; on the hosted runner, a wait could finish or stop after 4–5 ms. The AppKit event-wait test could instead accept a delayed private wake from an earlier test while its own callback had not run.

The test harness now keeps bounded waits in the same requested mode, uses a nonfiring keep-alive timer, and identifies the delayed AppKit probe by its exact callback ID under a lock. Main-thread, deadline, and exactly-once assertions remain. This correction changes test synchronization only and sends no keyboard or mouse input. Final hosted results are recorded in the checks on [PR #4](https://github.com/frank4565/ClipMenu/pull/4).

The corrected full local suite passed **111 tests with no failures** (`build/release-0.5.2-unit-final.log`), including deliberate early stops and an already-claimed stale wake event in the affected regressions.

## MacBook Air follow-up

Quit the existing app before replacing it with the test app. Confirm **0.5.2-beta.4** in About and **Granted** for Accessibility in General. This package is for validation of the revised source and has bounded diagnostics enabled.

Previous beta 1 archive: `build/menu-keyboard-paste-beta1/ClipMenu-0.5.2-beta.1-menu-paste-test.zip`, 3,400,618 bytes. SHA-256: `d3f48ea2b8341af4f97e94d90b7b84abf94a9a62703d16e0750665f8ecc64eab`. Verification metadata: `build/menu-keyboard-paste-beta1/verification.json`.

Beta 2 archive: `build/menu-keyboard-paste-beta2/ClipMenu-0.5.2-beta.2-menu-paste-test.zip`, 3,406,689 bytes. SHA-256: `421806145b74c49c851c438ab69c271875b56ec49c1e3133ae241cfe04086cae`. The source diff SHA-256 recorded in its verification metadata is `c6ad9e6017752c18c6b6da66e52644b7414dc9f96adfeeb2a6a93a40a81061a3`. This is an unpublished test package; no release tag or GitHub publication was created.

Previous beta 3 archive: `build/menu-keyboard-paste-beta3/ClipMenu-0.5.2-beta.3-menu-paste-test.zip`, 3,420,858 bytes. SHA-256: `50d49396ec16219780f85188877147ed1a40f3fa2e417a55ce123e25ba61742f`. Verification metadata includes `Source/AppController.swift` and `Info.plist` in source diff SHA-256 `a249155cabc54d0256dbcbdcb705596b51cd9d47dac8c6065e35789de790ed81`. No release tag, GitHub publication, or source commit was created for this test package.

Current beta 4 archive: `build/menu-keyboard-paste-beta4/ClipMenu-0.5.2-beta.4-menu-paste-test.zip`, 3,438,217 bytes. SHA-256: `8219ee8658d717ed1e17f38a445347669b87f9672a7bd03d58818ff87deae921`. Verification metadata includes `Source/AppController.swift` and `Info.plist` in source diff SHA-256 `ab8113b9787ef905d2cee3f3475e8e92f0231bc8d45a565333419adf0fa719d7`. No release tag, GitHub publication, or source commit was created for this test package.

Run CM-PASTE-008 and CM-PASTE-012 through CM-PASTE-015 on macOS 27.0.1 using both status-menu and hotkey-menu selection. For Safari, focus the address bar, select by mouse or Command–1, release the keys, then provide no keyboard, mouse, or activation input while checking whether the text appears. Check that Command–1 closes the menu and selects once, subsequent typing behaves normally, and Command-click actions still work. Repeat automatic paste into TextEdit. Preserve the diagnostic stage log if either failure remains.
