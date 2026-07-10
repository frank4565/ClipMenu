import XCTest
@testable import ClipMenu

#if DEBUG || TESTING
final class UpdateCoordinatorDebugTests: XCTestCase {
#if TESTING
    override func setUp() {
        super.setUp()
        UpdateCoordinator.shared.debugResetForTesting()
    }

    override func tearDown() {
        UpdateCoordinator.shared.debugResetForTesting()
        super.tearDown()
    }
#endif

    func testUpdateCoordinatorPolicyReportsMatchExpectedState() throws {
        let coordinator = UpdateCoordinator.shared
        let reports: [(String, [String: Any])] = [
            ("skip", coordinator.debugUpdateSkipBehaviorReport()),
            ("readyToInstallPresentation", coordinator.debugReadyToInstallPresentationPolicyReport()),
            ("downloadFailure", coordinator.debugDownloadFailurePolicyReport()),
            ("checkFailure", coordinator.debugUpdateCheckFailurePolicyReport()),
            ("checkNetwork", coordinator.debugUpdateCheckNetworkExerciseReport()),
            ("appcastParsing", coordinator.debugAppcastParsingAndDownloadNamingReport()),
            ("payloadFailure", coordinator.debugUpdateCheckPayloadFailureReport()),
            ("passiveAlerts", coordinator.debugUpdatePassiveAlertsReport()),
            ("automaticInstall", coordinator.debugAutomaticInstallUpdatesReport()),
            ("presentation", coordinator.debugUpdatePresentationPolicyReport()),
            ("systemProfileFeed", coordinator.debugSystemProfileFeedReport())
        ]
        let failedReports = reports.compactMap { name, report in
            (report["matchesExpected"] as? Bool) == true ? nil : name
        }
        if !failedReports.isEmpty {
            XCTFail("Reports did not match expected state: \(failedReports.joined(separator: ", "))")
        }
    }

#if TESTING
    func testUpdateCoordinatorNetworkAndVerificationSmokeReportsRun() {
        let coordinator = UpdateCoordinator.shared
        XCTAssertFalse(coordinator.debugDownloadAndOpenFailureExerciseReport().isEmpty)
        XCTAssertFalse(coordinator.debugDownloadedUpdateVerificationReport().isEmpty)
        XCTAssertEqual(coordinator.debugUpdatePresentationDispatchReport()["matchesExpected"] as? Bool, true)
    }
#endif

    func testUpdateCoordinatorUIFactoryReportsMatchExpectedState() throws {
        let coordinator = UpdateCoordinator.shared
        let reports: [(String, [String: Any])] = [
            ("checking", coordinator.debugCheckingForUpdatesReport()),
            ("permissionPrompt", coordinator.debugUpdatePermissionPromptReport()),
            ("readyToInstall", coordinator.debugReadyToInstallReport()),
            ("availableAlert", coordinator.debugAvailableUpdateAlertReport()),
            ("availableAccessory", coordinator.debugAvailableUpdateAccessoryReport()),
            ("downloadProgress", coordinator.debugDownloadProgressReport()),
            ("feedSelection", coordinator.debugUpdateFeedSelectionReport())
        ]

        let failedReports = reports.compactMap { name, report in
            (report["matchesExpected"] as? Bool) == true ? nil : name
        }
        if !failedReports.isEmpty {
            XCTFail("Reports did not match expected state: \(failedReports.joined(separator: ", "))")
        }
    }
}
#endif
