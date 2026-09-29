import AppDabAutomation
@testable import AppDabCLIKit
import AppDabKitTestSupport
import AppDabServices
import Foundation
import Testing

@Suite("TestFlight CLI commands")
struct TestFlightCommandTests {
    @Test func allNewCommandsProduceGuardedPreviews() async throws {
        let provider = TestFlightCLIProvider()
        let runner = makeRunner(provider)
        let build = ["--account-id", "account-1", "--build-id", "build-1"]
        let group = ["--account-id", "account-1", "--beta-group-id", "group-1"]
        let commands = [
            ["builds", "addTester"] + build + ["--tester-id", "tester-2"],
            ["builds", "removeTester"] + build + ["--tester-id", "tester-1"],
            ["builds", "addBetaGroup"] + build + ["--beta-group-id", "group-1"],
            ["builds", "removeBetaGroup"] + build + ["--beta-group-id", "group-1"],
            ["builds", "submitForBetaReview"] + build + ["--no-auto-notify"],
            ["builds", "expire"] + build,
            ["betaGroups", "addTester"] + group + ["--tester-id", "tester-2"],
            ["betaGroups", "removeTester"] + group + ["--tester-id", "tester-1"]
        ]

        for arguments in commands {
            let result = await runner.run(arguments: arguments + ["--preview", "--format", "json"])
            let envelope = try #require(JSONSerialization.jsonObject(with: Data(result.standardOutput.utf8)) as? [String: Any])
            #expect(result.exitCode == 0)
            #expect(envelope["plan"] != nil)
        }
        #expect(await provider.mutationCount == 0)
    }

    @Test func interactiveBuildWriteRendersBuildAndRecoveryCommand() async {
        let provider = TestFlightCLIProvider()
        let interaction = TestCLIInteraction(responses: ["yes"])
        let runner = makeRunner(provider, interaction: interaction)
        let result = await runner.run(arguments: [
            "builds", "addTester", "--account-id", "account-1", "--build-id", "build-1", "--tester-id", "tester-2"
        ])

        #expect(result.exitCode == 0)
        #expect(result.standardOutput.contains("Build ID"))
        #expect(result.standardOutput.contains("build-1"))
        #expect(interaction.standardError.contains("--reconcile"))
        #expect(await provider.buildTesterIDs.contains("tester-2"))
        #expect(await provider.mutationCount == 1)
    }

    @Test func betaReviewFlagReachesTypedAction() async throws {
        let provider = TestFlightCLIProvider()
        let executor = makeExecutor(provider)
        let plan = try await executor.preview(
            SubmitBuildForBetaReviewAction.self,
            input: .init(accountID: "account-1", buildID: "build-1", autoNotifyEnabled: false)
        )
        let result = await CLIRunner(executor: executor).run(arguments: [
            "builds", "submitForBetaReview", "--account-id", "account-1", "--build-id", "build-1",
            "--no-auto-notify", "--format", "json", "--confirm", plan.confirmationFingerprint,
            "--idempotency-key", "submit-1"
        ])

        #expect(result.exitCode == 0)
        #expect(result.standardOutput.contains("\"action\" : \"create_beta_app_review_submission\""))
        #expect(await provider.autoNotifyEnabled == false)
    }

    @Test func betaGroupWriteRecoversAfterLostResponse() async throws {
        let provider = TestFlightCLIProvider(failAfterMutation: true)
        let executor = makeExecutor(provider)
        let input = BetaGroupTesterInput(accountID: "account-1", betaGroupID: "group-1", testerID: "tester-1")
        let plan = try await executor.preview(RemoveTesterFromBetaGroupAction.self, input: input)
        let runner = CLIRunner(executor: executor)
        let arguments = [
            "betaGroups", "removeTester", "--account-id", "account-1", "--beta-group-id", "group-1",
            "--tester-id", "tester-1", "--confirm", plan.confirmationFingerprint,
            "--idempotency-key", "remove-1"
        ]
        let uncertain = await runner.run(arguments: arguments)
        let recovered = await runner.run(arguments: arguments + ["--reconcile"])

        #expect(uncertain.exitCode == 1)
        #expect(uncertain.standardError.contains("--reconcile"))
        #expect(recovered.exitCode == 0)
        #expect(recovered.standardOutput.contains("Beta Group Tester"))
        #expect(recovered.standardOutput.contains("Member"))
        #expect(recovered.standardOutput.contains("No"))
        #expect(await provider.mutationCount == 1)
    }

    private func makeRunner(_ provider: TestFlightCLIProvider, interaction: TestCLIInteraction? = nil) -> CLIRunner {
        CLIRunner(executor: makeExecutor(provider), interaction: interaction)
    }

    private func makeExecutor(_ provider: TestFlightCLIProvider) -> Executor {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("TestFlightCommandTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("audit.sqlite")
        return Executor(dataProvider: provider, auditStore: AutomationSQLiteAuditStore(databaseURL: databaseURL))
    }
}

private actor TestFlightCLIProvider: AutomationDataProviding {
    private let base = MockAutomationDataProvider()
    private var buildTesters = ["tester-1"]
    private var buildGroups: [String] = []
    private var groupTesters = ["tester-1"]
    private var submissionID: String?
    private var notifications: Bool? = true
    private var expired = false
    private let failAfterMutation: Bool
    private(set) var mutationCount = 0

    init(failAfterMutation: Bool = false) { self.failAfterMutation = failAfterMutation }

    var buildTesterIDs: [String] { buildTesters }
    var autoNotifyEnabled: Bool? { notifications }

    nonisolated func accountStore() throws -> any AutomationAccountStoring { try MockAutomationDataProvider().accountStore() }
    func listAccounts() async throws -> [AccountSummary] { try await base.listAccounts() }
    func listApps(accountID: String, pagination: PaginationRequest) async throws -> AppList {
        try await base.listApps(accountID: accountID, pagination: pagination)
    }
    func getApp(accountID: String, appID: String) async throws -> AppDetail {
        try await base.getApp(accountID: accountID, appID: appID)
    }
    func getCustomerReview(accountID: String, reviewID: String) async throws -> CustomerReview {
        try await base.getCustomerReview(accountID: accountID, reviewID: reviewID)
    }
    func listCustomerReviews(accountID: String, appID: String, pagination: PaginationRequest) async throws -> ReviewList {
        try await base.listCustomerReviews(accountID: accountID, appID: appID, pagination: pagination)
    }

    func buildSnapshot(accountID: String, buildID: String, scope: BuildTestFlightSnapshotScope) async throws -> BuildTestFlightSnapshot {
        let testers: [String]
        let groups: [String]
        switch scope {
        case .build:
            testers = []
            groups = []
        case .individualTester(let id):
            testers = buildTesters.contains(id) ? [id] : []
            groups = []
        case .betaGroup(let id):
            testers = []
            groups = buildGroups.contains(id) ? [id] : []
        }
        return .init(
            build: build(buildID), individualTesterIDs: testers, betaGroupIDs: groups,
            betaReviewSubmissionID: submissionID, externalBetaState: "READY_FOR_BETA_SUBMISSION",
            autoNotifyEnabled: notifications
        )
    }

    func mutateBuild(accountID: String, buildID: String, mutation: BuildTestFlightMutation) async throws -> BuildSummary {
        mutationCount += 1
        switch mutation {
        case .addIndividualTesters(let ids): buildTesters.append(contentsOf: ids)
        case .removeIndividualTesters(let ids): buildTesters.removeAll { ids.contains($0) }
        case .addBetaGroups(let ids): buildGroups.append(contentsOf: ids)
        case .removeBetaGroups(let ids): buildGroups.removeAll { ids.contains($0) }
        case .submitForBetaReview(let enabled):
            submissionID = "submission-1"
            notifications = enabled
        case .expire: expired = true
        }
        if failAfterMutation { throw ServiceError.upstream("Response lost after applying mutation.") }
        return build(buildID)
    }

    func betaGroupTesterMembership(accountID: String, betaGroupID: String, testerID: String) async throws -> BetaGroupTesterMembership {
        .init(betaGroupID: betaGroupID, betaGroupName: "Early Access", testerID: testerID, isMember: groupTesters.contains(testerID))
    }

    func mutateBetaGroupTester(accountID: String, betaGroupID: String, mutation: BetaGroupTesterMutation) async throws -> BetaGroupTesterMembership {
        mutationCount += 1
        let testerID: String
        switch mutation {
        case .add(let id):
            testerID = id
            groupTesters.append(id)
        case .remove(let id):
            testerID = id
            groupTesters.removeAll { $0 == id }
        }
        if failAfterMutation { throw ServiceError.upstream("Response lost after applying mutation.") }
        return try await betaGroupTesterMembership(accountID: accountID, betaGroupID: betaGroupID, testerID: testerID)
    }

    private func build(_ id: String) -> BuildSummary {
        .init(buildID: id, version: "42", platform: "iOS", processingState: "VALID",
              uploadedDate: Date(timeIntervalSince1970: 100), expirationDate: nil, expired: expired)
    }
}
