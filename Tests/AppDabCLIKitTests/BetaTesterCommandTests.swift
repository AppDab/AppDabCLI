@testable import AppDabAutomation
@testable import AppDabCLIKit
import Testing

struct BetaTesterCommandTests {
    @Test func routesAllTesterActions() throws {
        let list = try CLIParser().parse([
            "betaTesters", "list", "--account-id", "account-1", "--app-id", "app-1",
        ])
        let invite = try CLIParser().parse([
            "betaTesters", "invite", "--account-id", "account-1", "--email", "tester@example.com",
            "--beta-group-id", "group-1", "--preview",
        ])
        let send = try CLIParser().parse([
            "betaTesters", "sendInvitation", "--account-id", "account-1",
            "--app-id", "app-1", "--tester-id", "tester-1",
        ])
        #expect(list.actionID == .listBetaTesters)
        #expect(invite.actionID == .inviteBetaTester)
        #expect(invite.executionContext.mode == .preview)
        #expect(send.actionID == .sendBetaTesterInvitation)
    }

    @Test func requiresOneTesterScopeOrDestination() {
        #expect(throws: CLIUsageError.self) {
            try CLIParser().parse([
                "betaTesters", "list", "--account-id", "account-1", "--app-id", "app-1",
                "--build-id", "build-1",
            ])
        }
        #expect(throws: CLIUsageError.self) {
            try CLIParser().parse([
                "betaTesters", "invite", "--account-id", "account-1", "--email", "tester@example.com",
            ])
        }
    }
}
