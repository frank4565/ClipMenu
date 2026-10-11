import AppKit
import Carbon
import XCTest
@testable import ClipMenu

private final class WeakProbeReference {
    weak var object: NSObject?

    init(_ object: NSObject?) {
        self.object = object
    }
}

final class PreferenceNormalizationTests: XCTestCase {
    func testPasteKeyboardEventsReleaseCommandAndUseCapturedLayoutKey() throws {
        let keyCode = CGKeyCode(kVK_ANSI_B)
        let events = try XCTUnwrap(CMMakePasteKeyboardEvents(keyCode: keyCode))
        XCTAssertEqual(events.map(\.type), [.flagsChanged, .keyDown, .keyUp, .flagsChanged])
        XCTAssertEqual(events.map { $0.getIntegerValueField(.keyboardEventKeycode) },
                       [Int64(kVK_Command), Int64(keyCode), Int64(keyCode), Int64(kVK_Command)])
        XCTAssertEqual(events.map(\.flags), [.maskCommand, .maskCommand, .maskCommand, []])
    }

    func testPasteWaitsForPhysicalModifiersAndTheExactTargetProcess() {
        func canPaste(target: pid_t? = 42, frontmost: pid_t? = 42,
                      released: Bool = true, tracking: Bool = false) -> Bool {
            CMCanDispatchPaste(targetProcessIdentifier: target,
                               frontmostProcessIdentifier: frontmost,
                               clipMenuProcessIdentifier: 7,
                               modifiersReleased: released,
                               menuIsTracking: tracking)
        }
        XCTAssertTrue(canPaste())
        XCTAssertFalse(canPaste(released: false))
        XCTAssertFalse(canPaste(tracking: true))
        XCTAssertFalse(canPaste(frontmost: 43))
        XCTAssertFalse(canPaste(frontmost: 7))
        XCTAssertFalse(canPaste(frontmost: nil))
        XCTAssertFalse(canPaste(target: nil))
        XCTAssertFalse(canPaste(target: nil, frontmost: 7))
        XCTAssertFalse(CMCanDispatchPaste(targetProcessIdentifier: 42,
                                         frontmostProcessIdentifier: 42,
                                         clipMenuProcessIdentifier: 7,
                                         modifiersReleased: true, menuIsTracking: false,
                                         requestDeadline: 100, now: 100.1))
    }

    @MainActor
    func testPasteReadinessDeadlineRunsWhileMainThreadIsBlocked() {
        let triggered = DispatchSemaphore(value: 0)
        CMTriggerPasteReadinessAfterDelay(0.01) {
            XCTAssertFalse(Thread.isMainThread)
            triggered.signal()
        }
        // Deliberately prevent all main run-loop timers and main-queue blocks
        // from progressing. The deadline must still fire independently.
        XCTAssertEqual(triggered.wait(timeout: .now() + 0.5), .success)
    }

    @MainActor
    func testPasteReadinessWakesAnActualAppKitEventWait() throws {
        XCTAssertTrue(NSApp is CMApplication)
        // Remove previous tests' wake events before starting the timed wait.
        while let event = NSApp.nextEvent(matching: .applicationDefined, until: .distantPast,
                                         inMode: .default, dequeue: true) {
            NSApp.sendEvent(event)
        }
        let privateWakeMarker = try XCTUnwrap(CMMakeAppKitWorkWakeEvent(identifier: 0))
        var callbackCount = 0
        var receivedPrivateWake = false
        let started = ProcessInfo.processInfo.systemUptime
        CMSchedulePasteReadinessCheck(after: 0.01) {
            XCTAssertTrue(Thread.isMainThread)
            callbackCount += 1
        }
        let deadline = Date(timeIntervalSinceNow: 0.5)
        // Exercise AppKit's event queue instead of supplying CF run-loop ticks.
        // A CF fallback callback alone cannot satisfy this test: a new private
        // wake event must actually arrive and interrupt the AppKit queue wait.
        while !receivedPrivateWake && Date() < deadline {
            guard let event = NSApp.nextEvent(matching: .applicationDefined, until: deadline,
                                             inMode: .default, dequeue: true) else { break }
            receivedPrivateWake = event.subtype == privateWakeMarker.subtype
                && event.data1 == privateWakeMarker.data1 && event.data2 > 0
            NSApp.sendEvent(event)
        }
        XCTAssertTrue(receivedPrivateWake)
        XCTAssertEqual(callbackCount, 1)
        XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - started, 0.4)
        CFRunLoopRunInMode(.defaultMode, 0.02, false)
        XCTAssertEqual(callbackCount, 1)
    }

    @MainActor
    func testAppKitWorkEventAndCFFallbackDeliverOnlyOnce() throws {
        XCTAssertTrue(NSApp is CMApplication)
        var callbackCount = 0
        let identifier = CMPerformAfterMenuTracking {
            XCTAssertTrue(Thread.isMainThread)
            callbackCount += 1
        }
        let event = try XCTUnwrap(CMMakeAppKitWorkWakeEvent(identifier: identifier))
        NSApp.sendEvent(event)
        NSApp.sendEvent(event)
        XCTAssertEqual(callbackCount, 1)
        CFRunLoopRunInMode(.defaultMode, 0.02, false)
        XCTAssertEqual(callbackCount, 1)
    }

    @MainActor
    func testAppKitWorkCFFallbackWinsBeforeTheQueuedWakeEvent() throws {
        var callbackCount = 0
        let identifier = CMPerformAfterMenuTracking { callbackCount += 1 }
        CFRunLoopRunInMode(.defaultMode, 0.02, false)
        XCTAssertEqual(callbackCount, 1)
        NSApp.sendEvent(try XCTUnwrap(CMMakeAppKitWorkWakeEvent(identifier: identifier)))
        XCTAssertEqual(callbackCount, 1)
    }

    @MainActor
    func testUnrelatedAppKitEventsDoNotClaimPendingWork() throws {
        var callbackCount = 0
        let identifier = CMPerformAfterMenuTracking { callbackCount += 1 }
        let unrelated = try XCTUnwrap(NSEvent.otherEvent(with: .applicationDefined, location: .zero,
                                                       modifierFlags: [], timestamp: 0, windowNumber: 0,
                                                       context: nil, subtype: 0, data1: 0, data2: identifier))
        XCTAssertFalse(CMHandleAppKitWorkWakeEvent(unrelated))
        NSApp.sendEvent(unrelated)
        XCTAssertEqual(callbackCount, 0)
        NSApp.sendEvent(try XCTUnwrap(CMMakeAppKitWorkWakeEvent(identifier: identifier)))
        XCTAssertEqual(callbackCount, 1)
    }

    @MainActor
    func testAppKitWorkExpiresAndReleasesItsClosureWhileMainIsBlocked() throws {
        var probe: NSObject? = NSObject()
        let retainedProbe = WeakProbeReference(probe)
        var callbackCount = 0
        let identifier = CMPerformAfterMenuTracking(expiresAfter: 0.01) { [capturedProbe = probe!] in
            withExtendedLifetime(capturedProbe) { callbackCount += 1 }
        }
        probe = nil
        XCTAssertNotNil(retainedProbe.object)
        let expiryFinished = DispatchSemaphore(value: 0)
        CMTriggerPasteReadinessAfterDelay(0.08) { expiryFinished.signal() }
        // No main run-loop processing occurs while the registry expiry runs.
        XCTAssertEqual(expiryFinished.wait(timeout: .now() + 0.5), .success)
        XCTAssertNil(retainedProbe.object)
        NSApp.sendEvent(try XCTUnwrap(CMMakeAppKitWorkWakeEvent(identifier: identifier)))
        CFRunLoopRunInMode(.defaultMode, 0.02, false)
        XCTAssertEqual(callbackCount, 0)
    }

    @MainActor
    func testPasteReadinessRunsOnMainWhileDefaultLoopIsIdle() {
        var callbackCount = 0
        CMSchedulePasteReadinessCheck(after: 0.01) {
            XCTAssertTrue(Thread.isMainThread)
            callbackCount += 1
        }
        // One continuous wait supplies no polling ticks or physical input.
        CFRunLoopRunInMode(.defaultMode, 0.3, false)
        XCTAssertEqual(callbackCount, 1)
    }

    @MainActor
    func testPasteHandoffAndReadinessRunWhileTrackingLoopIsIdle() {
        let trackingMode = CFRunLoopMode(rawValue: RunLoop.Mode.eventTracking.rawValue as CFString)
        CFRunLoopAddCommonMode(CFRunLoopGetMain(), trackingMode)
        var handoffRan = false
        var readinessCount = 0
        CMPerformAfterMenuTracking { handoffRan = true }
        CMSchedulePasteReadinessCheck(after: 0.01) {
            XCTAssertTrue(Thread.isMainThread)
            readinessCount += 1
        }
        // AppKit can remain in this mode after visually closing the menu. Both
        // stages must progress during a continuous idle wait, without polling,
        // a transition to default, or another keyboard/mouse event.
        CFRunLoopRunInMode(trackingMode, 0.3, false)
        XCTAssertTrue(handoffRan)
        XCTAssertEqual(readinessCount, 1)
    }

    @MainActor
    func testMenuPasteWorkRunsInTheCurrentCustomMode() {
        let mode = CFRunLoopMode(rawValue: "ClipMenuIdleTrackingRegression" as CFString)
        var scheduled = false
        var handoffRan = false
        var readinessCount = 0
        var entryMode = "none"
        var afterSchedulingMode = "none"
        let observer = CFRunLoopObserverCreateWithHandler(nil, CFRunLoopActivity.entry.rawValue, false, 0) { _, _ in
            entryMode = CFRunLoopCopyCurrentMode(CFRunLoopGetMain()).map { $0.rawValue as String } ?? "none"
            scheduled = true
            CMPerformAfterMenuTracking { handoffRan = true }
            CMSchedulePasteReadinessCheck(after: 0.01) {
                XCTAssertTrue(Thread.isMainThread)
                readinessCount += 1
            }
            afterSchedulingMode = CFRunLoopCopyCurrentMode(CFRunLoopGetMain()).map { $0.rawValue as String } ?? "none"
        }!
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, mode)
        let keepAlive = Timer(timeInterval: 10, repeats: false) { _ in }
        RunLoop.main.add(keepAlive, forMode: RunLoop.Mode(mode.rawValue as String))
        defer { keepAlive.invalidate() }
        // This mode is deliberately absent from the common set. The keep-alive
        // timer never fires; only the background trigger can wake this wait.
        let result = CFRunLoopRunInMode(mode, 0.3, false)
        CFRunLoopRemoveObserver(CFRunLoopGetMain(), observer, mode)
        XCTAssertTrue(scheduled)
        let context = "runResult=\(result.rawValue) entryMode=\(entryMode) afterSchedulingMode=\(afterSchedulingMode)"
        XCTAssertEqual(entryMode, mode.rawValue as String, context)
        XCTAssertEqual(afterSchedulingMode, mode.rawValue as String, context)
        XCTAssertTrue(handoffRan, context)
        XCTAssertEqual(readinessCount, 1, context)
    }

#if DEBUG || TESTING
    @MainActor
    func testBackgroundPasteWithCapturedKeyDoesNotWaitForMainQueue() throws {
        let defaults = UserDefaults.standard
        let key = "debugBypassDirectPasteSynthesisForTesting"
        let original = defaults.object(forKey: key)
        defer {
            if let original { defaults.set(original, forKey: key) }
            else { defaults.removeObject(forKey: key) }
        }
        defaults.set(true, forKey: key)
        let controller = try XCTUnwrap(NSApp.delegate as? AppController)
        let completed = DispatchSemaphore(value: 0)
        controller.debugDispatchResolvedPasteForTesting(keyCode: CGKeyCode(kVK_ANSI_V)) {
            completed.signal()
        }
        // Deliberately keep main occupied, as it is in a synchronous menu popup.
        XCTAssertEqual(completed.wait(timeout: .now() + 0.5), .success)
    }
#endif

    func testMenuCountAndLengthPreferencesClampToSafeMinimums() {
        XCTAssertEqual(CMNormalizedLegacyMenuTooltipLength(-40), 1)
        XCTAssertEqual(CMNormalizedLegacyMenuTitleLength(0), 1)
        XCTAssertEqual(CMNormalizedLegacyMenuFolderItemsCount(-1), 1)
        XCTAssertEqual(CMNormalizedLegacyMenuInlineItemsCount(-1), 0)
        XCTAssertEqual(CMNormalizedLegacyMaxHistorySize(0), 1)
        XCTAssertEqual(CMNormalizedLegacyThumbnailDimension(-100), 1)
    }

    func testNearestOptionPreferencesChooseSupportedValues() {
        XCTAssertEqual(CMNormalizedMenuLegacyFontSize(8), 9)
        XCTAssertEqual(CMNormalizedMenuLegacyFontSize(20), 16)
        XCTAssertEqual(CMNormalizedMenuLegacyFontSize(40), 32)
        XCTAssertEqual(CMNormalizedTypeLegacyMenuIconSize(40), 32)
        XCTAssertEqual(CMNormalizedTypeLegacyMenuIconSize(47), 48)
        XCTAssertEqual(CMNormalizedLegacyAutosaveDelay(61), 60)
        XCTAssertEqual(CMNormalizedLegacyAutosaveDelay(100_000), 86_400)
    }

    func testEnumeratedPreferencesRejectUnknownValues() {
        XCTAssertEqual(CMNormalizedMenuLegacyFontSizingMode(99), 0)
        XCTAssertEqual(CMNormalizedTypeFileIconSelectionTag(-1), 0)
        XCTAssertEqual(CMNormalizedStatusItemSelectionTag(-1), 1)
        XCTAssertEqual(CMNormalizedStatusItemSelectionTag(13), 1)
        XCTAssertEqual(CMNormalizedLegacyExportSeparatorTag(6), 1)
        XCTAssertEqual(CMNormalizedLegacySnippetPosition(99), CMPositionOfSnippets.belowClips.rawValue)
    }

    func testBooleanPreferencesPreserveLegacyNumberValues() {
        XCTAssertTrue(CMNormalizedLegacyExportHistoryAsSingleFileValue(nil))
        XCTAssertTrue(CMNormalizedLegacyExportHistoryAsSingleFileValue(NSNumber(value: 2)))
        XCTAssertTrue(CMNormalizedLegacyExportHistoryAsSingleFileValue(1))
        XCTAssertFalse(CMNormalizedLegacyExportHistoryAsSingleFileValue(0))

        XCTAssertTrue(CMNormalizedLegacyReorderClipsAfterPastingValue(nil))
        XCTAssertTrue(CMNormalizedLegacyReorderClipsAfterPastingValue(NSNumber(value: 2)))
        XCTAssertTrue(CMNormalizedLegacyReorderClipsAfterPastingValue(true))
        XCTAssertFalse(CMNormalizedLegacyReorderClipsAfterPastingValue(false))
    }

    func testFileIconPreferenceNormalizesExtensionsAndLegacyTypeCodes() {
        XCTAssertEqual(
            CMNormalizedMenuIconFileTypeValue("  txt  ", defaultValue: "TEXT", selectionTag: 0),
            "txt"
        )
        XCTAssertEqual(
            CMNormalizedMenuIconFileTypeValue(nil, defaultValue: "TEXT", selectionTag: 0),
            "TEXT"
        )
        XCTAssertEqual(
            CMNormalizedMenuIconFileTypeValue("A", defaultValue: "TEXT", selectionTag: 1),
            "A   "
        )
        XCTAssertEqual(
            CMNormalizedMenuIconFileTypeValue("ABCDE", defaultValue: "TEXT", selectionTag: 1),
            "ABCD"
        )
    }

#if TESTING
    func testExcludedApplicationDictionariesNormalizeSupportedShapes() {
        let dictionaries = CMDebugExcludedAppDictionariesForTesting(from: [
            ["bundleIdentifier": "com.example.swift", "name": "Swift App"],
            NSDictionary(dictionary: ["bundleIdentifier": "com.example.ns", "name": "NSDictionary App"]),
            NSDictionary(dictionary: ["bundleIdentifier": ""]),
            "invalid"
        ])

        XCTAssertEqual(dictionaries.count, 2)
        XCTAssertEqual(dictionaries[0]["bundleIdentifier"], "com.example.swift")
        XCTAssertEqual(dictionaries[1]["name"], "NSDictionary App")
    }

    @MainActor
    func testMenuIconPreferencesCoverSupportedPasteboardTypes() {
        let preferences = AppController().debugMenuIconPreferencesForTesting()
        XCTAssertEqual(preferences.count, 9)
        XCTAssertEqual(preferences.compactMap { $0["defaultFileType"] as? String }.filter { !$0.isEmpty }.count, 8)
        XCTAssertEqual(preferences.last?["defaultFileType"] as? String, "")
    }

    @MainActor
    func testHotKeyRecorderExerciseCoversCaptureAndDisplayStates() {
        let report = CMHotKeyRecorderExerciseForTesting()
        let captures = report["captures"] as? [[String: Int]]
        XCTAssertEqual(captures?.count, 2)
        XCTAssertEqual(captures?.first?["keyCode"], -1)
        XCTAssertEqual(captures?.last?["keyCode"], kVK_ANSI_V)
        XCTAssertEqual(report["fallbackKeyName"] as? String, "Key 999")
        XCTAssertTrue((report["commandDisplay"] as? String)?.contains("V") == true)
    }
#endif

#if DEBUG
    @MainActor
    func testRememberingSelectedPaneDoesNotReapplyPreferences() {
        let defaults = UserDefaults.standard
        let originalSelection = defaults.object(forKey: CMSelectedPreferencePaneKey)
        defer {
            if let originalSelection {
                defaults.set(originalSelection, forKey: CMSelectedPreferencePaneKey)
            } else {
                defaults.removeObject(forKey: CMSelectedPreferencePaneKey)
            }
        }

        let controller = AppController()
        let initialGenerations = controller.debugUserDefaultsApplicationGenerations()
        for tab in PreferenceTab.allCases {
            defaults.set(tab.rawValue, forKey: CMSelectedPreferencePaneKey)
            controller.debugUserDefaultsDidChangeForTesting()
            XCTAssertEqual(defaults.string(forKey: CMSelectedPreferencePaneKey), tab.rawValue)
            XCTAssertEqual(controller.debugUserDefaultsApplicationGenerations(), initialGenerations)
        }
        controller.debugUserDefaultsDidChangeForTesting()
        XCTAssertEqual(controller.debugUserDefaultsApplicationGenerations(), initialGenerations)
    }

    @MainActor
    func testChangedShortcutPreferenceStillAppliesOnce() {
        let defaults = UserDefaults.standard
        let keys = [
            CMPrefHotKeyEnabledKey,
            CMPrefHistoryHotKeyEnabledKey,
            CMPrefSnippetsHotKeyEnabledKey,
            CMPrefHotKeyKeyCodeKey,
            CMPrefTimeIntervalKey,
            CMPrefAutosaveDelayKey
        ]
        let originals = Dictionary(uniqueKeysWithValues: keys.map { ($0, defaults.object(forKey: $0)) })
        defer {
            for (key, value) in originals {
                if let value {
                    defaults.set(value, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
        }

        // Exercise the normal application pass without claiming system shortcuts
        // or starting clipboard/autosave timers in this isolated controller.
        defaults.set(false, forKey: CMPrefHotKeyEnabledKey)
        defaults.set(false, forKey: CMPrefHistoryHotKeyEnabledKey)
        defaults.set(false, forKey: CMPrefSnippetsHotKeyEnabledKey)
        defaults.set(0.0, forKey: CMPrefTimeIntervalKey)
        defaults.set(0, forKey: CMPrefAutosaveDelayKey)
        let controller = AppController()
        let initialGenerations = controller.debugUserDefaultsApplicationGenerations()

        let nextKeyCode = defaults.integer(forKey: CMPrefHotKeyKeyCodeKey) == kVK_ANSI_V
            ? kVK_ANSI_B : kVK_ANSI_V
        defaults.set(nextKeyCode, forKey: CMPrefHotKeyKeyCodeKey)
        controller.debugUserDefaultsDidChangeForTesting()

        let appliedGenerations = controller.debugUserDefaultsApplicationGenerations()
        XCTAssertEqual(appliedGenerations["applicationWork"], initialGenerations["applicationWork"].map { $0 + 1 })
        XCTAssertEqual(appliedGenerations["hotKeyRegistration"], initialGenerations["hotKeyRegistration"].map { $0 + 1 })
        XCTAssertEqual(defaults.integer(forKey: CMPrefHotKeyKeyCodeKey), nextKeyCode)
        controller.debugUserDefaultsDidChangeForTesting()
        XCTAssertEqual(controller.debugUserDefaultsApplicationGenerations(), appliedGenerations)
    }

    @MainActor
    func testUserDefaultsDidChangeNormalizesStoredPreferences() {
        let defaults = UserDefaults.standard
        let keys: [String] = [
            CMPrefTimeIntervalKey,
            CMPrefTagOfSeparatorForExportHistoryToFileKey,
            CMPrefExportHistoryAsSingleFileKey,
            CMPrefReorderClipsAfterPasting,
            CMPrefPositionOfSnippetsKey,
            CMPrefMaxHistorySizeKey,
            CMPrefAutosaveDelayKey,
            CMPrefThumbnailWidthKey,
            CMPrefThumbnailHeightKey,
            CMPrefHowToChangeFontSizeKey,
            CMPrefMaxLengthOfToolTipKey,
            CMPrefMaxMenuItemTitleLengthKey,
            CMPrefNumberOfItemsPlaceInsideFolderKey,
            CMPrefNumberOfItemsPlaceInlineKey,
            CMEnableAutomaticCheckKey,
            CMUpdateCheckIntervalKey
        ]
        let originals = Dictionary(uniqueKeysWithValues: keys.map { ($0, defaults.object(forKey: $0)) })
        defer {
            for (key, value) in originals {
                if let value {
                    defaults.set(value, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
        }

        let controller = AppController()
        defaults.set(-10.0, forKey: CMPrefTimeIntervalKey)
        defaults.set(99, forKey: CMPrefTagOfSeparatorForExportHistoryToFileKey)
        defaults.set("yes", forKey: CMPrefExportHistoryAsSingleFileKey)
        defaults.set("no", forKey: CMPrefReorderClipsAfterPasting)
        defaults.set(99, forKey: CMPrefPositionOfSnippetsKey)
        defaults.set(0, forKey: CMPrefMaxHistorySizeKey)
        defaults.set(100_000, forKey: CMPrefAutosaveDelayKey)
        defaults.set(-1, forKey: CMPrefThumbnailWidthKey)
        defaults.set(-2, forKey: CMPrefThumbnailHeightKey)
        defaults.set(99, forKey: CMPrefHowToChangeFontSizeKey)
        defaults.set(-1, forKey: CMPrefMaxLengthOfToolTipKey)
        defaults.set(0, forKey: CMPrefMaxMenuItemTitleLengthKey)
        defaults.set(0, forKey: CMPrefNumberOfItemsPlaceInsideFolderKey)
        defaults.set(-1, forKey: CMPrefNumberOfItemsPlaceInlineKey)
        defaults.set(false, forKey: CMEnableAutomaticCheckKey)
        defaults.set(0, forKey: CMUpdateCheckIntervalKey)

        controller.debugUserDefaultsDidChangeForTesting()

        XCTAssertEqual(defaults.integer(forKey: CMPrefMaxHistorySizeKey), 1)
        XCTAssertEqual(defaults.integer(forKey: CMPrefAutosaveDelayKey), 86_400)
        XCTAssertEqual(defaults.integer(forKey: CMPrefThumbnailWidthKey), 1)
        XCTAssertEqual(defaults.integer(forKey: CMPrefMaxLengthOfToolTipKey), 1)
        XCTAssertEqual(defaults.integer(forKey: CMPrefNumberOfItemsPlaceInlineKey), 0)
        let appliedGenerations = controller.debugUserDefaultsApplicationGenerations()
        XCTAssertEqual(appliedGenerations["applicationWork"], 1)
        controller.debugUserDefaultsDidChangeForTesting()
        XCTAssertEqual(controller.debugUserDefaultsApplicationGenerations(), appliedGenerations)
    }
#endif
}
