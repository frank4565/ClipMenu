import XCTest
@testable import ClipMenu

final class MenuPreviewTests: XCTestCase {
    func testHistoryMenuKeepsSingletonBucketsAtTopLevel() {
        XCTAssertEqual(
            CMHistoryMenuGroups(clipCount: 2, inlineCount: 1, folderCount: 10),
            [.direct(0), .direct(1)]
        )
        XCTAssertEqual(
            CMHistoryMenuGroups(clipCount: 4, inlineCount: 1, folderCount: 2),
            [.direct(0), .folder(1..<3), .direct(3)]
        )
    }

    func testHistoryMenuPreservesMultiItemFolders() {
        XCTAssertEqual(
            CMHistoryMenuGroups(clipCount: 8, inlineCount: 2, folderCount: 3),
            [.direct(0), .direct(1), .folder(2..<5), .folder(5..<8)]
        )
    }

    func testTrimmedTitleUsesFirstLineAndEllipsisBudget() {
        XCTAssertEqual(CMMenuPreviewTrimmedTitle("  First line\nSecond line  ", limit: 80), "First line")
        XCTAssertEqual(CMMenuPreviewTrimmedTitle("abcdef", limit: 5), "ab...")
        XCTAssertEqual(CMMenuPreviewTrimmedTitle("abcdef", limit: 1), "...")
    }

    func testNumberedTitleAndKeyEquivalentRespectNumberingPreferences() {
        XCTAssertEqual(CMMenuPreviewNumberedTitle("Clip", listNumber: 3, markWithNumbers: true), "3. Clip")
        XCTAssertEqual(CMMenuPreviewNumberedTitle("Clip", listNumber: 3, markWithNumbers: false), "Clip")

        XCTAssertEqual(CMMenuPreviewKeyEquivalent(index: 0, markWithNumbers: true, startsFromZero: false), "1")
        XCTAssertEqual(CMMenuPreviewKeyEquivalent(index: 9, markWithNumbers: true, startsFromZero: false), "0")
        XCTAssertEqual(CMMenuPreviewKeyEquivalent(index: 0, markWithNumbers: true, startsFromZero: true), "0")
        XCTAssertEqual(CMMenuPreviewKeyEquivalent(index: 10, markWithNumbers: true, startsFromZero: true), "")
        XCTAssertEqual(CMMenuPreviewKeyEquivalent(index: 0, markWithNumbers: false, startsFromZero: true), "")
    }

    func testTooltipPreviewHonorsVisibilityAndNormalizedLength() {
        XCTAssertNil(CMMenuPreviewTooltip(text: "abcdef", maxLength: 3, showTooltips: false))
        XCTAssertEqual(CMMenuPreviewTooltip(text: "abcdef", maxLength: 3, showTooltips: true), "abc")
        XCTAssertEqual(CMMenuPreviewTooltip(text: "abcdef", maxLength: 0, showTooltips: true), "a")
        XCTAssertEqual(CMMenuPreviewTooltip(text: "abc", maxLength: 80, showTooltips: true), "abc")
    }

    func testPreferenceSnapshotStatesUseNormalizedValues() throws {
        let interval = CMObserveIntervalPreferencesSnapshotForDebug(timeInterval: 2.0)
        let intervalStates = try XCTUnwrap(interval["states"] as? [String: Any])
        XCTAssertEqual(intervalStates["timeInterval"] as? Double, 1.0)
        XCTAssertEqual(intervalStates["cadence"] as? String, "light")

        let retention = CMHistoryRetentionPreferencesSnapshotForDebug(
            maxHistorySize: 0,
            autosaveDelay: 61,
            saveHistoryOnQuit: false
        )
        let retentionStates = try XCTUnwrap(retention["states"] as? [String: Any])
        XCTAssertEqual(retentionStates["maxHistorySize"] as? Int, 1)
        XCTAssertEqual(retentionStates["autosaveDelay"] as? Int, 60)
        XCTAssertEqual(retentionStates["saveHistoryOnQuit"] as? Bool, false)
    }
}
