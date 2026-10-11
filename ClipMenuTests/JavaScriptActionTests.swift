import XCTest
@testable import ClipMenu

#if TESTING
final class JavaScriptActionTests: XCTestCase {
    func testJavaScriptActionReturnsMutatedClipAndStrings() throws {
        let controller = AppController()

        let clipScript = try temporaryScript(
            """
            clip.stringValue = clip.stringValue.toUpperCase();
            return clip;
            """
        )
        let stringScript = try temporaryScript("return clip.stringValue + ' suffix';")
        let undefinedScript = try temporaryScript("return;")
        defer {
            try? FileManager.default.removeItem(at: clipScript)
            try? FileManager.default.removeItem(at: stringScript)
            try? FileManager.default.removeItem(at: undefinedScript)
        }

        XCTAssertEqual(
            controller.debugRunJavaScriptActionForTesting(at: clipScript.path, clip: ClipItem(text: "testing"))?.text,
            "TESTING"
        )
        XCTAssertEqual(
            controller.debugRunJavaScriptActionForTesting(at: stringScript.path, clip: ClipItem(text: "testing"))?.text,
            "testing suffix"
        )
        XCTAssertNil(
            controller.debugRunJavaScriptActionForTesting(at: undefinedScript.path, clip: ClipItem(text: "testing"))
        )
        XCTAssertNil(
            controller.debugRunJavaScriptActionForTesting(at: clipScript.path, clip: ClipItem(text: ""))
        )
    }

    func testJavaScriptActionErrorBranchesReturnNilWithoutPresentingAlerts() throws {
        let defaults = UserDefaults.standard
        let originalAlertLogging = defaults.object(forKey: "debugJavaScriptAlertsAreLogged")
        defaults.set(true, forKey: "debugJavaScriptAlertsAreLogged")
        defer {
            if let originalAlertLogging {
                defaults.set(originalAlertLogging, forKey: "debugJavaScriptAlertsAreLogged")
            } else {
                defaults.removeObject(forKey: "debugJavaScriptAlertsAreLogged")
            }
        }

        let controller = AppController()
        let syntaxScript = try temporaryScript("function () {")
        let throwingScript = try temporaryScript("throw new Error('boom');")
        let requireScript = try temporaryScript("return ClipMenu.require('missing-library');")
        defer {
            try? FileManager.default.removeItem(at: syntaxScript)
            try? FileManager.default.removeItem(at: throwingScript)
            try? FileManager.default.removeItem(at: requireScript)
        }

        XCTAssertNil(controller.debugRunJavaScriptActionForTesting(
            at: "/tmp/clipmenu-missing-\(UUID().uuidString).js",
            clip: ClipItem(text: "testing")
        ))
        XCTAssertNil(controller.debugRunJavaScriptActionForTesting(at: syntaxScript.path, clip: ClipItem(text: "testing")))
        XCTAssertNil(controller.debugRunJavaScriptActionForTesting(at: throwingScript.path, clip: ClipItem(text: "testing")))
        XCTAssertEqual(
            controller.debugRunJavaScriptActionForTesting(at: requireScript.path, clip: ClipItem(text: "testing"))?.text,
            "false"
        )
    }

    func testScriptableActionClipAppliesFormattingAttributes() {
        let report = CMDebugScriptableActionClipFormattingReportForTesting()
        XCTAssertEqual(report["available"] as? Bool, true)
        XCTAssertEqual(report["richText"] as? String, "Styled")
        XCTAssertEqual(report["hasRTF"] as? Bool, true)
        XCTAssertEqual(report["emptyHasRTF"] as? Bool, false)
    }

    @MainActor
    func testActionDispatchReportCoversInertModifierPaths() {
        let report = AppController().debugActionDispatchReportForTesting()
        XCTAssertEqual(report["disabled"] as? Bool, false)
        XCTAssertEqual(report["noContext"] as? Bool, false)
        XCTAssertEqual(report["emptyControl"] as? Bool, false)
        XCTAssertEqual(report["unknownShift"] as? Bool, false)
        XCTAssertEqual(report["directOption"] as? Bool, true)
        XCTAssertFalse(report.isEmpty)
    }

    @MainActor
    func testRuntimeActionModelReportCoversDefaultDetectionAndPaths() {
        let report = AppController().debugRuntimeActionModelReportForTesting()
        XCTAssertGreaterThanOrEqual(report["defaultNodeCount"] as? Int ?? 0, 2)
        XCTAssertEqual(report["legacyDefaultDetected"] as? Bool, true)
        XCTAssertEqual(report["customDefaultDetected"] as? Bool, false)
        XCTAssertEqual(report["relativeBundledPath"] as? String, "Case/UPPERCASE.js")
        XCTAssertEqual(report["shortBundledPath"] as? String, "Trim/Trim.js")
        XCTAssertEqual(report["plainRelativePath"] as? String, "Case/lowercase.js")
        XCTAssertNil(report["absoluteNonBundledPath"] as? String)
    }

    private func temporaryScript(_ source: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipMenuJavaScriptActionTests-\(UUID().uuidString).js")
        try source.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
#endif
