import AppKit
import XCTest
@testable import ClipMenu

final class AlertFactoryTests: XCTestCase {
    private struct FixtureError: LocalizedError {
        let errorDescription: String?
    }

    func testSnippetFailureAlertsExposeUserFacingMessagesAndAccessories() {
        assertAlert(
            CMMakeSnippetSaveFailureAlert(FixtureError(errorDescription: "Disk full")),
            messageText: "Could not save snippets.",
            informativeText: "Disk full"
        )
        assertAlert(
            CMMakeSnippetImportFailureAlert(FixtureError(errorDescription: "Bad XML")),
            messageText: "Failed to parse XML file",
            informativeText: "Bad XML"
        )
        assertAlert(
            CMMakeSnippetExportFailureAlert(FixtureError(errorDescription: "Permission denied")),
            messageText: "Could not write document out...",
            informativeText: "Permission denied"
        )
    }

    func testActionSaveFailureAlertExposesUserFacingMessagesAndAccessory() {
        assertAlert(
            CMMakeActionSaveFailureAlert(FixtureError(errorDescription: "Read-only folder")),
            messageText: "Could not save actions.",
            informativeText: "Read-only folder"
        )
    }

    func testUnableToEndEditingAndGenericAlertsHaveExpectedButtons() {
        let editingAlert = CMMakeUnableToEndEditingAlert()
        XCTAssertEqual(editingAlert.messageText, "Unable to end editing")
        XCTAssertEqual(editingAlert.buttons.map(\.title), ["OK"])
        XCTAssertNotNil(editingAlert.accessoryView)

        let genericAlert = CMMakeGenericSnippetAlert(messageText: "Title", informativeText: "Detail")
        XCTAssertEqual(genericAlert.messageText, "Title")
        XCTAssertEqual(genericAlert.informativeText, "Detail")
        XCTAssertEqual(genericAlert.buttons.map(\.title), ["OK"])
    }

    private func assertAlert(
        _ alert: NSAlert,
        messageText: String,
        informativeText: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(alert.messageText, messageText, file: file, line: line)
        XCTAssertEqual(alert.informativeText, informativeText, file: file, line: line)
        XCTAssertEqual(alert.buttons.map(\.title), ["OK"], file: file, line: line)
        XCTAssertNotNil(alert.accessoryView, file: file, line: line)
    }
}
