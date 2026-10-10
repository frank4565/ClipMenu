import AppKit
import XCTest
@testable import ClipMenu

final class MenuPreviewTests: XCTestCase {
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
