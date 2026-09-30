@testable import AppDabAutomation
@testable import AppDabCLIKit
import Testing

struct BetaAppTestingCommandTests {
    private let app = ["--account-id", "account-1", "--app-id", "app-1"]

    @Test func routesAllBetaAppTestingActions() throws {
        let commands: [(String, [String], AutomationActionID)] = [
            ("listLocalizations", [], .listBetaAppLocalizations),
            ("createLocalization", ["--locale", "en-US"], .createBetaAppLocalization),
            ("updateLocalization", ["--localization-id", "localization-1", "--description", "Test",
                                    "--feedback-email", "test@example.com", "--marketing-url", "https://example.com",
                                    "--privacy-policy-url", "https://example.com/privacy", "--tvos-privacy-policy", "Policy"], .updateBetaAppLocalization),
            ("deleteLocalization", ["--localization-id", "localization-1"], .deleteBetaAppLocalization),
            ("getReviewDetail", [], .getBetaAppReviewDetail),
            ("updateReviewDetail", ["--contact-first-name", "Ada", "--contact-last-name", "Lovelace",
                                    "--contact-phone", "123", "--contact-email", "ada@example.com",
                                    "--demo-account-required", "false", "--demo-account-name", "",
                                    "--demo-account-password", "", "--notes", "Notes"], .updateBetaAppReviewDetail),
            ("getLicenseAgreement", [], .getBetaLicenseAgreement),
            ("updateLicenseAgreement", ["--agreement-text", "Terms"], .updateBetaLicenseAgreement),
        ]
        for (command, arguments, actionID) in commands {
            let invocation = try CLIParser().parse(["betaAppTesting", command] + app + arguments)
            #expect(invocation.actionID == actionID)
        }
    }

    @Test func localizationUpdateRequiresAllFields() {
        #expect(throws: CLIUsageError.self) {
            try CLIParser().parse(["betaAppTesting", "updateLocalization"] + app + [
                "--localization-id", "localization-1", "--description", "Test",
            ])
        }
    }
}
