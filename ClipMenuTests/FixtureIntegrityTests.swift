import Darwin
import XCTest

final class FixtureIntegrityTests: XCTestCase {
    func testHotKeyFixturesRemainLoadable() throws {
        for fixtureName in ["clips_hotkey_fixture", "snippets_hotkey_fixture"] {
            let jsonURL = try repositoryRoot()
                .appendingPathComponent("doc")
                .appendingPathComponent("\(fixtureName).json")
            XCTAssertTrue(FileManager.default.fileExists(atPath: jsonURL.path))
            XCTAssertGreaterThan(try fixtureSize(at: jsonURL), 0)
        }

        let snippetsXMLURL = try repositoryRoot()
            .appendingPathComponent("doc")
            .appendingPathComponent("snippets_hotkey_fixture.xml")
        XCTAssertTrue(FileManager.default.fileExists(atPath: snippetsXMLURL.path))
        XCTAssertGreaterThan(try fixtureSize(at: snippetsXMLURL), 0)
    }

    func testBundledActionScriptsRemainPresentAndOrganized() throws {
        let actionsURL = try repositoryRoot()
            .appendingPathComponent("resource")
            .appendingPathComponent("script")
            .appendingPathComponent("action")
        let representativeScripts = [
            "Case/UPPERCASE.js",
            "HTML/Escape HTML characters.js",
            "Japanese/Convert Hiragana to Katakana.js",
            "Crypt/Encode to Base64.js",
            "Surround with/( ).js"
        ]

        for script in representativeScripts {
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: actionsURL.appendingPathComponent(script).path),
                "Missing bundled action script: \(script)"
            )
        }
    }

    private func repositoryRoot(
        file: StaticString = #filePath
    ) throws -> URL {
        let url = URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        if FileManager.default.fileExists(atPath: url.appendingPathComponent("ClipMenu.xcodeproj").path) {
            return url
        }
        throw XCTSkip("Could not locate repository root")
    }

    private func fixtureSize(at url: URL) throws -> UInt64 {
        var fileStatus = stat()
        let result = url.path.withCString { stat($0, &fileStatus) }
        XCTAssertEqual(result, 0)
        return UInt64(fileStatus.st_size)
    }
}
