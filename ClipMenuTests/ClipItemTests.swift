import AppKit
import XCTest
@testable import ClipMenu

final class ClipItemTests: XCTestCase {
    private let filenamesType = "NSFilenamesPboardType"
    private let urlType = "NSURLPboardType"
    private let publicURLType = NSPasteboard.PasteboardType("public.url")
    private let clipMenuURLType = NSPasteboard.PasteboardType("NSURLPboardType")
    private let clipMenuFilenamesType = NSPasteboard.PasteboardType("NSFilenamesPboardType")
    private var storeTypesSnapshot: Any?

    override func setUp() {
        super.setUp()
        storeTypesSnapshot = UserDefaults.standard.object(forKey: "storeTypes")
        UserDefaults.standard.set(ClipItem.defaultStoreTypes(), forKey: "storeTypes")
    }

    override func tearDown() {
        if let storeTypesSnapshot {
            UserDefaults.standard.set(storeTypesSnapshot, forKey: "storeTypes")
        } else {
            UserDefaults.standard.removeObject(forKey: "storeTypes")
        }
        super.tearDown()
    }

    func testLegacyPasteboardTypesNormalizeToModernTypes() {
        XCTAssertEqual(
            ClipItem.normalizedPasteboardType("NSStringPboardType"),
            NSPasteboard.PasteboardType.string.rawValue
        )
        XCTAssertEqual(
            ClipItem.normalizedPasteboardType("NSRTFPboardType"),
            NSPasteboard.PasteboardType.rtf.rawValue
        )
        XCTAssertEqual(
            ClipItem.normalizedPasteboardType("public.file-url"),
            filenamesType
        )
        XCTAssertEqual(
            ClipItem.normalizedPasteboardType("Apple PICT pasteboard type"),
            NSPasteboard.PasteboardType.tiff.rawValue
        )
        XCTAssertEqual(ClipItem.normalizedPasteboardType("NeXT Rich Text Format v1.0 pasteboard type"), NSPasteboard.PasteboardType.rtf.rawValue)
        XCTAssertEqual(ClipItem.normalizedPasteboardType("NSRTFDPboardType"), NSPasteboard.PasteboardType.rtfd.rawValue)
        XCTAssertEqual(ClipItem.normalizedPasteboardType("NeXT RTFD pasteboard type"), NSPasteboard.PasteboardType.rtfd.rawValue)
        XCTAssertEqual(ClipItem.normalizedPasteboardType("NSPDFPboardType"), NSPasteboard.PasteboardType.pdf.rawValue)
        XCTAssertEqual(ClipItem.normalizedPasteboardType("NSTIFFPboardType"), NSPasteboard.PasteboardType.tiff.rawValue)
        XCTAssertEqual(ClipItem.normalizedPasteboardType("NeXT TIFF v4.0 pasteboard type"), NSPasteboard.PasteboardType.tiff.rawValue)
        XCTAssertEqual(ClipItem.normalizedPasteboardType("NSURLPboardType"), urlType)
        XCTAssertEqual(ClipItem.normalizedPasteboardType("Apple URL pasteboard type"), urlType)
        XCTAssertEqual(ClipItem.normalizedPasteboardType("public.url"), urlType)
        XCTAssertEqual(ClipItem.normalizedPasteboardType("NSPICTPboardType"), NSPasteboard.PasteboardType.tiff.rawValue)
        XCTAssertEqual(ClipItem.normalizedPasteboardType("custom.type"), "custom.type")
    }

    func testDecodingInfersStringTypeForLegacyTextPayloads() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "text": "legacy text",
            "createdAt": 0,
            "lastUsedAt": 0
        ])
        let clip = try JSONDecoder().decode(ClipItem.self, from: data)

        XCTAssertEqual(clip.types, [NSPasteboard.PasteboardType.string.rawValue])
        XCTAssertEqual(clip.text, "legacy text")
        XCTAssertTrue(clip.hasStringPasteboardType)
        XCTAssertTrue(clip.hasTextContent)
    }

    func testDecodingInfersTypedPayloadsWhenTypesAreMissing() throws {
        let data = try JSONEncoder().encode(
            ClipItem(
                types: [],
                text: "",
                rtfData: Data("rtf".utf8),
                pdfData: Data("pdf".utf8),
                filenames: ["/tmp/a.txt"],
                urls: ["https://example.com"],
                imageData: Data("image".utf8)
            )
        )
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        var legacyObject = try XCTUnwrap(object)
        legacyObject.removeValue(forKey: "types")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)

        let clip = try JSONDecoder().decode(ClipItem.self, from: legacyData)

        XCTAssertEqual(
            clip.types,
            [
                NSPasteboard.PasteboardType.rtf.rawValue,
                NSPasteboard.PasteboardType.pdf.rawValue,
                filenamesType,
                urlType,
                NSPasteboard.PasteboardType.tiff.rawValue
            ]
        )
        XCTAssertEqual(clip.filePathsText, "/tmp/a.txt")
        XCTAssertFalse(clip.hfsFilePathsText?.isEmpty ?? true)
    }

    func testTitleSourcePrefersTextThenFileNamesThenURLsThenTypeFallbacks() {
        XCTAssertEqual(ClipItem(text: "Hello").titleSource, "Hello")
        XCTAssertEqual(
            ClipItem(types: [filenamesType], filenames: ["/tmp/a", "/tmp/b"]).titleSource,
            "/tmp/a\n/tmp/b"
        )
        XCTAssertEqual(
            ClipItem(types: [urlType], urls: ["https://example.com"]).titleSource,
            "https://example.com"
        )
        XCTAssertEqual(ClipItem(types: [NSPasteboard.PasteboardType.pdf.rawValue], pdfData: Data([1])).titleSource, "(PDF)")
        XCTAssertEqual(ClipItem(types: [NSPasteboard.PasteboardType.tiff.rawValue], imageData: Data([1])).titleSource, "(Image)")
    }

    func testDuplicateKeyIsStableForEquivalentFileAndURLPayloads() {
        let firstFiles = ClipItem(
            types: [filenamesType],
            filenames: ["/tmp/b", "/tmp/a"]
        )
        let secondFiles = ClipItem(
            types: [filenamesType],
            filenames: ["/tmp/a", "/tmp/b"]
        )
        XCTAssertEqual(firstFiles.duplicateKey, secondFiles.duplicateKey)

        let firstURLs = ClipItem(
            types: [urlType],
            urls: ["https://b.example", "https://a.example"]
        )
        let secondURLs = ClipItem(
            types: [urlType],
            urls: ["https://a.example", "https://b.example"]
        )
        XCTAssertEqual(firstURLs.duplicateKey, secondURLs.duplicateKey)
    }

    func testPasteboardCaptureReadsStringURLFileAndDataPayloads() throws {
        let textPasteboard = NSPasteboard(name: NSPasteboard.Name("ClipMenuTextCapture-\(UUID().uuidString)"))
        textPasteboard.clearContents()
        textPasteboard.setString("Captured text", forType: .string)
        let textClip = try XCTUnwrap(ClipItem.fromPasteboard(textPasteboard))
        XCTAssertEqual(textClip.text, "Captured text")
        XCTAssertEqual(textClip.types, [NSPasteboard.PasteboardType.string.rawValue])

        let urlPasteboard = NSPasteboard(name: NSPasteboard.Name("ClipMenuURLCapture-\(UUID().uuidString)"))
        urlPasteboard.clearContents()
        urlPasteboard.declareTypes([publicURLType, .string], owner: nil)
        urlPasteboard.setString("https://example.com/path", forType: publicURLType)
        urlPasteboard.setString("Example", forType: .string)
        let urlClip = try XCTUnwrap(ClipItem.fromPasteboard(urlPasteboard))
        XCTAssertEqual(urlClip.urls, ["https://example.com/path"])
        XCTAssertEqual(urlClip.text, "Example")

        let fileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("clipmenu-file.txt")
        let filePasteboard = NSPasteboard(name: NSPasteboard.Name("ClipMenuFileCapture-\(UUID().uuidString)"))
        filePasteboard.clearContents()
        filePasteboard.writeObjects([fileURL as NSURL])
        let fileClip = try XCTUnwrap(ClipItem.fromPasteboard(filePasteboard))
        XCTAssertEqual(fileClip.filenames, [fileURL.path])

        let rtfData = try XCTUnwrap(NSAttributedString(string: "Rich").rtf(
            from: NSRange(location: 0, length: 4),
            documentAttributes: [:]
        ))
        let rtfPasteboard = NSPasteboard(name: NSPasteboard.Name("ClipMenuRTFCapture-\(UUID().uuidString)"))
        rtfPasteboard.clearContents()
        rtfPasteboard.declareTypes([.rtf, .string], owner: nil)
        rtfPasteboard.setData(rtfData, forType: .rtf)
        rtfPasteboard.setString("Rich", forType: .string)
        let richClip = try XCTUnwrap(ClipItem.fromPasteboard(rtfPasteboard))
        XCTAssertEqual(richClip.text, "Rich")
        XCTAssertNotNil(richClip.rtfData)

        let emptyRichPasteboard = NSPasteboard(name: NSPasteboard.Name("ClipMenuEmptyRich-\(UUID().uuidString)"))
        emptyRichPasteboard.clearContents()
        emptyRichPasteboard.declareTypes([.rtf], owner: nil)
        XCTAssertNil(ClipItem.fromPasteboard(emptyRichPasteboard))

        let unsupportedPasteboard = NSPasteboard(name: NSPasteboard.Name("ClipMenuUnsupported-\(UUID().uuidString)"))
        unsupportedPasteboard.clearContents()
        unsupportedPasteboard.declareTypes([NSPasteboard.PasteboardType("com.example.unsupported")], owner: nil)
        XCTAssertNil(ClipItem.fromPasteboard(unsupportedPasteboard))
    }

    func testPasteboardCaptureReadsLegacyURLAndFileURLVariants() throws {
        let legacyURLStringPasteboard = NSPasteboard(name: NSPasteboard.Name("ClipMenuLegacyURLString-\(UUID().uuidString)"))
        legacyURLStringPasteboard.clearContents()
        legacyURLStringPasteboard.declareTypes([clipMenuURLType], owner: nil)
        legacyURLStringPasteboard.setPropertyList("https://example.com/legacy", forType: clipMenuURLType)
        let legacyURLStringClip = try XCTUnwrap(ClipItem.fromPasteboard(legacyURLStringPasteboard))
        XCTAssertEqual(legacyURLStringClip.urls, ["https://example.com/legacy"])

        let legacyURLArrayPasteboard = NSPasteboard(name: NSPasteboard.Name("ClipMenuLegacyURLArray-\(UUID().uuidString)"))
        legacyURLArrayPasteboard.clearContents()
        legacyURLArrayPasteboard.declareTypes([clipMenuURLType], owner: nil)
        legacyURLArrayPasteboard.setPropertyList(["https://example.com/a", "https://example.com/b"], forType: clipMenuURLType)
        let legacyURLArrayClip = try XCTUnwrap(ClipItem.fromPasteboard(legacyURLArrayPasteboard))
        XCTAssertEqual(legacyURLArrayClip.urls, ["https://example.com/a", "https://example.com/b"])

        let fileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("clipmenu-file-url.txt")
        let fileURLPasteboard = NSPasteboard(name: NSPasteboard.Name("ClipMenuPublicFileURL-\(UUID().uuidString)"))
        fileURLPasteboard.clearContents()
        fileURLPasteboard.declareTypes([NSPasteboard.PasteboardType("public.file-url")], owner: nil)
        fileURLPasteboard.setString(fileURL.absoluteString, forType: NSPasteboard.PasteboardType("public.file-url"))
        let fileURLClip = try XCTUnwrap(ClipItem.fromPasteboard(fileURLPasteboard))
        XCTAssertEqual(fileURLClip.filenames, [fileURL.path])

        let legacyFilenamesPasteboard = NSPasteboard(name: NSPasteboard.Name("ClipMenuLegacyFilenames-\(UUID().uuidString)"))
        legacyFilenamesPasteboard.clearContents()
        legacyFilenamesPasteboard.declareTypes([clipMenuFilenamesType], owner: nil)
        legacyFilenamesPasteboard.setPropertyList(["/tmp/legacy-a.txt", "/tmp/legacy-b.txt"], forType: clipMenuFilenamesType)
        let legacyFilenamesClip = try XCTUnwrap(ClipItem.fromPasteboard(legacyFilenamesPasteboard))
        XCTAssertEqual(legacyFilenamesClip.filenames, ["/tmp/legacy-a.txt", "/tmp/legacy-b.txt"])

        let urlObjectPasteboard = NSPasteboard(name: NSPasteboard.Name("ClipMenuURLObject-\(UUID().uuidString)"))
        urlObjectPasteboard.clearContents()
        urlObjectPasteboard.writeObjects([NSURL(string: "https://example.com/object")!])
        let urlObjectClip = try XCTUnwrap(ClipItem.fromPasteboard(urlObjectPasteboard))
        XCTAssertEqual(urlObjectClip.urls, ["https://example.com/object"])
    }

    func testPasteboardCaptureHonorsLegacyStoreTypeKeysAndBooleanValues() throws {
        var storeTypes: [String: Any] = [:]
        storeTypes["NSStringPboardType"] = NSNumber(value: false)
        storeTypes["NSPDFPboardType"] = false
        storeTypes["NSTIFFPboardType"] = NSNumber(value: false)
        storeTypes["public.url"] = false
        storeTypes["com.example.ignored"] = true
        storeTypes["NSRTFPboardType"] = "not-a-bool"
        UserDefaults.standard.set(storeTypes, forKey: "storeTypes")

        let stringPasteboard = NSPasteboard(name: NSPasteboard.Name("ClipMenuDisabledLegacyString-\(UUID().uuidString)"))
        stringPasteboard.clearContents()
        stringPasteboard.setString("disabled legacy string", forType: .string)
        XCTAssertNil(ClipItem.fromPasteboard(stringPasteboard))

        let pdfPasteboard = NSPasteboard(name: NSPasteboard.Name("ClipMenuDisabledLegacyPDF-\(UUID().uuidString)"))
        pdfPasteboard.clearContents()
        pdfPasteboard.declareTypes([.pdf], owner: nil)
        pdfPasteboard.setData(Data("%PDF-disabled".utf8), forType: .pdf)
        XCTAssertNil(ClipItem.fromPasteboard(pdfPasteboard))

        let publicURLPasteboard = NSPasteboard(name: NSPasteboard.Name("ClipMenuDisabledPublicURL-\(UUID().uuidString)"))
        publicURLPasteboard.clearContents()
        publicURLPasteboard.declareTypes([publicURLType], owner: nil)
        publicURLPasteboard.setString("https://example.com/disabled", forType: publicURLType)
        XCTAssertNil(ClipItem.fromPasteboard(publicURLPasteboard))

        let rtfData = try XCTUnwrap(NSAttributedString(string: "Still Rich").rtf(
            from: NSRange(location: 0, length: 10),
            documentAttributes: [:]
        ))
        let rtfPasteboard = NSPasteboard(name: NSPasteboard.Name("ClipMenuInvalidStoreTypeBool-\(UUID().uuidString)"))
        rtfPasteboard.clearContents()
        rtfPasteboard.declareTypes([.rtf, .string], owner: nil)
        rtfPasteboard.setData(rtfData, forType: .rtf)
        rtfPasteboard.setString("Still Rich", forType: .string)
        let rtfClip = try XCTUnwrap(ClipItem.fromPasteboard(rtfPasteboard))
        XCTAssertEqual(rtfClip.text, "Still Rich")
        XCTAssertNotNil(rtfClip.rtfData)
    }

    func testWriteToPasteboardRestoresAvailablePayloadTypes() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("ClipMenuWrite-\(UUID().uuidString)"))
        let rtfData = try XCTUnwrap(NSAttributedString(string: "Styled").rtf(
            from: NSRange(location: 0, length: 6),
            documentAttributes: [:]
        ))
        let clip = ClipItem(
            types: [
                NSPasteboard.PasteboardType.rtf.rawValue,
                urlType,
                filenamesType
            ],
            text: "Styled",
            rtfData: rtfData,
            filenames: ["/tmp/clipmenu.txt"],
            urls: ["https://example.com"]
        )

        clip.write(to: pasteboard)

        XCTAssertEqual(pasteboard.string(forType: .string), "Styled")
        XCTAssertEqual(pasteboard.propertyList(forType: clipMenuURLType) as? [String], ["https://example.com"])
        XCTAssertEqual(pasteboard.propertyList(forType: clipMenuFilenamesType) as? [String], ["/tmp/clipmenu.txt"])
        XCTAssertNotNil(pasteboard.data(forType: .rtf))
    }

    func testWriteToPasteboardCoversTypedPayloadsAndMissingDataBranches() throws {
        let richPackagePasteboard = NSPasteboard(name: NSPasteboard.Name("ClipMenuWriteRTFD-\(UUID().uuidString)"))
        let richPackageClip = ClipItem(
            types: [NSPasteboard.PasteboardType.rtfd.rawValue],
            text: "Package fallback",
            rtfData: Data("rtfd-package".utf8)
        )
        richPackageClip.write(to: richPackagePasteboard)
        XCTAssertEqual(richPackagePasteboard.string(forType: .string), "Package fallback")
        XCTAssertEqual(richPackagePasteboard.data(forType: .rtfd), Data("rtfd-package".utf8))

        let pdfPasteboard = NSPasteboard(name: NSPasteboard.Name("ClipMenuWritePDF-\(UUID().uuidString)"))
        let pdfClip = ClipItem(
            types: [NSPasteboard.PasteboardType.pdf.rawValue],
            pdfData: Data("%PDF-clipmenu".utf8)
        )
        pdfClip.write(to: pdfPasteboard)
        XCTAssertEqual(pdfPasteboard.data(forType: .pdf), Data("%PDF-clipmenu".utf8))

        let imagePasteboard = NSPasteboard(name: NSPasteboard.Name("ClipMenuWriteImage-\(UUID().uuidString)"))
        let imageClip = ClipItem(
            types: [NSPasteboard.PasteboardType.tiff.rawValue, "Apple PICT pasteboard type"],
            imageData: Data("tiff-data".utf8)
        )
        imageClip.write(to: imagePasteboard)
        XCTAssertEqual(imagePasteboard.data(forType: .tiff), Data("tiff-data".utf8))

        let missingPayloadPasteboard = NSPasteboard(name: NSPasteboard.Name("ClipMenuWriteMissingPayloads-\(UUID().uuidString)"))
        let missingPayloadClip = ClipItem(
            types: [
                NSPasteboard.PasteboardType.rtf.rawValue,
                NSPasteboard.PasteboardType.pdf.rawValue,
                filenamesType,
                urlType,
                NSPasteboard.PasteboardType.tiff.rawValue,
                "com.example.unhandled"
            ]
        )
        missingPayloadClip.write(to: missingPayloadPasteboard)
        XCTAssertNil(missingPayloadPasteboard.data(forType: .rtf))
        XCTAssertNil(missingPayloadPasteboard.data(forType: .pdf))
        XCTAssertNil(missingPayloadPasteboard.propertyList(forType: clipMenuFilenamesType))
        XCTAssertNil(missingPayloadPasteboard.propertyList(forType: clipMenuURLType))
        XCTAssertNil(missingPayloadPasteboard.data(forType: .tiff))
    }

#if TESTING
    func testLegacyArchivedClipDecodesIntoClipItem() throws {
        let report = try CMDebugLegacyArchivedClipReportForTesting()
        XCTAssertFalse(report.isEmpty)
    }
#endif

}
