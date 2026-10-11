import AppKit
import XCTest

final class HistoryAutoPasteUITests: XCTestCase {
    private var clipMenu: XCUIApplication!
    private var textEdit: XCUIApplication?
    private var safari: XCUIApplication?
    private var readinessURL: URL!
    private var supportDirectoryURL: URL!
    private var textEditDocumentURL: URL?
    private var ownedTextEditWindow: XCUIElement?
    private var ownedSafariWindow: XCUIElement?
    private var originalFrontmostApplication: NSRunningApplication?
    private var originalPasteboardItems: [NSPasteboardItem] = []
    private var changedPasteboard = false

    private var requiresPasteAutomationPermission: Bool {
        !name.contains("testCommandNumberHistoryShortcutCopiesSelectionWithoutPastePermission")
    }

    override func setUpWithError() throws {
        continueAfterFailure = false

        originalFrontmostApplication = NSWorkspace.shared.frontmostApplication
        originalPasteboardItems = try copyPasteboardItems()

        readinessURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipMenuPasteReadiness-\(UUID().uuidString).json")
        supportDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipMenuHistoryAutoPasteUITests-\(UUID().uuidString)", isDirectory: true)
        clipMenu = XCUIApplication()
        clipMenu.launchArguments += [
            "-inputPasteCommand", requiresPasteAutomationPermission ? "YES" : "NO",
            "-enableAction", "NO",
            "-menuItemsAreMarkedWithNumbers", "YES",
            "-menuItemsTitleStartWithZero", "NO",
            "-numberOfItemsPlaceInline", "10",
            "-maxMenuItemTitleLength", "200",
            "-timeInterval", "0.1",
            "-showStatusItem", "1",
            "-showLabelsInMenu", "NO",
            "-debugPasteFlow", "YES",
            "-debugPasteAutomationReadinessPath", readinessURL.path
        ]
        if !requiresPasteAutomationPermission {
            // Give XCTest a visible accessibility surface for this menu-only
            // fixture; an inactive accessory app can stall its launch handshake.
            clipMenu.launchArguments += ["-debugShowPreferencesAfterLaunchDelay", "0.1"]
        }
        clipMenu.launchEnvironment["CLIPMENU_DEBUG_SUPPORT_DIRECTORY"] = supportDirectoryURL.path
        clipMenu.launch()

        let readinessWritten = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in FileManager.default.fileExists(atPath: self.readinessURL.path) },
            object: nil
        )
        wait(for: [readinessWritten], timeout: 5)
        let readinessData = try Data(contentsOf: readinessURL)
        let readiness = try XCTUnwrap(
            JSONSerialization.jsonObject(with: readinessData) as? [String: Any]
        )
        if requiresPasteAutomationPermission, readiness["canSynthesizePaste"] as? Bool != true {
            throw XCTSkip(
                "The built ClipMenu Debug app needs Accessibility or Post Events permission before real paste UI tests can run"
            )
        }
    }

    override func tearDownWithError() throws {
        // Only the isolated ClipMenu app belongs to this test. Never terminate a
        // user's Safari or TextEdit process, even when a test fails.
        clipMenu?.terminate()
        closeOwnedSafariWindow()
        closeOwnedTextEditWindow()
        if changedPasteboard {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            if !originalPasteboardItems.isEmpty {
                XCTAssertTrue(pasteboard.writeObjects(originalPasteboardItems), "Could not restore the original clipboard")
            }
        }
        if let readinessURL {
            try? FileManager.default.removeItem(at: readinessURL)
        }
        if let textEditDocumentURL {
            try? FileManager.default.removeItem(at: textEditDocumentURL)
        }
        if let supportDirectoryURL {
            try? FileManager.default.removeItem(at: supportDirectoryURL)
        }
        originalFrontmostApplication?.activate(options: [.activateIgnoringOtherApps])
    }

    func testSelectingHistoryMenuItemPastesIntoFrontmostTextView() throws {
        let expectedText = "ClipMenu real history paste \(UUID().uuidString)"
        let editor = try openOwnedTextEditDocument()
        try seedHistory(expectedText)
        let historyItem = try openHistoryMenu(containing: expectedText)
        historyItem.click()
        assertPastedWithoutFurtherInput(expectedText, into: editor)
    }

    func testCommandNumberHistoryShortcutCopiesSelectionWithoutPastePermission() throws {
        let expectedText = "ClipMenu native Command 1 \(UUID().uuidString)"
        try seedHistory(expectedText)
        let historyItem = try openHistoryMenu(containing: expectedText)
        // Change the clipboard while the native menu is tracking. Selecting
        // entry 1 must write its original text back, proving that Command-1
        // dispatched the menu action even when synthesized paste is disabled.
        let marker = "ClipMenu unselected clipboard marker \(UUID().uuidString)"
        try seedHistory(marker)
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), marker)
        historyItem.typeKey("1", modifierFlags: .command)

        let selected = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in NSPasteboard.general.string(forType: .string) == expectedText },
            object: nil
        )
        wait(for: [selected], timeout: 5)
    }

    func testCommandNumberHistoryShortcutPastesIntoTextEditWithoutAnotherKey() throws {
        let expectedText = "ClipMenu TextEdit Command 1 \(UUID().uuidString)"
        let editor = try openOwnedTextEditDocument()
        try seedHistory(expectedText)
        let historyItem = try openHistoryMenu(containing: expectedText)
        historyItem.typeKey("1", modifierFlags: .command)
        assertPastedWithoutFurtherInput(expectedText, into: editor)
    }

    func testMouseHistorySelectionPastesIntoSafariAddressBarWithoutAnotherKey() throws {
        let expectedText = "ClipMenu Safari mouse \(UUID().uuidString)"
        let addressBar = try openOwnedSafariAddressBar()
        try seedHistory(expectedText)
        let historyItem = try openHistoryMenu(containing: expectedText)
        historyItem.click()
        assertPastedWithoutFurtherInput(expectedText, into: addressBar)
    }

    func testCommandNumberHistoryShortcutPastesIntoSafariAddressBarWithoutAnotherKey() throws {
        let expectedText = "ClipMenu Safari Command 1 \(UUID().uuidString)"
        let addressBar = try openOwnedSafariAddressBar()
        try seedHistory(expectedText)
        let historyItem = try openHistoryMenu(containing: expectedText)
        historyItem.typeKey("1", modifierFlags: .command)
        assertPastedWithoutFurtherInput(expectedText, into: addressBar)
    }

    private func assertPastedWithoutFurtherInput(_ expectedText: String, into destination: XCUIElement) {
        // Reading the AX value is deliberately the only operation after history
        // selection. Activating, clicking, or typing could wake a delayed paste
        // and make the reported Safari regression appear to pass.
        let pasted = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in destination.value as? String == expectedText },
            object: nil
        )
        wait(for: [pasted], timeout: 5)
    }

    private func copyPasteboardItems() throws -> [NSPasteboardItem] {
        try (NSPasteboard.general.pasteboardItems ?? []).map { original in
            let copy = NSPasteboardItem()
            for type in original.types {
                guard let data = original.data(forType: type) else {
                    throw XCTSkip("The clipboard contains a representation that cannot be backed up safely")
                }
                guard copy.setData(data, forType: type) else {
                    throw XCTSkip("The clipboard contains a representation that cannot be restored safely")
                }
            }
            return copy
        }
    }

    private func seedHistory(_ text: String) throws {
        let pasteboard = NSPasteboard.general
        changedPasteboard = true
        pasteboard.clearContents()
        XCTAssertTrue(pasteboard.setString(text, forType: .string), "Could not seed the isolated history clipboard")
    }

    private func openHistoryMenu(containing expectedText: String) throws -> XCUIElement {
        let statusItem = clipMenu.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5), "ClipMenu status item did not appear")
        let historyItem = clipMenu.menuItems.matching(
            NSPredicate(format: "label == %@", "1. \(expectedText)")
        ).firstMatch
        // The first menu can open before the clipboard timer has captured the
        // fixture. Close it before retrying so menu tracking cannot hold up the
        // timer. These events occur before the selection under test.
        for _ in 0..<10 {
            try clickStatusItemUsingOwnedWindow(statusItem)
            if historyItem.waitForExistence(timeout: 0.5) {
                return historyItem
            }
            clipMenu.typeKey(.escape, modifierFlags: [])
        }
        XCTFail("The synthetic clipboard text did not become history entry 1")
        throw HistoryFixtureError.missingMenuItem
    }

    private func clickStatusItemUsingOwnedWindow(_ statusItem: XCUIElement) throws {
        // A menu bar extra has no window ancestor. XCTest can otherwise derive
        // an infinite display rect for its click even when its AX frame is valid.
        // Anchor the desktop point to the destination window, or to the visible
        // test Preferences window for the permission-independent shortcut case.
        let window = ownedSafariWindow ?? ownedTextEditWindow ?? clipMenu.windows.firstMatch
        guard window.waitForExistence(timeout: 5) else {
            XCTFail("No test-owned window is available to anchor the menu bar click")
            throw HistoryFixtureError.invalidClickGeometry
        }
        let statusFrame = statusItem.frame
        let windowFrame = window.frame
        guard hasFinitePositiveGeometry(statusFrame), hasFinitePositiveGeometry(windowFrame) else {
            XCTFail("The menu bar click requires finite status item and test-owned window frames")
            throw HistoryFixtureError.invalidClickGeometry
        }
        let target = CGPoint(x: statusFrame.midX, y: statusFrame.midY)
        let offset = CGVector(dx: target.x - windowFrame.minX, dy: target.y - windowFrame.minY)
        guard target.x.isFinite, target.y.isFinite, offset.dx.isFinite, offset.dy.isFinite else {
            XCTFail("The menu bar click target is not a finite desktop coordinate")
            throw HistoryFixtureError.invalidClickGeometry
        }
        let coordinate = window.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            .withOffset(offset)
        let resolvedPoint = coordinate.screenPoint
        guard resolvedPoint.x.isFinite, resolvedPoint.y.isFinite,
              abs(resolvedPoint.x - target.x) < 1, abs(resolvedPoint.y - target.y) < 1 else {
            XCTFail("The test-owned window moved before the menu bar click could be anchored")
            throw HistoryFixtureError.invalidClickGeometry
        }
        coordinate.click()
    }

    private func hasFinitePositiveGeometry(_ frame: CGRect) -> Bool {
        frame.origin.x.isFinite && frame.origin.y.isFinite
            && frame.width.isFinite && frame.height.isFinite
            && frame.width > 0 && frame.height > 0
    }

    private func openOwnedTextEditDocument() throws -> XCUIElement {
        let documentURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipMenuPasteDocument-\(UUID().uuidString).txt")
        textEditDocumentURL = documentURL
        try Data().write(to: documentURL)
        guard let applicationURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.TextEdit") else {
            throw XCTSkip("TextEdit is unavailable on this Mac")
        }
        textEdit = XCUIApplication(bundleIdentifier: "com.apple.TextEdit")
        let documentOpened = expectation(description: "Open the test-owned TextEdit document")
        var openingError: Error?
        NSWorkspace.shared.open(
            [documentURL], withApplicationAt: applicationURL, configuration: NSWorkspace.OpenConfiguration()
        ) { _, error in
            openingError = error
            documentOpened.fulfill()
        }
        wait(for: [documentOpened], timeout: 5)
        if let openingError { throw openingError }
        let textEdit = try XCTUnwrap(textEdit)
        let documentName = documentURL.deletingPathExtension().lastPathComponent
        let window = textEdit.windows.matching(NSPredicate(format: "label CONTAINS %@", documentName)).firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5), "TextEdit did not expose the test-owned document")
        ownedTextEditWindow = window
        let editor = window.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 5), "TextEdit did not expose an editable document")
        editor.click()
        XCTAssertEqual(editor.value as? String, "", "The test-owned TextEdit document must begin empty")
        return editor
    }

    private func openOwnedSafariAddressBar() throws -> XCUIElement {
        guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari") != nil else {
            throw XCTSkip("Safari is unavailable on this Mac")
        }
        let safari = XCUIApplication(bundleIdentifier: "com.apple.Safari")
        self.safari = safari
        let wasRunning = safari.state != .notRunning && safari.state != .unknown
        safari.activate()
        if !wasRunning {
            XCTAssertTrue(safari.windows.firstMatch.waitForExistence(timeout: 5), "Safari did not finish opening its initial window")
        }
        let originalWindowCount = safari.windows.count
        safari.typeKey("n", modifierFlags: .command)
        let windowCreated = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in safari.windows.count == originalWindowCount + 1 },
            object: nil
        )
        guard XCTWaiter.wait(for: [windowCreated], timeout: 5) == .completed else {
            XCTFail("Safari did not create a new test-owned window")
            throw HistoryFixtureError.missingSafariWindow
        }
        // No navigation or additional Safari windows are created. This new
        // front window remains the only Safari window touched by the test.
        let window = safari.windows.element(boundBy: 0)
        ownedSafariWindow = window
        safari.typeKey("l", modifierFlags: .command)
        safari.typeKey(.delete, modifierFlags: [])
        let namedAddressBar = window.textFields.matching(
            NSPredicate(format: "identifier == %@ OR label == %@", "Address and Search", "Address and Search")
        ).firstMatch
        let addressBar = namedAddressBar.exists ? namedAddressBar : window.toolbars.textFields.firstMatch
        XCTAssertTrue(addressBar.waitForExistence(timeout: 5), "Safari did not expose its address bar")
        XCTAssertEqual(addressBar.value as? String, "", "Safari's address bar must begin empty")
        return addressBar
    }

    private func closeOwnedSafariWindow() {
        guard let safari, let window = ownedSafariWindow, window.exists else { return }
        safari.activate()
        window.buttons[XCUIIdentifierCloseWindow].click()
    }

    private func closeOwnedTextEditWindow() {
        guard let textEdit, let window = ownedTextEditWindow, window.exists else { return }
        textEdit.activate()
        window.buttons[XCUIIdentifierCloseWindow].click()
        if window.sheets.firstMatch.waitForExistence(timeout: 1) {
            // Command-Delete dismisses TextEdit's save sheet with Don't Save
            // without depending on the system's display language.
            textEdit.typeKey(.delete, modifierFlags: .command)
        }
    }

    private enum HistoryFixtureError: Error {
        case missingMenuItem
        case missingSafariWindow
        case invalidClickGeometry
    }
}
