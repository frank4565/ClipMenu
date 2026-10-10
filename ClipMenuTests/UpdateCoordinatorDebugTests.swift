import XCTest
@testable import ClipMenu

final class UpdateCoordinatorTests: XCTestCase {
    func testFreshInstallLeavesAutomaticChecksForSparkleConsent() {
        let migrated = UpdateCoordinator.migratedLegacyPreferences([:])
        XCTAssertNil(migrated["SUEnableAutomaticChecks"])
        XCTAssertNil(migrated["SUAutomaticallyUpdate"])
        XCTAssertEqual(migrated[UpdateCoordinator.legacyPreferencesMigrationKey] as? Bool, true)
    }

    func testMigrationPreservesManualOnlyPreferenceAndUserData() {
        let lastCheck = Date(timeIntervalSince1970: 1_700_000_000)
        let domain: [String: Any] = [
            CMEnableAutomaticCheckKey: false,
            CMUpdateCheckIntervalKey: 604_800,
            CMEnableAutomaticCheckPreReleaseKey: true,
            "SUEnableAutomaticChecks": true,
            "SUAutomaticallyUpdate": true,
            "SULastCheckTime": lastCheck,
            "SUSkippedVersion": "0.4.4a12",
            "SUFeedURL": "http://feeds.feedburner.com/clipmenu-appcast",
            "unrelatedPreference": ["value": "keep"]
        ]
        let migrated = UpdateCoordinator.migratedLegacyPreferences(domain)
        XCTAssertEqual(migrated["SUEnableAutomaticChecks"] as? Bool, false)
        XCTAssertEqual((migrated["SUScheduledCheckInterval"] as? NSNumber)?.doubleValue, 604_800)
        XCTAssertEqual(migrated[CMEnableAutomaticCheckPreReleaseKey] as? Bool, true)
        XCTAssertEqual(migrated["SUAutomaticallyUpdate"] as? Bool, false)
        XCTAssertEqual(migrated["SULastCheckTime"] as? Date, lastCheck)
        XCTAssertEqual(migrated["SUSkippedVersion"] as? String, "0.4.4a12")
        XCTAssertEqual(migrated["unrelatedPreference"] as? [String: String], ["value": "keep"])
        XCTAssertNil(migrated["SUFeedURL"])
        XCTAssertNotNil(domain["SUFeedURL"], "Migration must not mutate its input.")
    }

    func testMigrationPreservesLegacyAutomaticCheckChoices() {
        for key in ["SUEnableAutomaticChecks", "SUCheckAtStartup", "SUAllowsAutomaticUpdates"] {
            for enabled in [false, true] {
                let migrated = UpdateCoordinator.migratedLegacyPreferences([key: enabled])
                XCTAssertEqual(migrated["SUEnableAutomaticChecks"] as? Bool, enabled, key)
            }
        }
    }

    func testInstallationConsentIsOnlyResetOnce() {
        var migrated = UpdateCoordinator.migratedLegacyPreferences(["SUAutomaticallyUpdate": true])
        XCTAssertEqual(migrated["SUAutomaticallyUpdate"] as? Bool, false)
        migrated["SUAutomaticallyUpdate"] = true
        let secondMigration = UpdateCoordinator.migratedLegacyPreferences(migrated)
        XCTAssertTrue((secondMigration as NSDictionary).isEqual(to: migrated))
        XCTAssertEqual(secondMigration["SUAutomaticallyUpdate"] as? Bool, true)
    }

    func testLegacyNeverIntervalPreservesManualOnlyBehavior() {
        for intervalKey in [CMUpdateCheckIntervalKey, "SUScheduledCheckInterval"] {
            var migrated = UpdateCoordinator.migratedLegacyPreferences([
                "SUEnableAutomaticChecks": true, intervalKey: 0
            ])
            XCTAssertEqual(migrated["SUEnableAutomaticChecks"] as? Bool, false)
            XCTAssertEqual((migrated["SUScheduledCheckInterval"] as? NSNumber)?.doubleValue, 86_400)
            migrated["SUEnableAutomaticChecks"] = true
            let afterOptIn = UpdateCoordinator.migratedLegacyPreferences(migrated)
            XCTAssertEqual(afterOptIn["SUEnableAutomaticChecks"] as? Bool, true)
        }
    }

    func testSecureConfigurationRequiresHTTPSAndEd25519PublicKey() {
        let validKey = Data(repeating: 1, count: 32).base64EncodedString()
        XCTAssertTrue(UpdateCoordinator.hasSecureConfiguration(
            feedURLString: "https://frank4565.github.io/ClipMenu/appcast.xml", publicEDKey: validKey
        ))
        for feed in [nil, "", "http://example.com/appcast.xml", "file:///tmp/appcast.xml", "https:///appcast.xml"] as [String?] {
            XCTAssertFalse(UpdateCoordinator.hasSecureConfiguration(feedURLString: feed, publicEDKey: validKey))
        }
        for key in [nil, "", "$(CLIPMENU_SPARKLE_PUBLIC_KEY)", "invalid", Data(repeating: 1, count: 31).base64EncodedString()] as [String?] {
            XCTAssertFalse(UpdateCoordinator.hasSecureConfiguration(feedURLString: "https://example.com/appcast.xml", publicEDKey: key))
        }
    }

    func testManualChecksRemainAvailableWhenAutomaticChecksAreOff() {
        let state = CMUpdatePreferencesAvailabilityReport(
            automaticChecks: false, feedURLPresent: true, isChecking: false,
            configurationAvailable: true, canCheckForUpdates: true
        )
        XCTAssertEqual(state["checkNowEnabled"], true)
        XCTAssertEqual(state["preReleasesEnabled"], true)
        XCTAssertEqual(state["intervalEnabled"], false)
        XCTAssertEqual(state["automaticallyInstallUpdatesEnabled"], false)
        for (configured, canCheck) in [(false, true), (true, false)] {
            let unavailable = CMUpdatePreferencesAvailabilityReport(
                automaticChecks: true, feedURLPresent: true, isChecking: true,
                configurationAvailable: configured, canCheckForUpdates: canCheck
            )
            XCTAssertEqual(unavailable["checkNowEnabled"], false)
        }
    }
}
