import AppKit
import XCTest
@testable import ClipMenu

#if DEBUG
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
