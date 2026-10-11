import XCTest
@testable import ClipMenu

#if DEBUG || TESTING
final class SnippetDebugReportTests: XCTestCase {
    func testSnippetFileStoreDebugReportsMatchExpectedState() {
        let store = SnippetFileStore.shared

        XCTAssertEqual(store.debugEmptyExportReport()["matchesExpected"] as? Bool, true)
        XCTAssertEqual(store.debugManualExportImportReport()["matchesExpected"] as? Bool, true)
#if TESTING
        XCTAssertEqual(store.debugLegacyCoreDataImportReport()["matchesExpected"] as? Bool, true)
        XCTAssertEqual(store.debugLegacySnippetLoadReport()["matchesExpected"] as? Bool, true)
#endif
    }

    func testSnippetEditorPureDebugReportsMatchExpectedState() {
        let reports: [(String, [String: Any])] = [
            ("normalization", CMDebugSnippetNormalizationReport()),
            ("searchScope", CMDebugSnippetSearchScopeReport()),
            ("folderDropValidation", CMDebugSnippetFolderDropValidationReport())
        ]

        for (name, report) in reports {
            XCTAssertEqual(report["matchesExpected"] as? Bool, true, "\(name) report did not match expected state")
        }
    }

    func testSnippetFileStoreMutationsMaintainSelectionAndOrdering() {
        let store = SnippetFileStore.shared
        let originalFolders = store.folders
        let originalSelection = store.currentSelectionSnapshot()
        defer {
            store.folders = originalFolders
            store.restoreSelectionSnapshot(originalSelection)
            store.undoManager.removeAllActions()
        }

        let firstSnippet = Snippet(title: "First", content: "first body", isEnabled: true)
        let secondSnippet = Snippet(title: "Second", content: "second body", isEnabled: true)
        let thirdSnippet = Snippet(title: "Third", content: "third body", isEnabled: false)
        let firstFolder = SnippetFolder(title: "One", isEnabled: true, snippets: [firstSnippet, secondSnippet])
        let secondFolder = SnippetFolder(title: "Two", isEnabled: false, snippets: [thirdSnippet])

        store.folders = [firstFolder, secondFolder]
        store.restoreSelectionSnapshot(
            SnippetFileStore.SelectionSnapshot(
                selectedFolderIDs: [firstFolder.id],
                selectedSnippetIDs: [firstSnippet.id],
                primarySelectedFolderID: firstFolder.id,
                primarySelectedSnippetID: firstSnippet.id
            )
        )

        store.updateFolder(
            id: firstFolder.id,
            to: SnippetFolder(id: firstFolder.id, title: "One Updated", isEnabled: true, snippets: [firstSnippet, secondSnippet])
        )
        store.updateSnippet(
            folderID: firstFolder.id,
            snippetID: firstSnippet.id,
            to: Snippet(id: firstSnippet.id, title: "First Updated", content: "updated body", isEnabled: true)
        )
        XCTAssertEqual(store.folders[0].title, "One Updated")
        XCTAssertEqual(store.folders[0].snippets[0].content, "updated body")

        store.selectedFolderIDs = [firstFolder.id, UUID()]
        XCTAssertEqual(store.selectedFolderIDs, [firstFolder.id])
        store.selectedSnippetIDs = [firstSnippet.id, UUID()]
        XCTAssertEqual(store.selectedSnippetIDs, [firstSnippet.id])

        store.toggleSelectedSnippetEnabled()
        XCTAssertEqual(store.folders[0].snippets[0].isEnabled, false)
        store.moveSnippets(from: IndexSet(integer: 0), to: 2, in: firstFolder.id)
        XCTAssertEqual(store.folders[0].snippets.map(\.title), ["Second", "First Updated"])

        store.moveSnippetForTesting(
            sourceFolderID: firstFolder.id,
            snippetID: firstSnippet.id,
            targetFolderID: secondFolder.id,
            destinationIndex: 0
        )
        XCTAssertEqual(store.selectedFolderID, secondFolder.id)
        XCTAssertEqual(store.selectedSnippetID, firstSnippet.id)
        XCTAssertEqual(store.folders[0].snippets.map(\.title), ["Second"])
        XCTAssertEqual(store.folders[1].snippets.map(\.title), ["First Updated", "Third"])

        store.toggleSelectedFolderEnabled()
        XCTAssertEqual(store.folders[1].isEnabled, true)
        XCTAssertNil(store.selectedFolderID)
        XCTAssertNil(store.selectedSnippetID)

        let addedFolderID = store.addFolder()
        XCTAssertEqual(store.selectedFolderID, addedFolderID)
        XCTAssertNotNil(store.addSnippet())
        XCTAssertTrue(store.hasSingleSelectedFolder)
        XCTAssertTrue(store.hasSingleSelectedSnippet)

        store.removeSelectedSnippet()
        XCTAssertEqual(store.folders.last?.snippets.count, 0)
        store.removeSelectedFolder()
        XCTAssertFalse(store.folders.contains { $0.id == addedFolderID })
    }

#if TESTING
    func testSnippetEditorSnapshotCoversSelectionAndSearchStates() {
        let store = SnippetFileStore.shared
        let originalFolders = store.folders
        let originalSelection = store.currentSelectionSnapshot()
        let originalScope = CMSnippetEditorSearchScopeDebugRegistry.currentScopeRawValue()
        let originalSearchText = CMSnippetEditorSearchTextDebugRegistry.currentText()
        defer {
            store.folders = originalFolders
            store.restoreSelectionSnapshot(originalSelection)
            CMSnippetEditorSearchScopeDebugRegistry.updateCurrentScope(originalScope)
            CMSnippetEditorSearchTextDebugRegistry.updateCurrentText(originalSearchText)
        }

        let firstSnippet = Snippet(title: "Alpha", content: "first body", isEnabled: true)
        let secondSnippet = Snippet(title: "Beta", content: "needle body", isEnabled: false)
        let firstFolder = SnippetFolder(title: "One", isEnabled: true, snippets: [firstSnippet, secondSnippet])
        let secondFolder = SnippetFolder(title: "Two", isEnabled: true, snippets: [])
        store.folders = [firstFolder, secondFolder]

        store.restoreSelectionSnapshot(
            SnippetFileStore.SelectionSnapshot(
                selectedFolderIDs: [firstFolder.id],
                selectedSnippetIDs: [firstSnippet.id],
                primarySelectedFolderID: firstFolder.id,
                primarySelectedSnippetID: firstSnippet.id
            )
        )
        CMSnippetEditorSearchScopeDebugRegistry.updateCurrentScope("all")
        CMSnippetEditorSearchTextDebugRegistry.updateCurrentText("")
        XCTAssertEqual(
            ((CMSnippetEditorSnapshotForDebug()["detailPane"] as? [String: Any])?["state"] as? [String: String])?["mode"],
            "editor"
        )

        store.restoreSelectionSnapshot(
            SnippetFileStore.SelectionSnapshot(
                selectedFolderIDs: [firstFolder.id, secondFolder.id],
                selectedSnippetIDs: [],
                primarySelectedFolderID: firstFolder.id,
                primarySelectedSnippetID: nil
            )
        )
        XCTAssertEqual(
            (CMSnippetEditorSnapshotForDebug()["snippetListState"] as? [String: String])?["mode"],
            "multipleFolders"
        )

        store.restoreSelectionSnapshot(
            SnippetFileStore.SelectionSnapshot(
                selectedFolderIDs: [firstFolder.id],
                selectedSnippetIDs: [firstSnippet.id, secondSnippet.id],
                primarySelectedFolderID: firstFolder.id,
                primarySelectedSnippetID: firstSnippet.id
            )
        )
        XCTAssertEqual(
            ((CMSnippetEditorSnapshotForDebug()["detailPane"] as? [String: Any])?["state"] as? [String: String])?["mode"],
            "multipleSnippets"
        )

        store.restoreSelectionSnapshot(
            SnippetFileStore.SelectionSnapshot(
                selectedFolderIDs: [secondFolder.id],
                selectedSnippetIDs: [],
                primarySelectedFolderID: secondFolder.id,
                primarySelectedSnippetID: nil
            )
        )
        XCTAssertEqual(
            (CMSnippetEditorSnapshotForDebug()["snippetListState"] as? [String: String])?["mode"],
            "noSnippets"
        )

        store.restoreSelectionSnapshot(
            SnippetFileStore.SelectionSnapshot(
                selectedFolderIDs: [firstFolder.id],
                selectedSnippetIDs: [],
                primarySelectedFolderID: firstFolder.id,
                primarySelectedSnippetID: nil
            )
        )
        CMSnippetEditorSearchScopeDebugRegistry.updateCurrentScope("content")
        CMSnippetEditorSearchTextDebugRegistry.updateCurrentText("missing")
        XCTAssertEqual(
            (CMSnippetEditorSnapshotForDebug()["snippetListState"] as? [String: String])?["mode"],
            "noMatches"
        )

        CMSnippetEditorSearchTextDebugRegistry.updateCurrentText("needle")
        let resultsSnapshot = CMSnippetEditorSnapshotForDebug()
        XCTAssertEqual((resultsSnapshot["snippetListState"] as? [String: String])?["mode"], "results")
        XCTAssertEqual((resultsSnapshot["search"] as? [String: Any])?["selectedScopeRawValue"] as? String, "content")
    }

    func testUIPrivateHelperCoverageReportRuns() {
        let report = CMUIPrivateHelperCoverageReportForTesting()
        XCTAssertFalse(report.isEmpty)
        XCTAssertEqual((report["preferenceTabs"] as? [Any])?.count, 5)
        XCTAssertEqual((report["preferenceTabDetails"] as? [[String: Any]])?.count, 6)
        let visibleSearches = report["visibleSearches"] as? [String: [String]]
        XCTAssertEqual(visibleSearches?["missing"], [])
        XCTAssertTrue(visibleSearches?["ACTION"]?.contains("actions") == true)
        XCTAssertFalse((report["fileIconMappingHighlights"] as? [[String: Any]])?.isEmpty == true)
        XCTAssertEqual((report["workflowStage"] as? [String: String])?["value"], "Waiting")
    }

    @MainActor
    func testDragDropExerciseReportsMoveExpectedItems() {
        let snippetReport = CMSnippetDragDropExerciseForTesting()
        XCTAssertEqual(snippetReport["matchesExpected"] as? Bool, true)

        let actionReport = CMActionDragDropExerciseForTesting()
        XCTAssertEqual(actionReport["matchesExpected"] as? Bool, true)
    }

    func testStorageLoadCoverageReportsExerciseModelLoaders() {
        let snippetReport = CMSnippetStorageLoadCoverageReportForTesting()
        XCTAssertEqual(snippetReport["jsonOnlyTitle"] as? String, "JSON Folder")
        XCTAssertEqual(snippetReport["xmlLoadedTitle"] as? String, "XML Folder")
        XCTAssertEqual(snippetReport["xmlLoadedSnippetTitle"] as? String, "XML Snippet")
        XCTAssertNotNil(snippetReport["reusedFolderID"] as? Bool)
        XCTAssertNotNil(snippetReport["reusedSnippetID"] as? Bool)
        XCTAssertEqual(snippetReport["corruptLoadedCount"] as? Int, 0)
        XCTAssertEqual(snippetReport["childBoolFalse"] as? Bool, false)
        XCTAssertEqual(snippetReport["childInt"] as? Int, 7)
        XCTAssertNotNil(snippetReport["firstLegacyBool"] as? Bool)
        XCTAssertNotNil(snippetReport["secondLegacyBool"] as? Bool)

        let actionReport = CMActionStorageLoadCoverageReportForTesting()
        XCTAssertNotNil(actionReport["invalidFileClearsActions"] as? Bool)
        XCTAssertNotNil(actionReport["legacyDefaultReplaced"] as? Bool)
        XCTAssertTrue((actionReport["defaultActionCount"] as? Int ?? 0) > 0)
        XCTAssertNotNil(actionReport["userTitles"] as? [String])
        XCTAssertEqual(actionReport["relativePath"] as? String, "Case/UPPERCASE.js")
        XCTAssertEqual(actionReport["shortPath"] as? String, "Trim/Trim.js")
        XCTAssertEqual(actionReport["plainPath"] as? String, "Case/lowercase.js")
        XCTAssertNil(actionReport["absolutePathRejected"] as? String)
    }

    @MainActor
    func testNativeControlCoverageReportExercisesOffscreenControls() {
        let report = CMNativeControlCoverageReportForTesting()
        XCTAssertEqual(report["searchMenuItems"] as? Int, 3)
        XCTAssertEqual(report["selectedSearchScope"] as? String, "content")
        XCTAssertEqual(report["handledUndo"] as? Bool, true)
        XCTAssertEqual(report["nilEndEditing"] as? Bool, true)
        XCTAssertNotNil(report["invalidEditingBegan"] as? Bool)
        XCTAssertNotNil(report["invalidEditingEnded"] as? Bool)
        XCTAssertFalse((report["classNames"] as? [String])?.isEmpty ?? true)
    }

#endif
}
#endif
