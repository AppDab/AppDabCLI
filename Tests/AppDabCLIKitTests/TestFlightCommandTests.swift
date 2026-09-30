import AppDabAutomation
@testable import AppDabCLIKit
import AppDabKitTestSupport
import AppDabServices
import Foundation
import Testing

@Suite("TestFlight CLI commands")
struct TestFlightCommandTests {
    @Test func betaGroupReadsRenderTextAndStructuredJSON() async throws {
        let runner = makeRunner(TestFlightCLIProvider())
        let listed = await runner.run(arguments: [
            "betaGroups", "list", "--account-id", "account-1", "--app-id", "app-1",
        ])
        let detail = await runner.run(arguments: [
            "betaGroups", "get", "--account-id", "account-1", "--beta-group-id", "group-1", "--format", "json",
        ])
        let envelope = try #require(JSONSerialization.jsonObject(with: Data(detail.standardOutput.utf8)) as? [String: Any])
        let data = try #require(envelope["data"] as? [String: Any])
        let group = try #require(data["betaGroup"] as? [String: Any])

        #expect(listed.exitCode == 0)
        #expect(listed.standardOutput.contains("Early Access"))
        #expect(detail.exitCode == 0)
        #expect(group["betaGroupID"] as? String == "group-1")
    }

    @Test func betaGroupCreateAndUpdateUseGuardedCommands() async throws {
        let provider = TestFlightCLIProvider()
        let executor = makeExecutor(provider)
        let runner = CLIRunner(executor: executor)
        let createInput = CreateBetaGroupInput(accountID: "account-1", appID: "app-1", name: "New Group", isInternalGroup: true)
        let createPlan = try await executor.preview(CreateBetaGroupAction.self, input: createInput)
        let created = await runner.run(arguments: [
            "betaGroups", "create", "--account-id", "account-1", "--app-id", "app-1", "--name", "New Group", "--internal",
            "--confirm", createPlan.confirmationFingerprint, "--idempotency-key", "create-group",
        ])
        #expect(created.exitCode == 0)
        #expect(created.standardOutput.contains("New Group"))
        #expect(await provider.mutationCount == 1)

        let updateInput = UpdateBetaGroupInput(accountID: "account-1", betaGroupID: "group-1", changes: .init(feedbackEnabled: false))
        let updatePlan = try await executor.preview(UpdateBetaGroupAction.self, input: updateInput)
        let updated = await runner.run(arguments: [
            "betaGroups", "update", "--account-id", "account-1", "--beta-group-id", "group-1", "--feedback-enabled", "false",
            "--confirm", updatePlan.confirmationFingerprint, "--idempotency-key", "update-group",
        ])
        #expect(updated.exitCode == 0)
        #expect(await provider.feedbackEnabled == false)
        #expect(await provider.mutationCount == 2)
    }

    @Test func betaGroupBuildWriteRecoversAfterLostResponse() async throws {
        let provider = TestFlightCLIProvider(failAfterMutation: true)
        let executor = makeExecutor(provider)
        let input = BetaGroupBuildInput(accountID: "account-1", betaGroupID: "group-1", buildID: "build-1")
        let plan = try await executor.preview(AddBuildToBetaGroupAction.self, input: input)
        let runner = CLIRunner(executor: executor)
        let arguments = [
            "betaGroups", "addBuild", "--account-id", "account-1", "--beta-group-id", "group-1", "--build-id", "build-1",
            "--confirm", plan.confirmationFingerprint, "--idempotency-key", "add-build",
        ]
        let uncertain = await runner.run(arguments: arguments)
        let recovered = await runner.run(arguments: arguments + ["--reconcile"])

        #expect(uncertain.exitCode == 1)
        #expect(recovered.exitCode == 0)
        #expect(recovered.standardOutput.contains("Beta Group Build"))
        #expect(await provider.mutationCount == 1)
    }

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
            ["betaGroups", "removeTester"] + group + ["--tester-id", "tester-1"],
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
            "builds", "addTester", "--account-id", "account-1", "--build-id", "build-1", "--tester-id", "tester-2",
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
            input: .init(accountID: "account-1", buildID: "build-1", autoNotifyEnabled: false),
        )
        let result = await CLIRunner(executor: executor).run(arguments: [
            "builds", "submitForBetaReview", "--account-id", "account-1", "--build-id", "build-1",
            "--no-auto-notify", "--format", "json", "--confirm", plan.confirmationFingerprint,
            "--idempotency-key", "submit-1",
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
            "--idempotency-key", "remove-1",
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
    private var betaGroups: [BetaGroupSummary] = [.init(betaGroupID: "group-1", name: "Early Access", feedbackEnabled: true)]
    private var groupBuilds: [String] = []
    private var submissionID: String?
    private var notifications: Bool? = true
    private var expired = false
    private let failAfterMutation: Bool
    private(set) var mutationCount = 0

    init(failAfterMutation: Bool = false) {
        self.failAfterMutation = failAfterMutation
    }

    var buildTesterIDs: [String] {
        buildTesters
    }

    var autoNotifyEnabled: Bool? {
        notifications
    }

    var feedbackEnabled: Bool? {
        betaGroups.first(where: { $0.betaGroupID == "group-1" })?.feedbackEnabled
    }

    func listBetaGroups(accountID _: String, appID: String, pagination: PaginationRequest) async throws -> BetaGroupList {
        try .init(appID: appID, betaGroups: betaGroups, pagination: .init(limit: pagination.resolvedLimit(), total: betaGroups.count, nextCursor: nil))
    }

    func getBetaGroup(accountID _: String, betaGroupID: String) async throws -> BetaGroupSummary {
        guard let group = betaGroups.first(where: { $0.betaGroupID == betaGroupID }) else { throw ServiceError.upstream("Beta group not found.") }
        return group
    }

    func createBetaGroup(accountID _: String, appID _: String, name: String, isInternalGroup: Bool, hasAccessToAllBuilds: Bool?) async throws -> BetaGroupSummary {
        mutationCount += 1
        let group = BetaGroupSummary(betaGroupID: "group-2", name: name, isInternalGroup: isInternalGroup, hasAccessToAllBuilds: hasAccessToAllBuilds)
        betaGroups.append(group)
        return group
    }

    func updateBetaGroup(accountID: String, betaGroupID: String, changes: BetaGroupChanges) async throws -> BetaGroupSummary {
        mutationCount += 1
        let group = try await getBetaGroup(accountID: accountID, betaGroupID: betaGroupID)
        let updated = BetaGroupSummary(betaGroupID: betaGroupID, name: changes.name ?? group.name, feedbackEnabled: changes.feedbackEnabled ?? group.feedbackEnabled)
        betaGroups.removeAll { $0.betaGroupID == betaGroupID }
        betaGroups.append(updated)
        return updated
    }

    func betaGroupBuildMembership(accountID: String, betaGroupID: String, buildID: String) async throws -> BetaGroupBuildMembership {
        try await .init(betaGroup: getBetaGroup(accountID: accountID, betaGroupID: betaGroupID), buildID: buildID, isMember: groupBuilds.contains(buildID))
    }

    func mutateBetaGroupBuild(accountID: String, betaGroupID: String, buildID: String, add: Bool) async throws -> BetaGroupBuildMembership {
        mutationCount += 1
        if add {
            groupBuilds.append(buildID)
        } else {
            groupBuilds.removeAll { $0 == buildID }
        }
        if failAfterMutation {
            throw ServiceError.upstream("Response lost after applying mutation.")
        }
        return try await betaGroupBuildMembership(accountID: accountID, betaGroupID: betaGroupID, buildID: buildID)
    }

    nonisolated func accountStore() throws -> any AutomationAccountStoring {
        try MockAutomationDataProvider().accountStore()
    }

    func listAccounts() async throws -> [AccountSummary] {
        try await base.listAccounts()
    }

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

    func buildSnapshot(accountID _: String, buildID: String, scope: BuildTestFlightSnapshotScope) async throws -> BuildTestFlightSnapshot {
        let testers: [String]
        let groups: [String]
        switch scope {
        case .build:
            testers = []
            groups = []
        case let .individualTester(id):
            testers = buildTesters.contains(id) ? [id] : []
            groups = []
        case let .betaGroup(id):
            testers = []
            groups = buildGroups.contains(id) ? [id] : []
        }
        return .init(
            build: build(buildID), individualTesterIDs: testers, betaGroupIDs: groups,
            betaReviewSubmissionID: submissionID, externalBetaState: "READY_FOR_BETA_SUBMISSION",
            autoNotifyEnabled: notifications,
        )
    }

    func mutateBuild(accountID _: String, buildID: String, mutation: BuildTestFlightMutation) async throws -> BuildSummary {
        mutationCount += 1
        switch mutation {
        case let .addIndividualTesters(ids): buildTesters.append(contentsOf: ids)
        case let .removeIndividualTesters(ids): buildTesters.removeAll { ids.contains($0) }
        case let .addBetaGroups(ids): buildGroups.append(contentsOf: ids)
        case let .removeBetaGroups(ids): buildGroups.removeAll { ids.contains($0) }
        case let .submitForBetaReview(enabled):
            submissionID = "submission-1"
            notifications = enabled
        case .expire: expired = true
        }
        if failAfterMutation {
            throw ServiceError.upstream("Response lost after applying mutation.")
        }
        return build(buildID)
    }

    func betaGroupTesterMembership(accountID _: String, betaGroupID: String, testerID: String) async throws -> BetaGroupTesterMembership {
        .init(betaGroupID: betaGroupID, betaGroupName: "Early Access", testerID: testerID, isMember: groupTesters.contains(testerID))
    }

    func mutateBetaGroupTester(accountID: String, betaGroupID: String, mutation: BetaGroupTesterMutation) async throws -> BetaGroupTesterMembership {
        mutationCount += 1
        let testerID: String
        switch mutation {
        case let .add(id):
            testerID = id
            groupTesters.append(id)
        case let .remove(id):
            testerID = id
            groupTesters.removeAll { $0 == id }
        }
        if failAfterMutation {
            throw ServiceError.upstream("Response lost after applying mutation.")
        }
        return try await betaGroupTesterMembership(accountID: accountID, betaGroupID: betaGroupID, testerID: testerID)
    }

    private func build(_ id: String) -> BuildSummary {
        .init(buildID: id, version: "42", platform: "iOS", processingState: "VALID",
              uploadedDate: Date(timeIntervalSince1970: 100), expirationDate: nil, expired: expired)
    }
}
