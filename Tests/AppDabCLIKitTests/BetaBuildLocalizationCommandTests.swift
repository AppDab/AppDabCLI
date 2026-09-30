@testable import AppDabAutomation
@testable import AppDabCLIKit
import Testing

struct BetaBuildLocalizationCommandTests {
    @Test func parsesUpdateAsGuardedWrite() throws {
        let invocation = try CLIParser().parse([
            "betaBuildLocalizations", "update", "--account-id", "account-1",
            "--localization-id", "localization-1", "--whats-new", "Test the new flow", "--preview",
        ])
        #expect(invocation.actionID == .updateBetaBuildLocalization)
        #expect(invocation.executionContext.mode == .preview)
    }

    @Test func rejectsOverlongWhatsNewText() {
        #expect(throws: CLIUsageError.self) {
            try CLIParser().parse([
                "betaBuildLocalizations", "update", "--account-id", "account-1",
                "--localization-id", "localization-1", "--whats-new", String(repeating: "x", count: 4001),
            ])
        }
    }
}
