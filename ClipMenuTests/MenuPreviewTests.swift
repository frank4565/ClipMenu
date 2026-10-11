import AppKit
import UniformTypeIdentifiers
import XCTest
@testable import ClipMenu

final class MenuPreviewTests: XCTestCase {
    @MainActor
    func testLegacyHFSIconsMatchSystemContentTypes() throws {
        let cases: [(String, UTType)] = [
            ("TEXT", .plainText),
            ("fold", .folder),
            ("ofld", try XCTUnwrap(UTType("com.apple.legacy.open-folder"))),
            ("clpt", try XCTUnwrap(UTType("com.apple.finder.textclipping"))),
            ("clpu", try XCTUnwrap(UTType("com.apple.finder.clipping"))),
            ("gurl", .url),
            ("PDF ", .pdf)
        ]
        for (hfsTag, contentType) in cases {
            let icon = CMIconForLegacyHFSType(NSHFSTypeCodeFromFileType("'\(hfsTag)'"))
            XCTAssertEqual(
                try iconPixels(icon),
                try iconPixels(NSWorkspace.shared.icon(for: contentType)),
                "HFS type \(hfsTag) should keep its system icon"
            )
        }
    }

    @MainActor
    func testUnknownLegacyHFSIconMatchesFileMetadata() throws {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data().write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let hfsType = NSHFSTypeCodeFromFileType("'ABCD'")
        try FileManager.default.setAttributes(
            [.hfsTypeCode: NSNumber(value: hfsType)],
            ofItemAtPath: fileURL.path
        )

        XCTAssertEqual(
            try iconPixels(CMIconForLegacyHFSType(hfsType)),
            try iconPixels(NSWorkspace.shared.icon(forFile: fileURL.path))
        )
    }

    @MainActor
    func testFileTypeIconsAcceptExtensionsTypeIdentifiersAndQuotedHFSTypes() throws {
        for (fileType, contentType) in [("pdf", UTType.pdf), ("public.jpeg", .jpeg), ("'fold'", .folder), ("", .data)] {
            XCTAssertEqual(
                try iconPixels(CMIconForFileType(fileType)),
                try iconPixels(NSWorkspace.shared.icon(for: contentType)),
                "File type \(fileType) should resolve its system icon"
            )
        }

        let filenameExtension = "clipmenu-unknown-extension"
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(filenameExtension)
        try Data().write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let expectedPixels = try iconPixels(NSWorkspace.shared.icon(forFile: fileURL.path))
        XCTAssertEqual(try iconPixels(CMIconForFileType(filenameExtension)), expectedPixels)
        let dynamicType = try XCTUnwrap(UTType(filenameExtension: filenameExtension))
        XCTAssertTrue(dynamicType.isDynamic)
        XCTAssertEqual(try iconPixels(CMIconForFileType(dynamicType.identifier)), expectedPixels)
    }

    @MainActor
    private func iconPixels(_ image: NSImage) throws -> Data {
        let bitmap = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 32,
            pixelsHigh: 32,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 128,
            bitsPerPixel: 32
        ))
        let pixels = try XCTUnwrap(bitmap.bitmapData)
        let byteCount = bitmap.bytesPerRow * bitmap.pixelsHigh
        pixels.update(repeating: 0, count: byteCount)
        let context = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap))
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = context
        image.draw(in: NSRect(x: 0, y: 0, width: 32, height: 32), from: .zero, operation: .copy, fraction: 1)
        return Data(bytes: pixels, count: byteCount)
    }

    func testHistoryMenuKeepsIncompleteBucketsAtTopLevel() {
        XCTAssertEqual(
            CMHistoryMenuGroups(clipCount: 2, inlineCount: 1, folderCount: 10),
            [.direct(0), .direct(1)]
        )
        XCTAssertEqual(
            CMHistoryMenuGroups(clipCount: 4, inlineCount: 1, folderCount: 10),
            [.direct(0), .direct(1), .direct(2), .direct(3)]
        )
        XCTAssertEqual(
            CMHistoryMenuGroups(clipCount: 6, inlineCount: 1, folderCount: 3),
            [.direct(0), .folder(1..<4), .direct(4), .direct(5)]
        )
    }

    func testHistoryMenuKeepsSingleOverflowPageAtTopLevel() {
        XCTAssertEqual(
            CMHistoryMenuGroups(clipCount: 11, inlineCount: 1, folderCount: 10),
            (0..<11).map(CMHistoryMenuGroup.direct)
        )
        XCTAssertEqual(
            CMHistoryMenuGroups(clipCount: 10, inlineCount: 0, folderCount: 10),
            (0..<10).map(CMHistoryMenuGroup.direct)
        )
        XCTAssertEqual(
            CMHistoryMenuGroups(clipCount: 12, inlineCount: 1, folderCount: 10),
            [.direct(0), .folder(1..<11), .direct(11)]
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

    func testPreferencesWindowFitsCompactVisibleScreenIncludingToolbar() {
        let visibleFrame = NSRect(x: 0, y: 0, width: 1280, height: 720)
        let chromeHeight: CGFloat = 80
        let contentSize = CMPreferencesContentSize(
            preferredHeight: 1200,
            visibleFrame: visibleFrame,
            windowChromeHeight: chromeHeight
        )

        XCTAssertEqual(contentSize.width, 760)
        XCTAssertEqual(contentSize.height, 616)
        XCTAssertLessThanOrEqual(contentSize.height + chromeHeight, visibleFrame.height - 24)
        XCTAssertEqual(
            CMPreferencesContentSize(
                preferredHeight: 180,
                visibleFrame: visibleFrame,
                windowChromeHeight: chromeHeight
            ),
            NSSize(width: 760, height: 180),
            "A short pane should retain its natural height on a compact screen"
        )
        XCTAssertEqual(
            CMPreferencesContentSize(
                preferredHeight: 900,
                visibleFrame: NSRect(x: 0, y: 0, width: 1920, height: 1400),
                windowChromeHeight: chromeHeight
            ).height,
            900,
            "A tall pane should use its full height when the screen has enough room"
        )
    }

    func testImageHoverPreviewPreservesAspectRatioWithoutEnlargingSmallImages() throws {
        let screen = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let menu = NSRect(x: 40, y: 400, width: 220, height: 350)
        let pointer = NSPoint(x: 120, y: 600)
        let landscape = try XCTUnwrap(CMImageHoverPreviewLayout(
            imageSize: NSSize(width: 1200, height: 800),
            menuFrame: menu,
            pointer: pointer,
            visibleFrame: screen
        ))
        XCTAssertEqual(landscape.width, 500, accuracy: 0.01)
        XCTAssertEqual(landscape.height, 340, accuracy: 0.01)
        XCTAssertGreaterThanOrEqual(landscape.minX, menu.maxX)

        let portrait = try XCTUnwrap(CMImageHoverPreviewLayout(
            imageSize: NSSize(width: 800, height: 1200),
            menuFrame: menu,
            pointer: pointer,
            visibleFrame: screen
        ))
        XCTAssertEqual(portrait.width, 260, accuracy: 0.01)
        XCTAssertEqual(portrait.height, 380, accuracy: 0.01)

        let small = try XCTUnwrap(CMImageHoverPreviewLayout(
            imageSize: NSSize(width: 64, height: 40),
            menuFrame: menu,
            pointer: pointer,
            visibleFrame: screen
        ))
        XCTAssertEqual(small.size, NSSize(width: 84, height: 60))
    }

    func testImageHoverPreviewUsesLeftSideAndStaysWithinScreenBounds() throws {
        let screen = NSRect(x: -1440, y: 60, width: 1440, height: 840)
        let menu = NSRect(x: -260, y: 500, width: 240, height: 300)
        let preview = try XCTUnwrap(CMImageHoverPreviewLayout(
            imageSize: NSSize(width: 1200, height: 800),
            menuFrame: menu,
            pointer: NSPoint(x: -100, y: 895),
            visibleFrame: screen
        ))
        XCTAssertLessThanOrEqual(preview.maxX, menu.minX)
        XCTAssertTrue(screen.contains(preview))

        let narrowScreen = NSRect(x: 0, y: 0, width: 320, height: 240)
        let constrained = try XCTUnwrap(CMImageHoverPreviewLayout(
            imageSize: NSSize(width: 1200, height: 800),
            menuFrame: NSRect(x: 100, y: 20, width: 180, height: 200),
            pointer: NSPoint(x: 319, y: 239),
            visibleFrame: narrowScreen
        ))
        XCTAssertTrue(narrowScreen.contains(constrained))
        XCTAssertEqual((constrained.width - 20) / (constrained.height - 20), 1.5, accuracy: 0.01)
    }

    func testImageHoverPreviewRejectsInvalidImageDimensions() {
        for size in [NSSize.zero, NSSize(width: -1, height: 10), NSSize(width: 10, height: 0)] {
            XCTAssertNil(CMImageHoverPreviewLayout(
                imageSize: size,
                menuFrame: NSRect(x: 40, y: 400, width: 220, height: 350),
                pointer: NSPoint(x: 120, y: 600),
                visibleFrame: NSRect(x: 0, y: 0, width: 1440, height: 900)
            ))
        }
    }
}

#if DEBUG
@MainActor
extension MenuPreviewTests {
    func testGeneralPreferencesScrollToBottomInCompactViewport() throws {
        try withPreferencesWindow { controller, window in
            let originalContentView = try XCTUnwrap(window.contentView)
            let chromeHeight = window.frame.height - originalContentView.frame.height
            let visibleFrame = NSRect(
                x: 0,
                y: 0,
                width: 1280,
                height: 480 + chromeHeight + 24
            )
            controller.debugSetVisibleFrame(visibleFrame)
            controller.debugSelectTab(rawValue: PreferenceTab.general.rawValue)
            let contentView = try XCTUnwrap(window.contentView)
            settlePreferencesLayout(in: contentView)

            let scrollView = try XCTUnwrap(preferenceScrollViews(in: contentView).first {
                guard let documentView = $0.documentView else { return false }
                return documentView.bounds.height > $0.contentView.bounds.height
            }, "General preferences need a scrolling document when the window is short")
            let documentView = try XCTUnwrap(scrollView.documentView)
            let viewport = scrollView.contentView
            XCTAssertTrue(scrollView.hasVerticalScroller)
            XCTAssertGreaterThan(documentView.bounds.height, viewport.bounds.height)
            XCTAssertLessThanOrEqual(viewport.bounds.height, 480)
            XCTAssertTrue(visibleFrame.contains(window.frame))

            let bottomOrigin = documentView.isFlipped
                ? documentView.bounds.maxY - viewport.bounds.height
                : documentView.bounds.minY
            viewport.scroll(to: NSPoint(x: viewport.bounds.minX, y: bottomOrigin))
            scrollView.reflectScrolledClipView(viewport)
            settlePreferencesLayout(in: contentView)

            let visibleDocumentRect = scrollView.documentVisibleRect
            if documentView.isFlipped {
                XCTAssertEqual(visibleDocumentRect.maxY, documentView.bounds.maxY, accuracy: 1)
            } else {
                XCTAssertEqual(visibleDocumentRect.minY, documentView.bounds.minY, accuracy: 1)
            }
        }
    }

    func testSwitchingPreferenceTabsResizesImmediatelyAndUpdatesToolbar() throws {
        try withPreferencesWindow { controller, window in
            let visibleFrame = NSRect(x: 0, y: 0, width: 1280, height: 800)
            controller.debugSetVisibleFrame(visibleFrame)
            var frameHeights: [PreferenceTab: CGFloat] = [:]

            for tab in PreferenceTab.allCases {
                controller.debugSelectTab(rawValue: tab.rawValue)
                let immediateFrame = window.frame
                frameHeights[tab] = immediateFrame.height
                XCTAssertTrue(visibleFrame.contains(immediateFrame), "\(tab.title) must fit on screen")
                XCTAssertEqual(window.title, tab.title)
                XCTAssertEqual(window.toolbar?.selectedItemIdentifier, tab.toolbarItemIdentifier)
                let contentView = try XCTUnwrap(window.contentView)
                settlePreferencesLayout(in: contentView)
                XCTAssertEqual(window.frame, immediateFrame, "\(tab.title) must finish resizing before selection returns")
                XCTAssertEqual(window.title, tab.title)
                XCTAssertEqual(window.toolbar?.selectedItemIdentifier, tab.toolbarItemIdentifier)
            }

            XCTAssertGreaterThan(
                try XCTUnwrap(frameHeights[.general]),
                try XCTUnwrap(frameHeights[.shortcuts]),
                "General should use a taller window than the shorter Shortcuts pane"
            )
            for tab in [PreferenceTab.general, .shortcuts, .general, .updates, .menu, .general] {
                controller.debugSelectTab(rawValue: tab.rawValue)
            }
            let finalFrame = window.frame
            settlePreferencesLayout(in: try XCTUnwrap(window.contentView))
            XCTAssertEqual(window.frame, finalFrame, "Rapid tab switching must not apply stale height updates")
        }
    }

    func testPreferenceToolbarClickLatency() throws {
        try withPreferencesWindow { controller, window in
            let visibleFrame = NSRect(x: 0, y: 0, width: 1280, height: 800)
            controller.debugSetVisibleFrame(visibleFrame)
            let toolbar = try XCTUnwrap(window.toolbar)
            var samples: [Double] = []
            var preparedPaneSnapshot: [String: [String: Int]]?

            for pass in 0...3 {
                for tab in PreferenceTab.allCases {
                    settlePreferencesLayout(in: try XCTUnwrap(window.contentView))
                    let item = try XCTUnwrap(toolbar.items.first {
                        $0.itemIdentifier == tab.toolbarItemIdentifier
                    })
                    let action = try XCTUnwrap(item.action)
                    let startedAt = ProcessInfo.processInfo.systemUptime
                    let dispatched = NSApp.sendAction(action, to: item.target, from: item)
                    let durationMilliseconds = (ProcessInfo.processInfo.systemUptime - startedAt) * 1000
                    samples.append(durationMilliseconds)
                    print(String(
                        format: "PREFERENCES_TAB_LATENCY pass=%d tab=%@ duration_ms=%.3f",
                        pass,
                        tab.rawValue,
                        durationMilliseconds
                    ))

                    XCTAssertTrue(dispatched)
                    XCTAssertEqual(window.title, tab.title)
                    XCTAssertEqual(toolbar.selectedItemIdentifier, tab.toolbarItemIdentifier)
                    let immediateFrame = window.frame
                    XCTAssertTrue(visibleFrame.contains(immediateFrame), "\(tab.title) must fit on screen")
                    settlePreferencesLayout(in: try XCTUnwrap(window.contentView))
                    XCTAssertEqual(window.frame, immediateFrame, "\(tab.title) must finish resizing before its toolbar action returns")
                    if pass > 0 {
                        XCTAssertEqual(
                            controller.debugPaneCacheSnapshot(),
                            try XCTUnwrap(preparedPaneSnapshot),
                            "Switching to \(tab.title) must reuse its host and measured size without another appearance"
                        )
                    }
                }
                if pass == 0 {
                    let snapshot = controller.debugPaneCacheSnapshot()
                    XCTAssertEqual(snapshot.count, PreferenceTab.allCases.count)
                    for tab in PreferenceTab.allCases {
                        let pane = try XCTUnwrap(snapshot[tab.rawValue])
                        XCTAssertNotNil(pane["hostingViewIdentity"])
                        XCTAssertEqual(pane["naturalSizeMeasurements"], tab == .actions ? 0 : 1)
                    }
                    preparedPaneSnapshot = snapshot
                }
            }

            let sortedSamples = samples.sorted()
            let midpoint = sortedSamples.count / 2
            let median = (sortedSamples[midpoint - 1] + sortedSamples[midpoint]) / 2
            print(String(
                format: "PREFERENCES_TAB_LATENCY summary samples=%d median_ms=%.3f max_ms=%.3f",
                samples.count,
                median,
                try XCTUnwrap(sortedSamples.last)
            ))
        }
    }

    func testPreferenceTabSwitchingPreservesPendingExcludedAppEdits() throws {
        try withPreferencesWindow { controller, window in
            CMReloadRecordingPreferences()
            defer { CMReloadRecordingPreferences() }
            for tab in PreferenceTab.allCases {
                controller.debugSelectTab(rawValue: tab.rawValue)
                settlePreferencesLayout(in: try XCTUnwrap(window.contentView))
            }

            let defaults = UserDefaults.standard
            let persistedExcludedApps = defaults.array(forKey: "excludeApps")
            let pendingBundleIdentifier = "com.clipmenu.tests.pending-excluded-app.\(UUID().uuidString)"
            CMStageExcludedAppForTesting(
                bundleIdentifier: pendingBundleIdentifier,
                name: "Pending exclusion"
            )
            let pendingExcludedApps = CMCurrentExcludedAppsDictionaries()
            XCTAssertTrue(pendingExcludedApps.contains {
                $0["bundleIdentifier"] == pendingBundleIdentifier
            })

            for tab in [PreferenceTab.general, .types, .actions, .shortcuts, .general, .types] {
                controller.debugSelectTab(rawValue: tab.rawValue)
                settlePreferencesLayout(in: try XCTUnwrap(window.contentView))
                XCTAssertEqual(
                    CMCurrentExcludedAppsDictionaries(),
                    pendingExcludedApps,
                    "Switching to \(tab.title) must preserve the pending excluded-app draft"
                )
            }
            XCTAssertEqual(
                defaults.array(forKey: "excludeApps") as NSArray?,
                persistedExcludedApps as NSArray?,
                "Switching tabs must not persist pending excluded-app edits"
            )
        }
    }

    func testReopeningPreferencesPreservesCommittedActionsAndReservedSelection() throws {
        try withPreservedPreferences {
            CMReloadActionPreferences()
            defer { CMReloadActionPreferences() }
            CMAddActionFolderForTesting()
            CMCommitActionPreferences()
            let committedPaths = CMCurrentActionPreferencePaths()
            let committedData = try XCTUnwrap(CMCommittedActionNodesData())
            XCTAssertTrue(CMSetReservedActionKindForTesting("builtin"))
            let reservedTitle = NSLocalizedString("Remove", comment: "")
            XCTAssertTrue(CMSelectReservedActionPreferenceNodeForTesting(path: reservedTitle))

            CMPreparePreferencesForPresentation()

            XCTAssertEqual(CMCurrentActionPreferencePaths(), committedPaths)
            XCTAssertEqual(CMCommittedActionNodesData(), committedData)
            let inspector = try XCTUnwrap(CMCurrentActionInspectorSnapshotForTesting())
            XCTAssertEqual(inspector["pane"] as? String, "reserved")
            XCTAssertEqual(inspector["name"] as? String, reservedTitle)
        }
    }

    private func withPreferencesWindow(
        _ body: (SwiftUIPreferencesWindowController, NSWindow) throws -> Void
    ) throws {
        try withPreservedPreferences {
            let controller = SwiftUIPreferencesWindowController.shared
            let window = try XCTUnwrap(controller.window)
            let originalFrame = window.frame
            let originalTab = PreferenceTab.allCases.first {
                $0.title == controller.debugSelectedTabTitle()
            } ?? .general
            defer {
                controller.debugSetVisibleFrame(nil)
                controller.debugSelectTab(rawValue: originalTab.rawValue)
                if let contentView = window.contentView {
                    settlePreferencesLayout(in: contentView)
                }
                window.setFrame(originalFrame, display: false)
            }
            try body(controller, window)
        }
    }

    private func preferenceScrollViews(in view: NSView) -> [NSScrollView] {
        var scrollViews = (view as? NSScrollView).map { [$0] } ?? []
        for subview in view.subviews {
            scrollViews.append(contentsOf: preferenceScrollViews(in: subview))
        }
        return scrollViews
    }

    private func settlePreferencesLayout(in view: NSView) {
        let deadline = Date().addingTimeInterval(0.25)
        repeat {
            view.layoutSubtreeIfNeeded()
            RunLoop.current.run(until: min(deadline, Date().addingTimeInterval(0.01)))
        } while Date() < deadline
        view.layoutSubtreeIfNeeded()
    }

    private func withPreservedPreferences(_ body: () throws -> Void) throws {
        let defaults = UserDefaults.standard
        let domainName = try XCTUnwrap(Bundle.main.bundleIdentifier)
        let originalDomain = defaults.persistentDomain(forName: domainName)
        defer {
            if let originalDomain {
                defaults.setPersistentDomain(originalDomain, forName: domainName)
            } else {
                defaults.removePersistentDomain(forName: domainName)
            }
        }
        try body()
    }

    func testImageHoverPreviewUsesOriginalImageAndDoesNotTakeFocus() throws {
        try withImageHoverFixture { controller, menu, imageClip, _ in
            let item = try XCTUnwrap(historyItem(for: imageClip, in: menu))
            let thumbnail = try XCTUnwrap(item.image)
            XCTAssertLessThanOrEqual(thumbnail.size.width, 32)
            controller.menuWillOpen(menu)
            controller.menu(menu, willHighlight: item)
            controller.debugFireImageHoverPreviewTimerForTesting()

            let state = controller.debugImageHoverPreviewStateForTesting
            XCTAssertEqual(state["isVisible"] as? Bool, true)
            XCTAssertEqual(state["clipID"] as? String, imageClip.id.uuidString)
            XCTAssertEqual(state["imagePixelWidth"] as? Int, 960)
            XCTAssertEqual(state["imagePixelHeight"] as? Int, 640)
            XCTAssertEqual(state["ignoresMouseEvents"] as? Bool, true)
            XCTAssertEqual(state["isKeyWindow"] as? Bool, false)
            let frame = try XCTUnwrap(state["panelFrame"] as? NSRect)
            XCTAssertGreaterThan(frame.width - 20, thumbnail.size.width)

            let panel = try XCTUnwrap(NSApp.windows.first {
                $0.title == NSLocalizedString("Image Preview", comment: "") && $0.isVisible
            })
            let contentView = try XCTUnwrap(panel.contentView)
            contentView.layoutSubtreeIfNeeded()
            let renderedBitmap = try XCTUnwrap(contentView.bitmapImageRepForCachingDisplay(in: contentView.bounds))
            contentView.cacheDisplay(in: contentView.bounds, to: renderedBitmap)
            let renderedImage = NSImage(size: contentView.bounds.size)
            renderedImage.addRepresentation(renderedBitmap)
            let attachment = XCTAttachment(image: renderedImage)
            attachment.name = "image-hover-preview"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testImageHoverPreviewTimerRunsWhileMenuTracksEvents() throws {
        try withImageHoverFixture { controller, menu, imageClip, _ in
            let item = try XCTUnwrap(historyItem(for: imageClip, in: menu))
            controller.menuWillOpen(menu)
            controller.menu(menu, willHighlight: item)
            XCTAssertEqual(controller.debugImageHoverPreviewStateForTesting["isVisible"] as? Bool, false)

            let deadline = Date().addingTimeInterval(1.5)
            while controller.debugImageHoverPreviewStateForTesting["isVisible"] as? Bool != true,
                  Date() < deadline {
                RunLoop.current.run(mode: .eventTracking, before: Date().addingTimeInterval(0.05))
            }

            XCTAssertEqual(controller.debugImageHoverPreviewStateForTesting["isVisible"] as? Bool, true)
        }
    }

    func testImageHoverPreviewCancelsWhenHighlightChangesOrMenuCloses() throws {
        try withImageHoverFixture { controller, menu, imageClip, textClip in
            let imageItem = try XCTUnwrap(historyItem(for: imageClip, in: menu))
            let textItem = try XCTUnwrap(historyItem(for: textClip, in: menu))
            controller.menuWillOpen(menu)

            controller.menu(menu, willHighlight: imageItem)
            controller.menu(menu, willHighlight: textItem)
            controller.debugFireImageHoverPreviewTimerForTesting()
            XCTAssertEqual(controller.debugImageHoverPreviewStateForTesting["isVisible"] as? Bool, false)

            controller.menu(menu, willHighlight: imageItem)
            controller.debugFireImageHoverPreviewTimerForTesting()
            XCTAssertEqual(controller.debugImageHoverPreviewStateForTesting["isVisible"] as? Bool, true)
            controller.menu(menu, willHighlight: textItem)
            XCTAssertEqual(controller.debugImageHoverPreviewStateForTesting["isVisible"] as? Bool, false)

            controller.menu(menu, willHighlight: imageItem)
            controller.debugFireImageHoverPreviewTimerForTesting()
            controller.menu(menu, willHighlight: nil)
            XCTAssertEqual(controller.debugImageHoverPreviewStateForTesting["isVisible"] as? Bool, false)

            controller.menu(menu, willHighlight: imageItem)
            controller.menuDidClose(menu)
            controller.debugFireImageHoverPreviewTimerForTesting()
            XCTAssertEqual(controller.debugImageHoverPreviewStateForTesting["isVisible"] as? Bool, false)

            controller.menuWillOpen(menu)
            controller.menu(menu, willHighlight: imageItem)
            controller.debugFireImageHoverPreviewTimerForTesting()
            controller.menuDidClose(menu)
            XCTAssertEqual(controller.debugImageHoverPreviewStateForTesting["isVisible"] as? Bool, false)
        }
    }

    func testImageHoverPreviewHonorsImageDisplayPreferenceAndWorksWithoutTextTooltips() throws {
        try withImageHoverFixture { controller, _, imageClip, _ in
            UserDefaults.standard.set(false, forKey: CMPrefShowToolTipOnMenuItemKey)
            let menu = controller.debugMakeHistoryMenuForTesting()
            let item = try XCTUnwrap(historyItem(for: imageClip, in: menu))
            XCTAssertNil(item.toolTip)
            controller.menuWillOpen(menu)
            controller.menu(menu, willHighlight: item)
            controller.debugFireImageHoverPreviewTimerForTesting()
            XCTAssertEqual(controller.debugImageHoverPreviewStateForTesting["isVisible"] as? Bool, true)
            controller.menuDidClose(menu)

            UserDefaults.standard.set(false, forKey: CMPrefShowImageInTheMenuKey)
            let hiddenImageMenu = controller.debugMakeHistoryMenuForTesting()
            let hiddenImageItem = try XCTUnwrap(historyItem(for: imageClip, in: hiddenImageMenu))
            XCTAssertNil(hiddenImageItem.image)
            controller.menuWillOpen(hiddenImageMenu)
            controller.menu(hiddenImageMenu, willHighlight: hiddenImageItem)
            controller.debugFireImageHoverPreviewTimerForTesting()
            XCTAssertEqual(controller.debugImageHoverPreviewStateForTesting["isVisible"] as? Bool, false)
            controller.menuDidClose(hiddenImageMenu)
            UserDefaults.standard.set(true, forKey: CMPrefShowImageInTheMenuKey)

            let corruptClip = ClipItem(types: [NSPasteboard.PasteboardType.tiff.rawValue], imageData: Data([1, 2, 3]))
            controller.debugReplaceHistoryClipsForTesting([corruptClip])
            let corruptMenu = controller.debugMakeHistoryMenuForTesting()
            let corruptItem = try XCTUnwrap(historyItem(for: corruptClip, in: corruptMenu))
            controller.menuWillOpen(corruptMenu)
            controller.menu(corruptMenu, willHighlight: corruptItem)
            controller.debugFireImageHoverPreviewTimerForTesting()
            XCTAssertEqual(controller.debugImageHoverPreviewStateForTesting["isVisible"] as? Bool, false)
            controller.menuDidClose(corruptMenu)
        }
    }

    func testHistorySubmenusUseImageHoverDelegate() throws {
        try withImageHoverFixture { controller, _, imageClip, textClip in
            UserDefaults.standard.set(0, forKey: CMPrefNumberOfItemsPlaceInlineKey)
            UserDefaults.standard.set(2, forKey: CMPrefNumberOfItemsPlaceInsideFolderKey)
            controller.debugReplaceHistoryClipsForTesting([
                imageClip, textClip, ClipItem(text: "third"), ClipItem(text: "fourth")
            ])
            let menu = controller.debugMakeHistoryMenuForTesting()
            let item = try XCTUnwrap(historyItem(for: imageClip, in: menu))
            let submenu = try XCTUnwrap(item.menu)
            XCTAssertFalse(submenu === menu)
            XCTAssertTrue(submenu.delegate === controller)
            controller.menuWillOpen(menu)
            controller.menuWillOpen(submenu)
            controller.menu(submenu, willHighlight: item)
            controller.debugFireImageHoverPreviewTimerForTesting()
            XCTAssertEqual(controller.debugImageHoverPreviewStateForTesting["isVisible"] as? Bool, true)
            controller.menuDidClose(submenu)
            XCTAssertEqual(controller.debugImageHoverPreviewStateForTesting["isVisible"] as? Bool, false)
            controller.menuDidClose(menu)
        }
    }

    private func historyItem(for clip: ClipItem, in menu: NSMenu) -> NSMenuItem? {
        for item in menu.items {
            if item.representedObject as? String == clip.id.uuidString { return item }
            if let submenu = item.submenu, let match = historyItem(for: clip, in: submenu) { return match }
        }
        return nil
    }

    private func withImageHoverFixture(
        _ body: (AppController, NSMenu, ClipItem, ClipItem) throws -> Void
    ) throws {
        let controller = try XCTUnwrap(NSApp.delegate as? AppController)
        let defaults = UserDefaults.standard
        let domainName = try XCTUnwrap(Bundle.main.bundleIdentifier)
        let originalDomain = defaults.persistentDomain(forName: domainName)
        let originalClips = controller.debugHistoryClipsForTesting
        let bitmap = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 960,
            pixelsHigh: 640,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ))
        let context = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        for (rect, color) in [
            (NSRect(x: 0, y: 0, width: 480, height: 320), NSColor(calibratedRed: 0.12, green: 0.42, blue: 0.78, alpha: 1)),
            (NSRect(x: 480, y: 0, width: 480, height: 320), NSColor(calibratedRed: 0.94, green: 0.48, blue: 0.18, alpha: 1)),
            (NSRect(x: 0, y: 320, width: 480, height: 320), NSColor(calibratedRed: 0.22, green: 0.68, blue: 0.45, alpha: 1)),
            (NSRect(x: 480, y: 320, width: 480, height: 320), NSColor(calibratedRed: 0.57, green: 0.31, blue: 0.72, alpha: 1))
        ] {
            color.setFill()
            NSBezierPath(rect: rect).fill()
        }
        NSGraphicsContext.restoreGraphicsState()
        let imageData = try XCTUnwrap(bitmap.representation(using: .tiff, properties: [:]))
        let imageClip = ClipItem(types: [NSPasteboard.PasteboardType.tiff.rawValue], imageData: imageData)
        let textClip = ClipItem(text: "Text beside image")

        defaults.set(true, forKey: CMPrefShowImageInTheMenuKey)
        defaults.set(true, forKey: CMPrefShowToolTipOnMenuItemKey)
        defaults.set(false, forKey: CMPrefShowLabelsInMenuKey)
        defaults.set(32, forKey: CMPrefThumbnailWidthKey)
        defaults.set(32, forKey: CMPrefThumbnailHeightKey)
        defaults.set(20, forKey: CMPrefMaxHistorySizeKey)
        defaults.set(10, forKey: CMPrefNumberOfItemsPlaceInlineKey)
        controller.debugReplaceHistoryClipsForTesting([imageClip, textClip])
        let menu = controller.debugMakeHistoryMenuForTesting()
        defer {
            controller.menuDidClose(menu)
            if let originalDomain {
                defaults.setPersistentDomain(originalDomain, forName: domainName)
            } else {
                defaults.removePersistentDomain(forName: domainName)
            }
            controller.debugReplaceHistoryClipsForTesting(originalClips)
        }
        try body(controller, menu, imageClip, textClip)
    }
}
#endif
