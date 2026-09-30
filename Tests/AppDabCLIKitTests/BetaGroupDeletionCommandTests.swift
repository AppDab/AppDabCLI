@testable import AppDabAutomation
@testable import AppDabCLIKit
import Testing

struct BetaGroupDeletionCommandTests {
    @Test func parsesDeletionAsGuardedWrite() throws {
        let invocation = try CLIParser().parse([
            "betaGroups", "delete", "--account-id", "account-1",
            "--beta-group-id", "group-1", "--preview",
        ])

        #expect(invocation.actionID == .deleteBetaGroup)
        #expect(invocation.executionContext.mode == .preview)
    }

    @Test func deletionRequiresGroupIdentifier() {
        #expect(throws: CLIUsageError.self) {
            try CLIParser().parse(["betaGroups", "delete", "--account-id", "account-1"])
        }
    }
}
