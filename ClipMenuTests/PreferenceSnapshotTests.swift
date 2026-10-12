import XCTest
@testable import ClipMenu

final class PreferenceSnapshotTests: XCTestCase {
    private let keys = [
        CMPrefInputPasteCommandKey,
        CMPrefReorderClipsAfterPasting,
        CMPrefSaveHistoryOnQuitKey,
        CMPrefExportHistoryAsSingleFileKey,
        CMPrefTagOfSeparatorForExportHistoryToFileKey,
        CMPrefMaxHistorySizeKey,
        CMPrefAutosaveDelayKey,
        CMPrefTimeIntervalKey,
        CMPrefShowStatusItemKey,
        CMPrefThumbnailWidthKey,
        CMPrefThumbnailHeightKey,
        CMPrefShowIconInTheMenuKey,
        CMPrefMenuIconSizeKey,
        CMPrefPositionOfSnippetsKey,
        CMEnableAutomaticCheckKey,
        CMEnableAutomaticCheckPreReleaseKey,
        CMAutomaticallyInstallUpdatesKey,
        CMUpdateCheckIntervalKey,
        "SUEnableAutomaticChecks",
        "SUScheduledCheckInterval",
        CMPrefEnableActionKey,
        CMPrefInvokeActionImmediatelyKey,
        "excludeApps",
        "storeTypes",
        CMPrefHotKeyEnabledKey,
        CMPrefHotKeyKeyCodeKey,
        CMPrefHotKeyModifierFlagsKey,
        CMPrefSnippetsHotKeyEnabledKey,
        CMPrefSnippetsHotKeyKeyCodeKey,
        CMPrefSnippetsHotKeyModifierFlagsKey,
        CMPrefMaxMenuItemTitleLengthKey,
        CMPrefNumberOfItemsPlaceInlineKey,
        CMPrefNumberOfItemsPlaceInsideFolderKey,
        CMPrefMenuItemsAreMarkedWithNumbersKey,
        CMPrefMenuItemsTitleStartWithZeroKey,
        CMPrefAddNumericKeyEquivalentsKey,
        CMPrefShowLabelsInMenuKey,
        CMPrefAddClearHistoryMenuItemKey,
        CMPrefShowAlertBeforeClearHistoryKey,
        CMPrefShowToolTipOnMenuItemKey,
        CMPrefMaxLengthOfToolTipKey,
        CMPrefChangeFontSizeKey,
        CMPrefHowToChangeFontSizeKey,
        CMPrefSelectedFontSizeKey
    ]
    private var defaultsSnapshot: [String: Any?] = [:]

    override func setUp() {
        super.setUp()
        defaultsSnapshot = Dictionary(uniqueKeysWithValues: keys.map { ($0, UserDefaults.standard.object(forKey: $0)) })
    }

    override func tearDown() {
        for (key, value) in defaultsSnapshot {
            if let value {
                UserDefaults.standard.set(value, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        super.tearDown()
    }

    func testGeneralPreferencesSnapshotNormalizesStoredState() throws {
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: CMPrefInputPasteCommandKey)
        defaults.set(2, forKey: CMPrefReorderClipsAfterPasting)
        defaults.set(false, forKey: CMPrefSaveHistoryOnQuitKey)
        defaults.set(0, forKey: CMPrefExportHistoryAsSingleFileKey)
        defaults.set(99, forKey: CMPrefTagOfSeparatorForExportHistoryToFileKey)
        defaults.set(0, forKey: CMPrefMaxHistorySizeKey)
        defaults.set(61, forKey: CMPrefAutosaveDelayKey)
        defaults.set(2.0, forKey: CMPrefTimeIntervalKey)
        defaults.set(99, forKey: CMPrefShowStatusItemKey)
        defaults.set([
            ["name": "Notes", "bundleIdentifier": "com.apple.Notes"],
            ["name": "Safari", "bundleIdentifier": "com.apple.Safari"]
        ], forKey: "excludeApps")

        let snapshot = CMGeneralPreferencesSnapshotForDebug()
        let clipboard = try XCTUnwrap(snapshot["clipboardHistory"] as? [String: Any])
        let states = try XCTUnwrap(clipboard["states"] as? [String: Any])
        let excludedSurface = try XCTUnwrap(snapshot["excludedApplications"] as? [String: Any])
        let pasteAutomationSurface = try XCTUnwrap(clipboard["pasteAutomationSurface"] as? [String: Any])
        let pasteAutomationStates = try XCTUnwrap(pasteAutomationSurface["states"] as? [String: Any])
        let pasteAutomationBadges = try XCTUnwrap(pasteAutomationSurface["badges"] as? [String])

        XCTAssertEqual(states["inputPasteCommand"] as? Bool, false)
        XCTAssertEqual(pasteAutomationStates["inputPasteCommand"] as? Bool, false)
        XCTAssertTrue((pasteAutomationSurface["detail"] as? String)?.contains("currently off") == true)
        XCTAssertTrue(pasteAutomationBadges.contains(NSLocalizedString("Auto-paste off", comment: "")))
        XCTAssertEqual(states["sortByLastUsed"] as? Bool, true)
        XCTAssertEqual(states["saveHistoryOnQuit"] as? Bool, false)
        XCTAssertEqual(states["exportHistoryAsSingleFile"] as? Bool, false)
        XCTAssertEqual(states["exportSeparator"] as? Int, 1)
        XCTAssertEqual(states["maxHistorySize"] as? Int, 1)
        XCTAssertEqual(states["autosaveDelay"] as? Int, 60)
        XCTAssertEqual(states["timeInterval"] as? Double, 1.0)
        XCTAssertEqual(excludedSurface["applicationNames"] as? [String], ["Notes", "Safari"])
    }

    func testTypePreferencesSnapshotSummarizesStoreTypesImagesAndIcons() throws {
        let defaults = UserDefaults.standard
        defaults.set(["String": true, "PDF": false, "TIFF": NSNumber(value: false)], forKey: "storeTypes")
        defaults.set(0, forKey: CMPrefThumbnailWidthKey)
        defaults.set(48, forKey: CMPrefThumbnailHeightKey)
        defaults.set(false, forKey: CMPrefShowIconInTheMenuKey)
        defaults.set(47, forKey: CMPrefMenuIconSizeKey)

        let snapshot = CMTypePreferencesSnapshotForDebug()
        let storeTypes = try XCTUnwrap(snapshot["storeTypes"] as? [String: Any])
        let images = try XCTUnwrap(snapshot["images"] as? [String: Any])
        let imageStates = try XCTUnwrap(images["states"] as? [String: Any])
        let icons = try XCTUnwrap(snapshot["icons"] as? [String: Any])

        XCTAssertEqual(storeTypes["enabledCount"] as? Int, 6)
        XCTAssertEqual(storeTypes["disabledCount"] as? Int, 2)
        XCTAssertEqual(imageStates["thumbnailWidth"] as? Int, 1)
        XCTAssertEqual(imageStates["thumbnailHeight"] as? Int, 48)
        XCTAssertEqual(icons["showIcons"] as? Bool, false)
        XCTAssertTrue((icons["sizeBadge"] as? String)?.contains("48") == true)
    }

    func testShortcutAndMenuSnapshotsExposeLegacyControls() throws {
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: CMPrefHotKeyEnabledKey)
        defaults.set(true, forKey: CMPrefSnippetsHotKeyEnabledKey)
        defaults.set(11, forKey: CMPrefSnippetsHotKeyKeyCodeKey)
        defaults.set(Int(NSEvent.ModifierFlags([.command, .option]).rawValue), forKey: CMPrefSnippetsHotKeyModifierFlagsKey)
        defaults.set(0, forKey: CMPrefMaxMenuItemTitleLengthKey)
        defaults.set(-5, forKey: CMPrefNumberOfItemsPlaceInlineKey)
        defaults.set(0, forKey: CMPrefNumberOfItemsPlaceInsideFolderKey)
        defaults.set(false, forKey: CMPrefMenuItemsAreMarkedWithNumbersKey)
        defaults.set(true, forKey: CMPrefMenuItemsTitleStartWithZeroKey)
        defaults.set(true, forKey: CMPrefAddNumericKeyEquivalentsKey)
        defaults.set(false, forKey: CMPrefShowLabelsInMenuKey)
        defaults.set(false, forKey: CMPrefAddClearHistoryMenuItemKey)
        defaults.set(true, forKey: CMPrefShowAlertBeforeClearHistoryKey)
        defaults.set(false, forKey: CMPrefShowToolTipOnMenuItemKey)
        defaults.set(0, forKey: CMPrefMaxLengthOfToolTipKey)
        defaults.set(true, forKey: CMPrefChangeFontSizeKey)
        defaults.set(1, forKey: CMPrefHowToChangeFontSizeKey)
        defaults.set(47, forKey: CMPrefSelectedFontSizeKey)

        let shortcuts = CMShortcutsPreferenceSnapshotForDebug()
        let rows = try XCTUnwrap(shortcuts["rows"] as? [[String: String]])
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(shortcuts["visibleRowTitles"] as? [String], rows.compactMap { $0["title"] })
        XCTAssertNil(shortcuts["hiddenHistoryShortcutDisplay"])
        XCTAssertNil(shortcuts["reservedHistoryBadge"])

        let menu = CMMenuPreferencesSnapshotForDebug()
        let layout = try XCTUnwrap(menu["layout"] as? [String: Any])
        let layoutValues = try XCTUnwrap(layout["values"] as? [String: Any])
        let menuItems = try XCTUnwrap(menu["menuItems"] as? [String: Any])
        let itemStates = try XCTUnwrap(menuItems["states"] as? [String: Any])
        let itemControlStates = try XCTUnwrap(menuItems["controlStates"] as? [String: Any])
        let preview = try XCTUnwrap(menu["menuRowPreview"] as? [String: Any])
        let tooltips = try XCTUnwrap(menu["tooltips"] as? [String: Any])
        let font = try XCTUnwrap(menu["font"] as? [String: Any])

        XCTAssertEqual(layoutValues["maxTitleLength"] as? Int, 1)
        XCTAssertEqual(layoutValues["inlineItems"] as? Int, 0)
        XCTAssertEqual(layoutValues["folderItems"] as? Int, 1)
        XCTAssertEqual(itemStates["markWithNumbers"] as? Bool, false)
        XCTAssertEqual(itemControlStates["titleStartsWithZeroEnabled"] as? Bool, false)
        XCTAssertEqual(itemControlStates["alertBeforeClearEnabled"] as? Bool, false)
        XCTAssertNotNil(preview["badges"] as? [String])
        XCTAssertNotNil(preview["historyRowTitle"] as? String)
        XCTAssertEqual(tooltips["maxTooltipLength"] as? Int, 1)
        XCTAssertEqual(tooltips["maxLengthEnabled"] as? Bool, false)
        XCTAssertEqual(font["changeFontSize"] as? Bool, true)
        XCTAssertNotNil(font["sizeOptions"] as? [String])
    }

    func testCaptureRulesSnapshotsExposeOpenAndFilteredStates() throws {
        let openCapture = CMCaptureRulesPreferencesSnapshotForDebug(
            reorderClipsAfterPasting: false,
            excludedApps: []
        )
        let filteredCapture = CMCaptureRulesPreferencesSnapshotForDebug(
            reorderClipsAfterPasting: true,
            excludedApps: ["Safari", "Notes"]
        )
        XCTAssertEqual((openCapture["states"] as? [String: Any])?["excludedAppsCount"] as? Int, 0)
        XCTAssertEqual((filteredCapture["states"] as? [String: Any])?["excludedAppsCount"] as? Int, 2)
    }

    func testSnippetAndUpdateSnapshotsExposeSelectedState() throws {
        let defaults = UserDefaults.standard
        defaults.set(CMPositionOfSnippets.aboveClips.rawValue, forKey: CMPrefPositionOfSnippetsKey)
        UpdateCoordinator.shared.automaticallyChecksForUpdates = false
        defaults.set(true, forKey: CMEnableAutomaticCheckPreReleaseKey)
        UpdateCoordinator.shared.automaticallyDownloadsUpdates = true
        UpdateCoordinator.shared.updateCheckInterval = 12_345

        let snippet = CMSnippetPreferencesSnapshotForDebug()
        XCTAssertEqual(snippet["selectedPosition"] as? Int, CMPositionOfSnippets.aboveClips.rawValue)
        let options = try XCTUnwrap(snippet["options"] as? [[String: Any]])
        XCTAssertEqual(options.filter { $0["selected"] as? Bool == true }.count, 1)

        let updates = CMUpdatesPreferencesSnapshotForDebug()
        let states = try XCTUnwrap(updates["states"] as? [String: Any])
        XCTAssertEqual(states["automaticChecks"] as? Bool, false)
        XCTAssertEqual(states["preReleases"] as? Bool, true)
        XCTAssertEqual(states["automaticallyInstallUpdates"] as? Bool, false)
        XCTAssertEqual(states["automaticallyDownloadsUpdates"] as? Bool, false)
        XCTAssertTrue(defaults.bool(forKey: "SUAutomaticallyUpdate"))
        XCTAssertEqual(states["interval"] as? Int, 12_345)
        XCTAssertEqual(states["showsImportedIntervalNotice"] as? Bool, true)
    }

    func testActionPreferencesSnapshotExposesBehaviorAndMenuSummaries() throws {
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: CMPrefEnableActionKey)
        defaults.set(true, forKey: CMPrefInvokeActionImmediatelyKey)

        let snapshot = CMActionPreferencesSnapshotForDebug()
        let behavior = try XCTUnwrap(snapshot["behavior"] as? [String: Any])
        let states = try XCTUnwrap(behavior["states"] as? [String: Any])
        let controlStates = try XCTUnwrap(behavior["controlStates"] as? [String: Any])
        let availableActions = try XCTUnwrap(snapshot["availableActions"] as? [String: Any])
        let actionMenu = try XCTUnwrap(snapshot["actionMenu"] as? [String: Any])

        XCTAssertEqual(states["enableActions"] as? Bool, false)
        XCTAssertEqual(states["invokeImmediately"] as? Bool, true)
        XCTAssertEqual(controlStates["invokeImmediatelyEnabled"] as? Bool, false)
        XCTAssertNotNil(availableActions["countSummary"] as? String)
        XCTAssertNotNil(actionMenu["countSummary"] as? String)
    }

    func testActionPreferenceDebugBridgeExercisesSelectionExpansionAndMovement() {
        CMReloadActionPreferences()
        defer { CMReloadActionPreferences() }

        let initialPaths = CMCurrentActionPreferencePaths()
        XCTAssertFalse(initialPaths.isEmpty)

        CMAddActionFolderForTesting()
        CMAddReservedActionForTesting()
        XCTAssertTrue(CMSelectActionPreferenceNodeForTesting(path: "Test Remove"))
        XCTAssertEqual(CMCurrentSelectedActionPreferencePath(), "Test Remove")

        XCTAssertTrue(CMToggleExpandedActionPreferencePathForTesting(path: "untitled folder"))
        XCTAssertTrue(CMCurrentExpandedActionPreferencePaths().contains("untitled folder"))
        XCTAssertTrue(CMMoveActionNodeForTesting(sourcePath: "Test Remove", destinationParentPath: "untitled folder", insertionIndex: 0))
        XCTAssertTrue(CMCurrentActionPreferencePaths().contains("untitled folder/Test Remove"))
        XCTAssertFalse(CMMoveActionNodeForTesting(sourcePath: "missing", destinationParentPath: nil, insertionIndex: 0))
        XCTAssertFalse(CMMoveActionNodeForTesting(sourcePath: "untitled folder", destinationParentPath: "missing", insertionIndex: 0))

        XCTAssertTrue(CMSetReservedActionKindForTesting("builtin"))
        XCTAssertTrue(CMSelectReservedActionPreferenceNodeForTesting(path: "Paste as Plain Text"))
        let reservedSnapshot = CMCurrentActionInspectorSnapshotForTesting()
        XCTAssertEqual(reservedSnapshot?["pane"] as? String, "reserved")

        XCTAssertTrue(CMInsertReservedActionForTesting(reservedPath: "Remove", destinationParentPath: "untitled folder", insertionIndex: 1))
        XCTAssertTrue(CMCurrentActionPreferencePaths().contains("untitled folder/Remove"))
        XCTAssertFalse(CMInsertReservedActionForTesting(reservedPath: "missing", destinationParentPath: "untitled folder", insertionIndex: 0))
        XCTAssertFalse(CMInsertReservedActionForTesting(reservedPath: "Remove", destinationParentPath: "missing", insertionIndex: 0))
        XCTAssertTrue(CMInsertReservedActionForTesting(reservedPath: "Paste as File Path", destinationParentPath: nil, insertionIndex: 0))
        XCTAssertEqual(CMCurrentActionPreferencePaths().first, "Paste as File Path")
        XCTAssertTrue(CMSelectActionPreferenceNodeForTesting(path: "Paste as File Path"))
        CMRemoveSelectedActionNodeForTesting()
        XCTAssertNotEqual(CMCurrentSelectedActionPreferencePath(), "Paste as File Path")

        XCTAssertTrue(CMSetReservedActionKindForTesting("bundled"))
        XCTAssertFalse(CMCurrentBundledReservedActionTitles().isEmpty)
        XCTAssertTrue(CMSetReservedActionKindForTesting("user"))
        _ = CMCurrentUserReservedActionTitles()
        XCTAssertFalse(CMSetReservedActionKindForTesting("unknown"))

        CMCommitActionPreferences()
        XCTAssertNotNil(CMCommittedActionNodesData())
    }

}
