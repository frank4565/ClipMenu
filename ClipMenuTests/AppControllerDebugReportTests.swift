import AppKit
import Carbon
import XCTest
@testable import ClipMenu

#if DEBUG
// This probe exposes only the controller's lock-protected activity state to a
// background assertion; the controller's AppKit operations remain on main.
private struct PasteActivityProbe: @unchecked Sendable {
    private let controller: AppController

    init(_ controller: AppController) {
        self.controller = controller
    }

    var isActive: Bool { controller.debugPasteActivityIsActiveForTesting }
}

@MainActor
final class PasteActivityLifetimeTests: XCTestCase {
    func testActivityWatchdogReleasesWhileMainThreadIsBlocked() {
        let controller = AppController()
        let generation = controller.debugBeginPasteActivityForTesting(duration: 0.03)
        defer { controller.debugFinishPasteActivityForTesting(generation: generation) }
        XCTAssertTrue(controller.debugPasteActivityIsActiveForTesting)
        let probe = PasteActivityProbe(controller)
        let released = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .userInitiated).async {
            let deadline = ProcessInfo.processInfo.systemUptime + 1
            while probe.isActive,
                  ProcessInfo.processInfo.systemUptime < deadline {
                Thread.sleep(forTimeInterval: 0.005)
            }
            released.signal()
        }
        // This deliberately blocks main; expiry must be independent of the
        // UI loop whose delayed callbacks caused the affected-machine bug.
        XCTAssertEqual(released.wait(timeout: .now() + 2), .success)
        XCTAssertFalse(controller.debugPasteActivityIsActiveForTesting)
    }

    func testSupersededWatchdogCannotEndNewPasteActivity() {
        let controller = AppController()
        let oldGeneration = controller.debugBeginPasteActivityForTesting(duration: 0.02)
        let newGeneration = controller.debugBeginPasteActivityForTesting(duration: 2)
        defer { controller.debugFinishPasteActivityForTesting(generation: newGeneration) }
        controller.debugFinishPasteActivityForTesting(generation: oldGeneration)
        let oldDeadlinePassed = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.1) {
            oldDeadlinePassed.signal()
        }
        XCTAssertEqual(oldDeadlinePassed.wait(timeout: .now() + 1), .success)
        XCTAssertTrue(controller.debugPasteActivityIsActiveForTesting)
        controller.debugFinishPasteActivityForTesting(generation: newGeneration)
        XCTAssertFalse(controller.debugPasteActivityIsActiveForTesting)
    }

    func testFinishedActivityStaysReleasedOnRepeatedCompletion() {
        let controller = AppController()
        let generation = controller.debugBeginPasteActivityForTesting(duration: 2)
        controller.debugFinishPasteActivityForTesting(generation: generation)
        controller.debugFinishPasteActivityForTesting(generation: generation)
        XCTAssertFalse(controller.debugPasteActivityIsActiveForTesting)
    }
}

@MainActor
final class AppControllerClipboardOwnershipTests: XCTestCase {
    func testSelectingExistingClipWithoutReorderingDoesNotRecaptureOrRebuild() throws {
        try withController { controller, pasteboard in
            let history = fixtureHistory()
            controller.debugReplaceHistoryClipsForTesting(history)
            let rebuildCount = controller.debugMenuRebuildCountForTesting

            controller.debugSelectHistoryClipForTesting(history[0].id)

            XCTAssertEqual(pasteboard.string(forType: .string), history[0].text)
            XCTAssertEqual(controller.debugHistoryClipsForTesting, history)
            XCTAssertEqual(controller.debugMenuRebuildCountForTesting, rebuildCount)
            controller.debugPollClipboardForTesting()
            controller.debugPollClipboardForTesting()
            XCTAssertEqual(controller.debugClipboardCaptureCountForTesting, 0)
            XCTAssertEqual(controller.debugMenuRebuildCountForTesting, rebuildCount)
            XCTAssertEqual(controller.debugHistoryClipsForTesting, history)
        }
    }

    func testSelectingExistingClipWithReorderingPromotesItWithoutRecapture() throws {
        try withController { controller, pasteboard in
            UserDefaults.standard.set(true, forKey: CMPrefReorderClipsAfterPasting)
            let history = fixtureHistory()
            controller.debugReplaceHistoryClipsForTesting(history)
            let rebuildCount = controller.debugMenuRebuildCountForTesting

            controller.debugSelectHistoryClipForTesting(history[0].id)

            let promotedHistory = controller.debugHistoryClipsForTesting
            let promotedClip = try XCTUnwrap(promotedHistory.first { $0.id == history[0].id })
            XCTAssertEqual(pasteboard.string(forType: .string), history[0].text)
            XCTAssertEqual(promotedHistory.map(\.id), history.map(\.id))
            XCTAssertGreaterThan(promotedClip.lastUsedAt, history[1].lastUsedAt)
            XCTAssertEqual(promotedClip.createdAt, history[0].createdAt)
            XCTAssertEqual(promotedHistory[1], history[1])
            XCTAssertEqual(controller.debugMenuRebuildCountForTesting, rebuildCount + 1)

            controller.debugPollClipboardForTesting()
            controller.debugPollClipboardForTesting()

            XCTAssertEqual(controller.debugClipboardCaptureCountForTesting, 0)
            XCTAssertEqual(controller.debugMenuRebuildCountForTesting, rebuildCount + 1)
            XCTAssertEqual(controller.debugHistoryClipsForTesting, promotedHistory)
        }
    }

    func testForeignCopyAfterHistorySelectionIsCapturedExactlyOnce() throws {
        try withController { controller, pasteboard in
            let history = fixtureHistory()
            controller.debugReplaceHistoryClipsForTesting(history)
            controller.debugSelectHistoryClipForTesting(history[0].id)
            controller.debugPollClipboardForTesting()
            let rebuildCount = controller.debugMenuRebuildCountForTesting
            let externalWriter = NSPasteboard(name: pasteboard.name)
            externalWriter.clearContents()
            XCTAssertTrue(externalWriter.setString("Foreign copy after selection", forType: .string))

            controller.debugPollClipboardForTesting()

            let capturedHistory = controller.debugHistoryClipsForTesting
            XCTAssertEqual(capturedHistory.prefix(history.count).map(\.id), history.map(\.id))
            XCTAssertEqual(capturedHistory.last?.text, "Foreign copy after selection")
            XCTAssertEqual(capturedHistory.count, history.count + 1)
            XCTAssertEqual(controller.debugClipboardCaptureCountForTesting, 1)
            XCTAssertEqual(controller.debugMenuRebuildCountForTesting, rebuildCount + 1)

            controller.debugPollClipboardForTesting()

            XCTAssertEqual(controller.debugHistoryClipsForTesting, capturedHistory)
            XCTAssertEqual(controller.debugClipboardCaptureCountForTesting, 1)
            XCTAssertEqual(controller.debugMenuRebuildCountForTesting, rebuildCount + 1)
        }
    }

    func testSnippetOutputStillEntersHistoryThroughClipboardPolling() throws {
        try withController { controller, pasteboard in
            let history = fixtureHistory()
            controller.debugReplaceHistoryClipsForTesting(history)
            let rebuildCount = controller.debugMenuRebuildCountForTesting

            controller.debugSelectSnippetForTesting("Snippet output remains capturable")

            XCTAssertEqual(pasteboard.string(forType: .string), "Snippet output remains capturable")
            XCTAssertEqual(controller.debugHistoryClipsForTesting, history)
            XCTAssertEqual(controller.debugClipboardCaptureCountForTesting, 0)
            XCTAssertEqual(controller.debugMenuRebuildCountForTesting, rebuildCount)

            controller.debugPollClipboardForTesting()

            let capturedHistory = controller.debugHistoryClipsForTesting
            XCTAssertEqual(capturedHistory.last?.text, "Snippet output remains capturable")
            XCTAssertEqual(capturedHistory.count, history.count + 1)
            XCTAssertEqual(controller.debugClipboardCaptureCountForTesting, 1)
            XCTAssertEqual(controller.debugMenuRebuildCountForTesting, rebuildCount + 1)
            controller.debugPollClipboardForTesting()
            XCTAssertEqual(controller.debugHistoryClipsForTesting, capturedHistory)
            XCTAssertEqual(controller.debugClipboardCaptureCountForTesting, 1)
        }
    }

    func testPendingPasteDefersPollingWithoutAcknowledgingForeignCopy() throws {
        try withController { controller, pasteboard in
            let history = fixtureHistory()
            controller.debugReplaceHistoryClipsForTesting(history)
            let rebuildCount = controller.debugMenuRebuildCountForTesting
            let generation = controller.debugBeginPasteActivityForTesting(duration: 2)
            defer { controller.debugFinishPasteActivityForTesting(generation: generation) }
            let externalWriter = NSPasteboard(name: pasteboard.name)
            externalWriter.clearContents()
            XCTAssertTrue(externalWriter.setString("Copy while paste is pending", forType: .string))

            controller.debugPollClipboardForTesting()
            controller.debugPollClipboardForTesting()

            XCTAssertTrue(controller.debugPasteActivityIsActiveForTesting)
            XCTAssertEqual(controller.debugHistoryClipsForTesting, history)
            XCTAssertEqual(controller.debugClipboardCaptureCountForTesting, 0)
            XCTAssertEqual(controller.debugMenuRebuildCountForTesting, rebuildCount)

            controller.debugFinishPasteActivityForTesting(generation: generation)
            controller.debugPollClipboardForTesting()

            XCTAssertFalse(controller.debugPasteActivityIsActiveForTesting)
            XCTAssertEqual(controller.debugHistoryClipsForTesting.last?.text, "Copy while paste is pending")
            XCTAssertEqual(controller.debugClipboardCaptureCountForTesting, 1)
            XCTAssertEqual(controller.debugMenuRebuildCountForTesting, rebuildCount + 1)
        }
    }

    func testReorderingDefersMenuRebuildUntilPasteCompletesOnMain() throws {
        try withController { controller, _ in
            UserDefaults.standard.set(true, forKey: CMPrefReorderClipsAfterPasting)
            let history = fixtureHistory()
            controller.debugReplaceHistoryClipsForTesting(history)
            let rebuildCount = controller.debugMenuRebuildCountForTesting
            let generation = controller.debugBeginPasteActivityForTesting(duration: 2)
            defer { controller.debugFinishPasteActivityForTesting(generation: generation) }

            controller.debugSelectHistoryClipForTesting(history[0].id)

            let promotedHistory = controller.debugHistoryClipsForTesting
            XCTAssertGreaterThan(promotedHistory[0].lastUsedAt, history[0].lastUsedAt)
            XCTAssertEqual(controller.debugMenuRebuildCountForTesting, rebuildCount)
            XCTAssertEqual(controller.debugClipboardCaptureCountForTesting, 0)

            controller.debugFinishPasteActivityForTesting(generation: generation)

            XCTAssertEqual(controller.debugMenuRebuildCountForTesting, rebuildCount,
                           "Finishing must queue the deferred AppKit rebuild on main.")
            pumpMainUntil { controller.debugMenuRebuildCountForTesting == rebuildCount + 1 }
            controller.debugFinishPasteActivityForTesting(generation: generation)
            controller.debugPollClipboardForTesting()
            XCTAssertEqual(controller.debugMenuRebuildCountForTesting, rebuildCount + 1)
            XCTAssertEqual(controller.debugClipboardCaptureCountForTesting, 0)
            XCTAssertEqual(controller.debugHistoryClipsForTesting, promotedHistory)
        }
    }

    func testExistingHistorySelectionWorksWhenFrontmostAppIsExcluded() throws {
        try withController { controller, pasteboard in
            let excludedBundle = "com.example.clipmenu.excluded-fixture"
            UserDefaults.standard.set([["bundleIdentifier": excludedBundle]], forKey: "excludeApps")
            let history = fixtureHistory()
            controller.debugReplaceHistoryClipsForTesting(history)
            let rebuildCount = controller.debugMenuRebuildCountForTesting

            controller.debugSelectHistoryClipForTesting(history[0].id)
            controller.debugPollClipboardForTesting(frontmostBundleIdentifier: excludedBundle)

            XCTAssertEqual(pasteboard.string(forType: .string), history[0].text)
            XCTAssertEqual(controller.debugHistoryClipsForTesting, history)
            XCTAssertEqual(controller.debugClipboardCaptureCountForTesting, 0)
            XCTAssertEqual(controller.debugMenuRebuildCountForTesting, rebuildCount)

            let externalWriter = NSPasteboard(name: pasteboard.name)
            externalWriter.clearContents()
            XCTAssertTrue(externalWriter.setString("Copy from excluded app", forType: .string))
            controller.debugPollClipboardForTesting(frontmostBundleIdentifier: excludedBundle)
            XCTAssertEqual(controller.debugHistoryClipsForTesting, history)
            XCTAssertEqual(controller.debugClipboardCaptureCountForTesting, 0)
            XCTAssertEqual(controller.debugMenuRebuildCountForTesting, rebuildCount)
        }
    }

    func testExistingHistorySelectionWorksWhenStringCaptureIsDisabled() throws {
        try withController { controller, pasteboard in
            var storeTypes = ClipItem.defaultStoreTypes()
            storeTypes["String"] = false
            UserDefaults.standard.set(storeTypes, forKey: "storeTypes")
            let history = fixtureHistory()
            controller.debugReplaceHistoryClipsForTesting(history)
            let rebuildCount = controller.debugMenuRebuildCountForTesting

            controller.debugSelectHistoryClipForTesting(history[0].id)
            XCTAssertNil(ClipItem.fromPasteboard(pasteboard))
            controller.debugPollClipboardForTesting()

            XCTAssertEqual(pasteboard.string(forType: .string), history[0].text)
            XCTAssertEqual(controller.debugHistoryClipsForTesting, history)
            XCTAssertEqual(controller.debugClipboardCaptureCountForTesting, 0)
            XCTAssertEqual(controller.debugMenuRebuildCountForTesting, rebuildCount)
        }
    }

    private func withController(_ body: (AppController, NSPasteboard) throws -> Void) throws {
        let defaults = UserDefaults.standard
        let domainName = try XCTUnwrap(Bundle.main.bundleIdentifier)
        let originalDomain = defaults.persistentDomain(forName: domainName)
        let originalController = AppController.debugSharedControllerForTesting
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("ClipMenuControllerOwnership-\(UUID().uuidString)"))
        defer {
            AppController.debugSharedControllerForTesting = originalController
            if let originalDomain {
                defaults.setPersistentDomain(originalDomain, forName: domainName)
            } else {
                defaults.removePersistentDomain(forName: domainName)
            }
            pasteboard.releaseGlobally()
        }
        defaults.set(false, forKey: CMPrefInputPasteCommandKey)
        defaults.set(false, forKey: CMPrefSaveHistoryOnQuitKey)
        defaults.set(false, forKey: CMPrefEnableActionKey)
        defaults.set(false, forKey: CMPrefReorderClipsAfterPasting)
        defaults.set(0, forKey: CMPrefShowStatusItemKey)
        defaults.set(20, forKey: CMPrefMaxHistorySizeKey)
        defaults.set(ClipItem.defaultStoreTypes(), forKey: "storeTypes")
        defaults.set([], forKey: "excludeApps")

        try body(AppController(pasteboard: pasteboard), pasteboard)
    }

    private func fixtureHistory() -> [ClipItem] {
        ["Older history fixture", "Newer history fixture"].enumerated().map { index, text in
            let date = Date(timeIntervalSince1970: TimeInterval(index + 1))
            return ClipItem(text: text, createdAt: date, lastUsedAt: date)
        }
    }

    private func pumpMainUntil(
        _ condition: () -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let deadline = ProcessInfo.processInfo.systemUptime + 1
        while !condition(), ProcessInfo.processInfo.systemUptime < deadline {
            CFRunLoopRunInMode(.defaultMode, 0.01, false)
        }
        XCTAssertTrue(condition(), "Deferred work did not run on main before the deadline.", file: file, line: line)
    }
}

@MainActor
final class AppControllerDebugReportTests: XCTestCase {
    func testMaxHistoryNormalizationReportPreservesPreferencesAndExistingHistory() throws {
        let appController = try XCTUnwrap(NSApp.delegate as? AppController)
        let defaults = UserDefaults.standard
        let domainName = try XCTUnwrap(Bundle.main.bundleIdentifier)
        let originalDomain = defaults.persistentDomain(forName: domainName)
        let originalClips = appController.debugHistoryClipsForTesting
        let reportURL = temporaryReportURL(named: "history-restoration")
        defer {
            if let originalDomain {
                defaults.setPersistentDomain(originalDomain, forName: domainName)
            } else {
                defaults.removePersistentDomain(forName: domainName)
            }
            appController.debugReplaceHistoryClipsForTesting(originalClips)
            try? FileManager.default.removeItem(at: reportURL.deletingLastPathComponent())
        }

        defaults.set(20, forKey: CMPrefMaxHistorySizeKey)
        defaults.set(false, forKey: CMPrefReorderClipsAfterPasting)
        defaults.set(
            reportURL.deletingLastPathComponent().appendingPathComponent("original-support").path,
            forKey: CMDebugSupportDirectoryDefaultsKey
        )
        let unrelatedPreference: [String: Any] = ["value": "preserve-me", "items": ["alpha", "beta"]]
        defaults.set(unrelatedPreference, forKey: "ClipMenuTests.UnrelatedPreference")
        let originalHistory = ["existing-one", "existing-two", "existing-three"].enumerated().map { index, text in
            let date = Date(timeIntervalSince1970: TimeInterval(index + 1))
            return ClipItem(text: text, createdAt: date, lastUsedAt: date)
        }
        appController.debugReplaceHistoryClipsForTesting(originalHistory)
        let expectedDomain = defaults.persistentDomain(forName: domainName) ?? [:]

        let report = try appController.debugRunReportForTesting(
            .maxHistorySizeNormalization,
            outputURL: reportURL
        )

        XCTAssertEqual(report["matchesExpected"] as? Bool, true)
        XCTAssertEqual(defaults.integer(forKey: CMPrefMaxHistorySizeKey), 20)
        let restoredDomain = defaults.persistentDomain(forName: domainName) ?? [:]
        XCTAssertTrue(
            (restoredDomain as NSDictionary).isEqual(to: expectedDomain),
            "The debug report must restore every persistent preference, including its support directory override."
        )
        XCTAssertEqual(appController.debugHistoryClipsForTesting, originalHistory)

        appController.debugCaptureHistoryTextForTesting("copied-four")
        appController.debugCaptureHistoryTextForTesting("copied-five")

        let restoredHistory = appController.debugHistoryClipsForTesting
        XCTAssertEqual(restoredHistory.count, 5)
        XCTAssertEqual(Array(restoredHistory.prefix(3)), originalHistory)
        XCTAssertEqual(restoredHistory.suffix(2).map(\.text), ["copied-four", "copied-five"])
    }

    func testMaxHistoryNormalizationReportRestoresLoadedDuplicateEntriesExactly() throws {
        let appController = try XCTUnwrap(NSApp.delegate as? AppController)
        let defaults = UserDefaults.standard
        let domainName = try XCTUnwrap(Bundle.main.bundleIdentifier)
        let originalDomain = defaults.persistentDomain(forName: domainName)
        let originalClips = appController.debugHistoryClipsForTesting
        let reportURL = temporaryReportURL(named: "duplicate-history-restoration")
        defer {
            if let originalDomain {
                defaults.setPersistentDomain(originalDomain, forName: domainName)
            } else {
                defaults.removePersistentDomain(forName: domainName)
            }
            appController.debugReplaceHistoryClipsForTesting(originalClips)
            try? FileManager.default.removeItem(at: reportURL.deletingLastPathComponent())
        }

        defaults.set(20, forKey: CMPrefMaxHistorySizeKey)
        defaults.set(false, forKey: CMPrefReorderClipsAfterPasting)
        let loadedHistory = ["same text", "different text", "same text"].enumerated().map { index, text in
            ClipItem(
                text: text,
                createdAt: Date(timeIntervalSince1970: TimeInterval(index + 1)),
                lastUsedAt: Date(timeIntervalSince1970: TimeInterval(index + 101))
            )
        }
        XCTAssertEqual(loadedHistory[0].duplicateKey, loadedHistory[2].duplicateKey)
        XCTAssertNotEqual(loadedHistory[0].id, loadedHistory[2].id)
        appController.debugReplaceHistoryClipsForTesting(loadedHistory)
        XCTAssertEqual(appController.debugHistoryClipsForTesting, loadedHistory)

        let report = try appController.debugRunReportForTesting(
            .maxHistorySizeNormalization,
            outputURL: reportURL
        )

        XCTAssertEqual(report["matchesExpected"] as? Bool, true)
        XCTAssertEqual(appController.debugHistoryClipsForTesting, loadedHistory)
    }

    func testSynchronousAppControllerDebugReportsMatchExpectedState() throws {
        let appController = try XCTUnwrap(NSApp.delegate as? AppController)
        let reports: [CMDebugAppControllerReportForTesting] = [
            .loginPrompt,
            .preferencesLoginItemTiming,
            .preferencesAutosaveTiming,
            .preferencesObserveIntervalTiming,
            .maxHistorySizeNormalization,
            .exportSeparatorNormalization,
            .exportModeNormalization,
            .sortOrderNormalization,
            .snippetPositionNormalization,
            .preferencesActionBehaviorTiming,
            .preferencesStoreTypesTiming,
            .excludedAppsCancel,
            .excludedAppsEditor,
            .historyMenuLayout,
            .menuFontSize,
            .menuFontSizingModeNormalization,
            .menuTooltipLengthNormalization,
            .menuTitleLengthNormalization,
            .menuFolderItemsNormalization,
            .menuInlineItemsNormalization,
            .typeThumbnailDimensionsNormalization,
            .typeFileIconSelectionNormalization
        ]

        var failedReports: [String] = []
        for report in reports {
            let payload = try appController.debugRunReportForTesting(
                report,
                outputURL: temporaryReportURL(named: report.rawValue)
            )
            if payload["matchesExpected"] as? Bool != true {
                let diagnosticState: [String: Any] = [
                    "state": payload["state"] ?? NSNull(),
                    "expectedState": payload["expectedState"] ?? NSNull()
                ]
                let diagnosticData = try JSONSerialization.data(withJSONObject: diagnosticState, options: [.sortedKeys])
                let diagnostic = String(decoding: diagnosticData, as: UTF8.self)
                failedReports.append("\(report.rawValue): \(diagnostic)")
            }
        }
        let failedReportList = failedReports.joined(separator: "\n")
        if !failedReports.isEmpty {
            XCTFail("Reports did not match expected state: \(failedReportList)")
        }
    }

    private func temporaryReportURL(named name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipMenuDebugReportTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("\(name).json")
    }
}
#endif

#if DEBUG
@MainActor
private final class NumericShortcutSelectionReceiver: NSObject {
    var selectedIndexes: [Int] = []
    var onSelection: ((NSMenuItem) -> Void)?

    @objc func selectItem(_ sender: NSMenuItem) {
        selectedIndexes.append(sender.tag)
        onSelection?(sender)
    }
}

@MainActor
final class AppControllerNumericShortcutTests: XCTestCase {
    // These tests exercise the Quartz filter and its queued native action.
    // Actual keyboard delivery and Accessibility permission require UI coverage.
    func testQuartzCommandNumberQueuesOneOrdinarySelectionAndConsumesItsKeyUp() throws {
        let controller = AppController()
        let originals = captureDefaults([CMPrefMenuItemsAreMarkedWithNumbersKey, CMPrefMenuItemsTitleStartWithZeroKey,
                                         CMPrefEnableActionKey, CMPrefCommandClickBehaviorKey])
        defer { restoreDefaults(originals) }
        UserDefaults.standard.set(true, forKey: CMPrefMenuItemsAreMarkedWithNumbersKey)
        UserDefaults.standard.set(false, forKey: CMPrefMenuItemsTitleStartWithZeroKey)
        UserDefaults.standard.set(true, forKey: CMPrefEnableActionKey)
        UserDefaults.standard.set(["type": "builtin", "name": "pasteAsPlainText:"], forKey: CMPrefCommandClickBehaviorKey)
        let menu = controller.debugNumericShortcutMenuForTesting(itemCount: 11, foldered: false)
        let receiver = NumericShortcutSelectionReceiver()
        var invokedModifiedClickActions: [Bool] = []
        receiver.onSelection = { item in
            invokedModifiedClickActions.append(controller.debugModifiedClickActionRequestedForTesting(item))
        }
        attach(receiver, to: menu)
        defer { controller.debugStopTrackingPopupMenuForTesting(menu) }

        XCTAssertFalse(try filter(controller, "1", keyCode: 18))
        XCTAssertFalse(try filter(controller, "1", keyCode: 18, type: .keyUp))
        controller.debugTrackPopupMenuForTesting(menu)
        XCTAssertFalse(try filter(controller, "v", keyCode: 9))
        XCTAssertFalse(try filter(controller, "1", keyCode: 18, modifiers: []))
        XCTAssertFalse(try filter(controller, "1", keyCode: 18, modifiers: [.command, .shift]))
        XCTAssertFalse(try filter(controller, "1", keyCode: 18, modifiers: [.command, .control]))
        XCTAssertFalse(try filter(controller, "1", keyCode: 18, modifiers: [.command, .option]))
        XCTAssertTrue(try filter(controller, "1", keyCode: 18))
        XCTAssertTrue(try filter(controller, "1", keyCode: 18, isRepeat: true))
        XCTAssertTrue(try filter(controller, "2", keyCode: 19), "A second eligible shortcut must not trigger native dispatch while selection is queued")
        XCTAssertEqual(receiver.selectedIndexes, [], "The tap callback must defer AppKit action dispatch")
        drainQueuedActions()
        XCTAssertEqual(receiver.selectedIndexes, [0])
        XCTAssertEqual(invokedModifiedClickActions, [false], "Command-number must stay an ordinary selection when Command-click has an action")
        XCTAssertEqual(controller.debugHandledNumericPopupKeyCountForTesting, 1)
        XCTAssertEqual(menu.items[10].keyEquivalent, "")
        controller.menuDidClose(menu)
        XCTAssertEqual(controller.debugTrackedPopupMenuCountForTesting, 0)
        XCTAssertTrue(try filter(controller, "1", keyCode: 18, type: .keyUp))
        XCTAssertFalse(try filter(controller, "1", keyCode: 18, type: .keyUp), "Only the keyup associated with a consumed keydown is filtered")
        XCTAssertTrue(try filter(controller, "2", keyCode: 19, type: .keyUp))
        drainQueuedActions()
        XCTAssertEqual(controller.debugConsumedNumericPopupKeyCountForTesting, 0)
        XCTAssertFalse(controller.debugHasNumericKeyEventHandlerForTesting)
        XCTAssertFalse(try filter(controller, "1", keyCode: 18))
        XCTAssertEqual(receiver.selectedIndexes, [0])

        controller.debugTrackPopupMenuForTesting(menu)
        XCTAssertTrue(try filter(controller, "0", keyCode: 29))
        drainQueuedActions()
        controller.menuDidClose(menu)
        XCTAssertTrue(try filter(controller, "0", keyCode: 29, type: .keyUp))
        drainQueuedActions()
        XCTAssertEqual(receiver.selectedIndexes, [0, 9])
        XCTAssertEqual(invokedModifiedClickActions, [false, false])
    }

    func testQuartzZeroBasedNumbersReachFolderedItemsUsingEventCharacters() throws {
        let controller = AppController()
        let originals = captureDefaults([CMPrefMenuItemsAreMarkedWithNumbersKey, CMPrefMenuItemsTitleStartWithZeroKey])
        defer { restoreDefaults(originals) }
        UserDefaults.standard.set(true, forKey: CMPrefMenuItemsAreMarkedWithNumbersKey)
        UserDefaults.standard.set(true, forKey: CMPrefMenuItemsTitleStartWithZeroKey)
        let menu = controller.debugNumericShortcutMenuForTesting(itemCount: 10, foldered: true)
        let submenu = try XCTUnwrap(menu.items.first?.submenu)
        let receiver = NumericShortcutSelectionReceiver()
        attach(receiver, to: submenu)
        defer { controller.debugStopTrackingPopupMenuForTesting(menu) }

        for (character, keyCode) in [("0", CGKeyCode(29)), ("0", CGKeyCode(18)), ("9", CGKeyCode(25))] {
            controller.debugTrackPopupMenuForTesting(menu)
            controller.debugTrackPopupMenuForTesting(submenu)
            XCTAssertEqual(controller.debugTrackedPopupMenuCountForTesting, 2)
            XCTAssertTrue(try filter(controller, character, keyCode: keyCode))
            drainQueuedActions()
            controller.menuDidClose(menu)
            XCTAssertEqual(controller.debugTrackedPopupMenuCountForTesting, 0, "Closing a root closes its tracked descendants")
            XCTAssertTrue(try filter(controller, character, keyCode: keyCode, type: .keyUp))
            drainQueuedActions()
            XCTAssertFalse(controller.debugHasNumericKeyEventHandlerForTesting)
        }
        XCTAssertEqual(receiver.selectedIndexes, [0, 0, 9], "Injected event characters must take precedence over US physical-key assumptions")
    }

    func testClosingMenuBeforeQueuedActionCancelsItAndLeavesUnrelatedKeysAlone() throws {
        let controller = AppController()
        let originals = captureDefaults([CMPrefMenuItemsAreMarkedWithNumbersKey, CMPrefMenuItemsTitleStartWithZeroKey])
        defer { restoreDefaults(originals) }
        UserDefaults.standard.set(true, forKey: CMPrefMenuItemsAreMarkedWithNumbersKey)
        UserDefaults.standard.set(false, forKey: CMPrefMenuItemsTitleStartWithZeroKey)
        let menu = controller.debugNumericShortcutMenuForTesting(itemCount: 3, foldered: false)
        let receiver = NumericShortcutSelectionReceiver()
        attach(receiver, to: menu)
        menu.items[0].isEnabled = false
        menu.items[1].isHidden = true
        controller.debugTrackPopupMenuForTesting(menu)
        defer { controller.debugStopTrackingPopupMenuForTesting(menu) }
        XCTAssertFalse(try filter(controller, "1", keyCode: 18), "Disabled items are not intercepted")
        XCTAssertFalse(try filter(controller, "2", keyCode: 19), "Hidden items are not intercepted")
        XCTAssertFalse(try filter(controller, "9", keyCode: 25), "Unassigned digits are not intercepted")
        XCTAssertTrue(try filter(controller, "3", keyCode: 20))
        controller.menuDidClose(menu)
        XCTAssertFalse(try filter(controller, "v", keyCode: 9))
        XCTAssertFalse(try filter(controller, "1", keyCode: 18, type: .keyUp), "Unmatched keyups pass through even while a consumed keyup is pending")
        drainQueuedActions()
        XCTAssertEqual(receiver.selectedIndexes, [], "A stale queued selection must not dispatch after its menu closes")
        XCTAssertTrue(try filter(controller, "3", keyCode: 20, type: .keyUp))
        drainQueuedActions()
        XCTAssertFalse(controller.debugHasNumericKeyEventHandlerForTesting)
        XCTAssertFalse(try filter(controller, "3", keyCode: 20))
        drainQueuedActions()
        XCTAssertEqual(receiver.selectedIndexes, [])
    }

    func testCommandMouseActionRetainsItsInteractionTypeAcrossModifierChanges() throws {
        let controller = AppController()
        let originals = captureDefaults([CMPrefEnableActionKey, CMPrefCommandClickBehaviorKey])
        defer { restoreDefaults(originals) }
        UserDefaults.standard.set(true, forKey: CMPrefEnableActionKey)
        UserDefaults.standard.set(["type": "builtin", "name": "pasteAsPlainText:"], forKey: CMPrefCommandClickBehaviorKey)
        let mouseItem = NSMenuItem(title: "Mouse fixture", action: nil, keyEquivalent: "")
        mouseItem.tag = -1
        let mouseEvent = try XCTUnwrap(NSEvent.mouseEvent(
            with: .leftMouseUp, location: .zero, modifierFlags: [.command], timestamp: 0,
            windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 0
        ))
        controller.debugRecordPopupInteractionForTesting(mouseEvent)
        let flagsEvent = try XCTUnwrap(NSEvent.keyEvent(
            with: .flagsChanged, location: .zero, modifierFlags: [.command], timestamp: 0,
            windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "",
            isARepeat: false, keyCode: 55
        ))
        controller.debugRecordPopupInteractionForTesting(flagsEvent)
        XCTAssertTrue(controller.debugModifiedClickActionRequestedForTesting(mouseItem))
    }

    private func attach(_ receiver: NumericShortcutSelectionReceiver, to menu: NSMenu) {
        for item in menu.items {
            item.target = receiver
            item.action = #selector(NumericShortcutSelectionReceiver.selectItem(_:))
        }
    }

    private func filter(
        _ controller: AppController, _ character: String, keyCode: CGKeyCode,
        modifiers: NSEvent.ModifierFlags = [.command], type: CGEventType = .keyDown,
        isRepeat: Bool = false
    ) throws -> Bool {
        let source = try XCTUnwrap(CGEventSource(stateID: .privateState))
        let event = try XCTUnwrap(CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: type == .keyDown))
        var flags: CGEventFlags = []
        if modifiers.contains(.command) { flags.insert(.maskCommand) }
        if modifiers.contains(.shift) { flags.insert(.maskShift) }
        if modifiers.contains(.control) { flags.insert(.maskControl) }
        if modifiers.contains(.option) { flags.insert(.maskAlternate) }
        event.flags = flags
        event.setIntegerValueField(.keyboardEventAutorepeat, value: isRepeat ? 1 : 0)
        let characters = Array(character.utf16)
        characters.withUnsafeBufferPointer {
            event.keyboardSetUnicodeString(stringLength: $0.count, unicodeString: $0.baseAddress)
        }
        return controller.debugConsumeNumericPopupKeyEventForTesting(type: type, event: event)
    }

    private func drainQueuedActions() {
        CFRunLoopRunInMode(.defaultMode, 0.01, false)
    }

    private func captureDefaults(_ keys: [String]) -> [String: Any] {
        Dictionary(uniqueKeysWithValues: keys.map { ($0, UserDefaults.standard.object(forKey: $0) ?? NSNull()) })
    }

    private func restoreDefaults(_ originals: [String: Any]) {
        for (key, value) in originals {
            if value is NSNull { UserDefaults.standard.removeObject(forKey: key) }
            else { UserDefaults.standard.set(value, forKey: key) }
        }
    }
}

#endif

#if TESTING
@MainActor
final class AppControllerMenuSurfaceTests: XCTestCase {

    func testMenuSurfaceExerciseBuildsRepresentativeMenus() throws {
        let appController = try XCTUnwrap(NSApp.delegate as? AppController)
        let report = appController.debugExerciseMenuSurfaceForTesting()
        XCTAssertEqual(report["addedClips"] as? Bool, true)
        XCTAssertEqual(report["addedSnippets"] as? Bool, true)
        XCTAssertEqual(report["partialHistoryBucketIsDirect"] as? Bool, true)
    }

    func testSelectionDispatchExerciseWritesAndClearsExpectedTargets() throws {
        let appController = try XCTUnwrap(NSApp.delegate as? AppController)
        let report = appController.debugExerciseSelectionDispatchForTesting()
        XCTAssertEqual(report["selectedClipText"] as? String, "Dispatch text")
        XCTAssertEqual(report["selectedSnippetText"] as? String, "Snippet dispatch")
        XCTAssertEqual(report["plainTextActionText"] as? String, "Dispatch text")
        XCTAssertEqual(report["filePathActionText"] as? String, "/tmp/alpha.txt\n/tmp/beta.txt")
        XCTAssertTrue((report["hfsPathActionText"] as? String)?.contains("gamma.txt") == true)
        XCTAssertEqual(report["removedFileClip"] as? Bool, true)
        XCTAssertEqual(report["clearCancelled"] as? Bool, false)
        XCTAssertEqual(report["clearAlertSuppressed"] as? Bool, true)
        XCTAssertEqual(report["historyWasEnabled"] as? Bool, true)
        XCTAssertEqual(report["clearConfirmed"] as? Bool, true)
        XCTAssertEqual((report["popupSummary"] as? [String: Any])?["menuTitle"] as? String, "Captured")
    }

    func testAppControllerSurfaceExerciseBuildsPromptMenuAndActionSurfaces() throws {
        let appController = try XCTUnwrap(NSApp.delegate as? AppController)
        let report = appController.debugExerciseAppControllerSurfacesForTesting()
        XCTAssertFalse((report["viewClassNames"] as? [String])?.isEmpty ?? true)
        XCTAssertEqual(report["legacyStatusTemplate"] as? Bool, true)
        XCTAssertEqual(report["preferredFontApplied"] as? Bool, true)
        XCTAssertEqual(report["popupEventCount"] as? Int, 4)
        XCTAssertEqual(report["excludedAppCount"] as? Int, 2)
        XCTAssertFalse((report["menuIconDefaults"] as? [String])?.isEmpty ?? true)
        XCTAssertNotNil(report["actionSurfaceState"] as? [String: Any])
        XCTAssertNotNil(report["menuSurfaceState"] as? [String: Any])
    }

    func testAppControllerSurfaceExerciseRestoresMenuFontPreferences() throws {
        let appController = try XCTUnwrap(NSApp.delegate as? AppController)
        let defaults = UserDefaults.standard
        let preferenceKeys = [
            CMPrefChangeFontSizeKey,
            CMPrefHowToChangeFontSizeKey,
            CMPrefSelectedFontSizeKey
        ]
        let originalValues = Dictionary(
            uniqueKeysWithValues: preferenceKeys.map { ($0, defaults.object(forKey: $0)) }
        )
        defer {
            for (key, value) in originalValues {
                if let value {
                    defaults.set(value, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
        }

        defaults.set(false, forKey: CMPrefChangeFontSizeKey)
        defaults.set(0, forKey: CMPrefHowToChangeFontSizeKey)
        defaults.set(9, forKey: CMPrefSelectedFontSizeKey)

        _ = appController.debugExerciseAppControllerSurfacesForTesting()

        XCTAssertFalse(defaults.bool(forKey: CMPrefChangeFontSizeKey))
        XCTAssertEqual(defaults.integer(forKey: CMPrefHowToChangeFontSizeKey), 0)
        XCTAssertEqual(defaults.integer(forKey: CMPrefSelectedFontSizeKey), 9)
    }

    func testPrivateHelperCoverageReportsNormalizeLegacyInputsAndEvents() throws {
        let appController = try XCTUnwrap(NSApp.delegate as? AppController)
        let legacyReport = CMDebugLegacyPrivateHelperReportForTesting()
        XCTAssertEqual(legacyReport["normalizedRemoveName"] as? String, "remove:")
        XCTAssertEqual(legacyReport["normalizedRemoveType"] as? String, "builtin")
        XCTAssertEqual(legacyReport["dictionaryType"] as? String, "builtin")
        XCTAssertEqual(legacyReport["dictionaryCount"] as? String, "3")
        XCTAssertNil(legacyReport["invalidAction"] as? [String: String])
        XCTAssertEqual(legacyReport["excludedBundleIdentifiers"] as? [String], ["com.example.One", "com.example.Two"])
        XCTAssertEqual(legacyReport["excludedNames"] as? [String], ["One"])
        XCTAssertEqual((legacyReport["stringArrays"] as? [[String]])?.count, 4)

        let appReport = appController.debugPrivateHelperCoverageReportForTesting()
        let combinedFlags = try XCTUnwrap(appReport["combinedFlags"] as? UInt)
        XCTAssertTrue(combinedFlags != 0)
        XCTAssertEqual(appReport["noFlags"] as? UInt, 0)
        XCTAssertEqual(appReport["eventTypeCount"] as? Int, 7)
        XCTAssertEqual(appReport["mappedEventTypeCount"] as? Int, 6)
        XCTAssertEqual(appReport["lastEventTypeIsNil"] as? Bool, true)
        XCTAssertEqual((appReport["carbonFlags"] as? [UInt])?.count, 6)
        XCTAssertNotEqual(appReport["syntheticEventTapFlags"] as? UInt, 0)
        XCTAssertEqual(appReport["syntheticEventTapType"] as? UInt, NSEvent.EventType.keyDown.rawValue)
    }

    func testPasteAutomationCoverageReportReachesSafeDispatchBoundaries() throws {
        let appController = try XCTUnwrap(NSApp.delegate as? AppController)
        let report = appController.debugPasteAutomationCoverageReportForTesting()
        XCTAssertEqual(report["matchesExpected"] as? Bool, true)
        let state = try XCTUnwrap(report["state"] as? [String: Any])
        XCTAssertEqual(state["deniedStateCanSynthesizePaste"] as? Bool, false)
        XCTAssertEqual(state["accessibilityOnlyCanSynthesizePaste"] as? Bool, true)
        XCTAssertEqual(state["postEventOnlyCanSynthesizePaste"] as? Bool, true)
        XCTAssertGreaterThanOrEqual(state["directPasteBypassCount"] as? Int ?? 0, 2)
    }

    func testLaunchAgentCoverageReportWritesAndRemovesTemporaryPlist() {
        let report = LoginItemManager.debugLaunchAgentCoverageReportForTesting()
        XCTAssertEqual(report["enabled"] as? Bool, true)
        XCTAssertEqual(report["existsAfterEnable"] as? Bool, true)
        XCTAssertEqual(report["runAtLoad"] as? Bool, true)
        XCTAssertEqual(report["disabled"] as? Bool, true)
        XCTAssertEqual(report["existsAfterDisable"] as? Bool, false)
        XCTAssertFalse((report["label"] as? String ?? "").isEmpty)
    }

}
#endif
