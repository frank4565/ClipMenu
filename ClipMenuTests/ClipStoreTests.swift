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

    func testAddingDistinctTextClipsAppendsWithoutReplacingExistingEntries() {
        UserDefaults.standard.set(20, forKey: CMPrefMaxHistorySizeKey)
        let store = ClipStore()
        let clips = ["first copy", "second copy", "third copy"].enumerated().map { index, text in
            let date = Date(timeIntervalSince1970: TimeInterval(index + 1))
            return ClipItem(text: text, createdAt: date, lastUsedAt: date)
        }

        for (index, clip) in clips.enumerated() {
            store.add(clip)
            XCTAssertEqual(store.clips, Array(clips.prefix(index + 1)))
        }

        XCTAssertTrue(store.debugHasUnsavedChanges)
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

    func testHistoryLimitOfOneIntentionallyRetainsOnlyLatestDistinctClip() {
        UserDefaults.standard.set(1, forKey: CMPrefMaxHistorySizeKey)
        UserDefaults.standard.set(false, forKey: CMPrefReorderClipsAfterPasting)
        let store = ClipStore()
        let clips = ["one", "two", "three"].enumerated().map { index, text in
            let date = Date(timeIntervalSince1970: TimeInterval(index + 1))
            return ClipItem(text: text, createdAt: date, lastUsedAt: date)
        }

        for clip in clips {
            store.add(clip)
            XCTAssertEqual(store.clips, [clip])
        }
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

    func testAsyncSaveLeavesMainResponsiveWhileTheWriterIsBlocked() throws {
        let (store, directory) = try makeIsolatedPersistenceStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let gate = PersistenceWriterGate()
        defer { gate.release.signal() }
        store.debugBeforePersistenceWriteForTesting = { gate.blockWriter() }
        store.add(ClipItem(text: "background snapshot"))
        let saved = expectation(description: "background save completes on main")
        var completionCalled = false

        let started = ProcessInfo.processInfo.systemUptime
        store.saveIfNeededAsync { success in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertTrue(success)
            completionCalled = true
            saved.fulfill()
        }
        XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - started, 0.1)
        XCTAssertTrue(gate.waitUntilEntered())

        let mainResponsive = expectation(description: "main work executes before writer is released")
        DispatchQueue.main.async {
            XCTAssertFalse(completionCalled)
            XCTAssertTrue(store.debugHasUnsavedChanges)
            mainResponsive.fulfill()
        }
        wait(for: [mainResponsive], timeout: 1)
        XCTAssertEqual(gate.mainThreadWriteCount, 0)
        gate.release.signal()
        wait(for: [saved], timeout: 3)
        XCTAssertFalse(store.debugHasUnsavedChanges)
    }

    func testAsyncRequestsForTheSameRevisionShareOneWrite() throws {
        let (store, directory) = try makeIsolatedPersistenceStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let gate = PersistenceWriterGate()
        defer { gate.release.signal() }
        store.debugBeforePersistenceWriteForTesting = { gate.blockWriter() }
        store.add(ClipItem(text: "one revision"))
        let first = expectation(description: "first save request")
        let second = expectation(description: "coalesced save request")
        store.saveIfNeededAsync { success in
            XCTAssertTrue(success)
            first.fulfill()
        }
        XCTAssertTrue(gate.waitUntilEntered())
        store.saveIfNeededAsync { success in
            XCTAssertTrue(success)
            second.fulfill()
        }

        gate.release.signal()
        wait(for: [first, second], timeout: 3)
        XCTAssertEqual(gate.writeCount, 1)
        XCTAssertFalse(store.debugHasUnsavedChanges)
    }

    func testOlderAsyncSaveDoesNotClearNewerUnsavedChanges() throws {
        let (store, directory) = try makeIsolatedPersistenceStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let gate = PersistenceWriterGate()
        defer { gate.release.signal() }
        store.debugBeforePersistenceWriteForTesting = { gate.blockWriter() }
        store.add(ClipItem(text: "older"))
        let olderSaved = expectation(description: "older snapshot saved")
        store.saveIfNeededAsync { success in
            XCTAssertTrue(success)
            olderSaved.fulfill()
        }
        XCTAssertTrue(gate.waitUntilEntered())
        store.add(ClipItem(text: "newer"))
        store.debugBeforePersistenceWriteForTesting = nil

        gate.release.signal()
        wait(for: [olderSaved], timeout: 3)
        XCTAssertTrue(store.debugHasUnsavedChanges)
        XCTAssertEqual(try persistedJSONClips(in: directory).map(\.text), ["older"])

        let newerSaved = expectation(description: "newer snapshot saved")
        store.saveIfNeededAsync { success in
            XCTAssertTrue(success)
            newerSaved.fulfill()
        }
        wait(for: [newerSaved], timeout: 3)
        XCTAssertFalse(store.debugHasUnsavedChanges)
        XCTAssertEqual(try persistedJSONClips(in: directory).map(\.text), ["older", "newer"])
    }

    func testSynchronousFinalSaveRunsAfterPendingAsyncWrites() throws {
        let (store, directory) = try makeIsolatedPersistenceStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let gate = PersistenceWriterGate()
        defer { gate.release.signal() }
        store.debugBeforePersistenceWriteForTesting = { gate.blockWriter() }
        store.add(ClipItem(text: "older"))
        let earlierSave = expectation(description: "earlier async save completion")
        store.saveIfNeededAsync { success in
            XCTAssertTrue(success)
            earlierSave.fulfill()
        }
        XCTAssertTrue(gate.waitUntilEntered())
        store.add(ClipItem(text: "final"))
        store.debugBeforePersistenceWriteForTesting = nil

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.02) { gate.release.signal() }
        XCTAssertTrue(store.save())
        XCTAssertFalse(store.debugHasUnsavedChanges)
        wait(for: [earlierSave], timeout: 3)
        XCTAssertFalse(store.debugHasUnsavedChanges)
        XCTAssertEqual(try persistedJSONClips(in: directory).map(\.text), ["older", "final"])
    }

    func testRemovalWaitsForPendingWritesAndOldCompletionCannotRecreateHistory() throws {
        let (store, directory) = try makeIsolatedPersistenceStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let gate = PersistenceWriterGate()
        defer { gate.release.signal() }
        store.debugBeforePersistenceWriteForTesting = { gate.blockWriter() }
        store.add(ClipItem(text: "discard on quit"))
        let earlierSave = expectation(description: "earlier async save completion")
        store.saveIfNeededAsync { success in
            XCTAssertTrue(success)
            earlierSave.fulfill()
        }
        XCTAssertTrue(gate.waitUntilEntered())

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.02) { gate.release.signal() }
        store.removeSavedHistory()
        wait(for: [earlierSave], timeout: 3)
        XCTAssertFalse(store.debugHasUnsavedChanges)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("clips.data").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("clips.json").path))
    }

    func testLoadWaitsForAnEarlierAsyncWriteFromAnotherStore() throws {
        let (store, directory) = try makeIsolatedPersistenceStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let gate = PersistenceWriterGate()
        defer { gate.release.signal() }
        store.debugBeforePersistenceWriteForTesting = { gate.blockWriter() }
        store.add(ClipItem(text: "visible to another store"))
        let earlierSave = expectation(description: "earlier async save completion")
        store.saveIfNeededAsync { success in
            XCTAssertTrue(success)
            earlierSave.fulfill()
        }
        XCTAssertTrue(gate.waitUntilEntered())
        let reloaded = ClipStore()
        reloaded.debugPersistenceDirectoryForTesting = directory

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.02) { gate.release.signal() }
        reloaded.load()
        XCTAssertEqual(reloaded.clips.map(\.text), ["visible to another store"])
        wait(for: [earlierSave], timeout: 3)
    }

    func testAsyncSaveUsesTheCapturedDestination() throws {
        let (store, directory) = try makeIsolatedPersistenceStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let (_, laterDirectory) = try makeIsolatedPersistenceStore()
        defer { try? FileManager.default.removeItem(at: laterDirectory) }
        let gate = PersistenceWriterGate()
        defer { gate.release.signal() }
        store.debugBeforePersistenceWriteForTesting = { gate.blockWriter() }
        store.add(ClipItem(text: "original destination"))
        let saved = expectation(description: "snapshot saved to captured directory")
        store.saveIfNeededAsync { success in
            XCTAssertTrue(success)
            saved.fulfill()
        }
        XCTAssertTrue(gate.waitUntilEntered())
        store.debugPersistenceDirectoryForTesting = laterDirectory
        gate.release.signal()
        wait(for: [saved], timeout: 3)

        XCTAssertEqual(try persistedJSONClips(in: directory).map(\.text), ["original destination"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: laterDirectory.appendingPathComponent("clips.data").path))
        XCTAssertTrue(store.debugHasUnsavedChanges)

        store.debugBeforePersistenceWriteForTesting = nil
        let savedToNewDestination = expectation(description: "same revision saved to new destination")
        store.saveIfNeededAsync { success in
            XCTAssertTrue(success)
            savedToNewDestination.fulfill()
        }
        wait(for: [savedToNewDestination], timeout: 3)
        XCTAssertFalse(store.debugHasUnsavedChanges)
        XCTAssertEqual(try persistedJSONClips(in: laterDirectory).map(\.text), ["original destination"])
    }

    func testFailedAsyncSaveRemainsDirtyAndCanRetryTheSameRevision() throws {
        let (store, directory) = try makeIsolatedPersistenceStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let archiveURL = directory.appendingPathComponent("clips.data", isDirectory: true)
        try FileManager.default.createDirectory(at: archiveURL, withIntermediateDirectories: false)
        store.add(ClipItem(text: "retry after a write failure"))
        let failed = expectation(description: "failed save")
        store.saveIfNeededAsync { success in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertFalse(success)
            failed.fulfill()
        }
        wait(for: [failed], timeout: 3)
        XCTAssertTrue(store.debugHasUnsavedChanges)

        try FileManager.default.removeItem(at: archiveURL)
        let retried = expectation(description: "successful retry")
        store.saveIfNeededAsync { success in
            XCTAssertTrue(success)
            retried.fulfill()
        }
        wait(for: [retried], timeout: 3)
        XCTAssertFalse(store.debugHasUnsavedChanges)
        XCTAssertEqual(try persistedJSONClips(in: directory).map(\.text), ["retry after a write failure"])
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

    private func makeIsolatedPersistenceStore() throws -> (ClipStore, URL) {
        UserDefaults.standard.set(10, forKey: CMPrefMaxHistorySizeKey)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipMenuPersistenceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = ClipStore()
        store.debugPersistenceDirectoryForTesting = directory
        return (store, directory)
    }

    private func persistedJSONClips(in directory: URL) throws -> [ClipItem] {
        let data = try Data(contentsOf: directory.appendingPathComponent("clips.json"))
        return try JSONDecoder().decode([ClipItem].self, from: data)
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

private final class PersistenceWriterGate {
    let release = DispatchSemaphore(value: 0)
    private let entered = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var writes = 0
    private var mainThreadWrites = 0

    var writeCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return writes
    }

    var mainThreadWriteCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return mainThreadWrites
    }

    func blockWriter() {
        lock.lock()
        writes += 1
        if Thread.isMainThread {
            mainThreadWrites += 1
        }
        lock.unlock()
        entered.signal()
        _ = release.wait(timeout: .now() + 5)
    }

    func waitUntilEntered() -> Bool {
        entered.wait(timeout: .now() + 2) == .success
    }
}
