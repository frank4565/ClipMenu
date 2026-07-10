import XCTest

final class HistoryAutoPasteUITests: XCTestCase {
    private var clipMenu: XCUIApplication!
    private var textEdit: XCUIApplication!
    private var readinessURL: URL!

    override func setUpWithError() throws {
        continueAfterFailure = false

        readinessURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipMenuPasteReadiness-\(UUID().uuidString).json")
        clipMenu = XCUIApplication()
        clipMenu.launchArguments += [
            "-inputPasteCommand", "YES",
            "-enableAction", "NO",
            "-timeInterval", "0.1",
            "-showStatusItem", "1",
            "-showLabelsInMenu", "NO",
            "-debugPasteFlow", "YES",
            "-debugPasteAutomationReadinessPath", readinessURL.path
        ]
        clipMenu.launchEnvironment["CLIPMENU_DEBUG_SUPPORT_DIRECTORY"] = NSTemporaryDirectory()
            + "ClipMenuHistoryAutoPasteUITests-\(UUID().uuidString)"
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
        guard readiness["canSynthesizePaste"] as? Bool == true else {
            throw XCTSkip(
                "The built ClipMenu app needs Accessibility or Post Events permission before the real Command-V UI test can run"
            )
        }

        textEdit = XCUIApplication(bundleIdentifier: "com.apple.TextEdit")
        textEdit.launch()
        textEdit.typeKey("n", modifierFlags: .command)
    }

    override func tearDownWithError() throws {
        textEdit?.terminate()
        clipMenu?.terminate()
        if let readinessURL {
            try? FileManager.default.removeItem(at: readinessURL)
        }
    }

    func testSelectingHistoryMenuItemPastesIntoFrontmostTextView() throws {
        let expectedText = "ClipMenu real history paste \(UUID().uuidString)"
        let editor = textEdit.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 5), "TextEdit did not expose an editable document")

        editor.click()
        editor.typeText(expectedText)
        editor.typeKey("a", modifierFlags: .command)
        editor.typeKey("c", modifierFlags: .command)
        editor.typeKey(.delete, modifierFlags: [])

        let statusItem = clipMenu.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5), "ClipMenu status item did not appear")
        statusItem.click()
        let firstHistoryItem = clipMenu.menuItems.firstMatch
        XCTAssertTrue(firstHistoryItem.waitForExistence(timeout: 5), "ClipMenu history menu did not expose its first item")
        firstHistoryItem.click()

        let pasted = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", expectedText),
            object: editor
        )
        wait(for: [pasted], timeout: 5)
    }
}
