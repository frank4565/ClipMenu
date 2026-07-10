import AppKit
import XCTest
@testable import ClipMenu

final class ClipStoreTests: XCTestCase {
    private var defaultsSnapshot: [String: Any?] = [:]

    override func setUp() {
        super.setUp()
        snapshotDefaults([
            CMPrefReorderClipsAfterPasting,
            CMPrefMaxHistorySizeKey,
            CMPrefTagOfSeparatorForExportHistoryToFileKey
        ])
    }

    override func tearDown() {
        restoreDefaults()
        super.tearDown()
    }

    func testAddingDuplicateClipPromotesExistingEntryInsteadOfAppending() {
        UserDefaults.standard.set(10, forKey: CMPrefMaxHistorySizeKey)
        let store = ClipStore()
        let original = ClipItem(text: "same", createdAt: Date(timeIntervalSince1970: 10), lastUsedAt: Date(timeIntervalSince1970: 10))
        let duplicate = ClipItem(text: "same", createdAt: Date(timeIntervalSince1970: 20), lastUsedAt: Date(timeIntervalSince1970: 20))

        store.add(original)
        store.add(duplicate)

        XCTAssertEqual(store.clips.count, 1)
        XCTAssertEqual(store.clips[0].text, "same")
        XCTAssertGreaterThan(store.clips[0].lastUsedAt, original.lastUsedAt)
        XCTAssertTrue(store.debugHasUnsavedChanges)
    }

    func testOrderedClipsCanSortByCreationOrLastUsedDate() {
        UserDefaults.standard.set(10, forKey: CMPrefMaxHistorySizeKey)
        let store = ClipStore()
        let olderCreatedRecentUse = ClipItem(
            text: "older-created",
            createdAt: Date(timeIntervalSince1970: 10),
            lastUsedAt: Date(timeIntervalSince1970: 100)
        )
        let newerCreatedOlderUse = ClipItem(
            text: "newer-created",
            createdAt: Date(timeIntervalSince1970: 20),
            lastUsedAt: Date(timeIntervalSince1970: 50)
        )

        store.add(olderCreatedRecentUse)
        store.add(newerCreatedOlderUse)

        UserDefaults.standard.set(false, forKey: CMPrefReorderClipsAfterPasting)
        XCTAssertEqual(store.orderedClips.map(\.text), ["newer-created", "older-created"])

        UserDefaults.standard.set(true, forKey: CMPrefReorderClipsAfterPasting)
        XCTAssertEqual(store.orderedClips.map(\.text), ["older-created", "newer-created"])
    }

    func testTrimHonorsNormalizedHistoryLimit() {
        UserDefaults.standard.set(2, forKey: CMPrefMaxHistorySizeKey)
        UserDefaults.standard.set(false, forKey: CMPrefReorderClipsAfterPasting)
        let store = ClipStore()

        store.add(ClipItem(text: "one", createdAt: Date(timeIntervalSince1970: 1)))
        store.add(ClipItem(text: "two", createdAt: Date(timeIntervalSince1970: 2)))
        store.add(ClipItem(text: "three", createdAt: Date(timeIntervalSince1970: 3)))

        XCTAssertEqual(store.clips.map(\.text), ["three", "two"])
    }

    func testExportsOnlyTextClipsWithSelectedSeparator() throws {
        UserDefaults.standard.set(10, forKey: CMPrefMaxHistorySizeKey)
        UserDefaults.standard.set(false, forKey: CMPrefReorderClipsAfterPasting)
        UserDefaults.standard.set(1, forKey: CMPrefTagOfSeparatorForExportHistoryToFileKey)
        let store = ClipStore()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipMenuTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        store.add(ClipItem(text: "one", createdAt: Date(timeIntervalSince1970: 1)))
        store.add(ClipItem(types: [NSPasteboard.PasteboardType.pdf.rawValue], createdAt: Date(timeIntervalSince1970: 2), pdfData: Data([1])))
        store.add(ClipItem(text: "three", createdAt: Date(timeIntervalSince1970: 3)))

        let singleFileURL = directory.appendingPathComponent("clips.txt")
        try store.exportTextClipsAsSingleFile(to: singleFileURL)
        XCTAssertEqual(try String(contentsOf: singleFileURL, encoding: .utf8), "three\none\n")

        try store.exportTextClipsAsMultipleFiles(to: directory)
        XCTAssertEqual(try String(contentsOf: directory.appendingPathComponent("1.txt"), encoding: .utf8), "three")
        XCTAssertEqual(try String(contentsOf: directory.appendingPathComponent("3.txt"), encoding: .utf8), "one")
    }

    func testMutationHelpersAndSaveIfNeededTrackDirtyState() {
        UserDefaults.standard.set(10, forKey: CMPrefMaxHistorySizeKey)
        let store = ClipStore()
        let first = ClipItem(text: "one", createdAt: Date(timeIntervalSince1970: 1), lastUsedAt: Date(timeIntervalSince1970: 1))
        let second = ClipItem(text: "two", createdAt: Date(timeIntervalSince1970: 2), lastUsedAt: Date(timeIntervalSince1970: 2))

        XCTAssertFalse(store.hasTextClips)
        XCTAssertTrue(store.saveIfNeeded())
        store.add(first)
        store.add(second)
        XCTAssertTrue(store.hasTextClips)
        XCTAssertEqual(store.clip(with: first.id.uuidString)?.text, "one")
        XCTAssertNil(store.clip(with: "not-a-uuid"))

        store.promote(first.id)
        XCTAssertTrue(store.debugHasUnsavedChanges)
        store.remove(second.id)
        XCTAssertEqual(store.clips.map(\.text), ["one"])
        store.clear()
        XCTAssertTrue(store.clips.isEmpty)
        XCTAssertTrue(store.debugHasUnsavedChanges)
    }

    func testSaveLoadAndRemoveSavedHistoryRoundTrip() {
        UserDefaults.standard.set(10, forKey: CMPrefMaxHistorySizeKey)
        UserDefaults.standard.set(false, forKey: CMPrefReorderClipsAfterPasting)
        let store = ClipStore()
        store.removeSavedHistory()
        defer { store.removeSavedHistory() }

        store.add(ClipItem(text: "persisted", createdAt: Date(timeIntervalSince1970: 1)))
        XCTAssertTrue(store.save())
        XCTAssertFalse(store.debugHasUnsavedChanges)

        let reloaded = ClipStore()
        reloaded.load()
        XCTAssertEqual(reloaded.clips.map(\.text), ["persisted"])

        reloaded.removeSavedHistory()
        let empty = ClipStore()
        empty.load()
        XCTAssertTrue(empty.clips.isEmpty)
    }

#if TESTING
    func testLegacyLoadReportMigratesArchiveAndWritesJSONSidecar() {
        UserDefaults.standard.set(10, forKey: CMPrefMaxHistorySizeKey)
        let report = ClipStore().debugLegacyLoadReportForTesting()
        XCTAssertEqual(report["matchesExpected"] as? Bool, true)
    }
#endif

    private func snapshotDefaults(_ keys: [String]) {
        defaultsSnapshot = Dictionary(uniqueKeysWithValues: keys.map { ($0, UserDefaults.standard.object(forKey: $0)) })
    }

    private func restoreDefaults() {
        for (key, value) in defaultsSnapshot {
            if let value {
                UserDefaults.standard.set(value, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }
}
