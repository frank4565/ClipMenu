import AppKit
import Carbon
import XCTest
@testable import ClipMenu

final class PreferenceNormalizationTests: XCTestCase {
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

#if TESTING
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

        AppController().debugUserDefaultsDidChangeForTesting()

        XCTAssertEqual(defaults.integer(forKey: CMPrefMaxHistorySizeKey), 1)
        XCTAssertEqual(defaults.integer(forKey: CMPrefAutosaveDelayKey), 86_400)
        XCTAssertEqual(defaults.integer(forKey: CMPrefThumbnailWidthKey), 1)
        XCTAssertEqual(defaults.integer(forKey: CMPrefMaxLengthOfToolTipKey), 1)
        XCTAssertEqual(defaults.integer(forKey: CMPrefNumberOfItemsPlaceInlineKey), 0)
    }
#endif
}
