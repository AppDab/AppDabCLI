import AppDabAutomation
@testable import AppDabCLIKit
import AppDabKitTestSupport
import AppDabServices
import Foundation
import Testing

struct XcodeCloudCommandTests {
    @Test(arguments: [
        (["listWorkflows", "--app-id", "app-1", "--limit", "25"], AutomationActionID.listXcodeCloudWorkflows, "workflows", "repository-1"),
        (["getWorkflow", "--workflow-id", "workflow-1"], .getXcodeCloudWorkflow, "workflow", "Release"),
        (["listGitReferences", "--repository-id", "repository-1"], .listXcodeCloudGitReferences, "gitReferences", "reference-1"),
        (["getBuild", "--build-run-id", "run-1"], .getXcodeCloudBuild, "buildRun", "PENDING"),
    ])
    func readsXcodeCloud(
        command: [String],
        actionID: AutomationActionID,
        outputKey: String,
        text: String,
    ) async throws {
        let runner = makeRunner(provider: XcodeCloudDataProvider())
        let arguments = arguments(for: command)

        let textResult = await runner.run(arguments: arguments)
        #expect(textResult.exitCode == 0)
        #expect(textResult.standardOutput.contains(text))

        let json = await runner.run(arguments: arguments + ["--format", "json"])
        let envelope = try responseEnvelope(json)
        #expect(envelope["action"] == .string(actionID.rawValue))
        let data = try #require(envelope["data"]?.objectValue)
        #expect(data[outputKey] != nil)
        if actionID == .listXcodeCloudWorkflows {
            #expect(data["appID"] == .string("app-1"))
            #expect(data["pagination"]?.objectValue?["limit"] == .integer(25))
        }
        if actionID == .listXcodeCloudGitReferences {
            #expect(data["repositoryID"] == .string("repository-1"))
        }
    }

    @Test func neutralizesWorkflowNameTerminalControlsInText() async throws {
        let provider = XcodeCloudDataProvider()
        let name = "Release \u{001B}[2J\u{009B}H"
        await provider.setWorkflow(.init(workflowID: "workflow-1", name: name))
        let runner = makeRunner(provider: provider)
        let arguments = arguments(for: ["getWorkflow", "--workflow-id", "workflow-1"])

        let text = await runner.run(arguments: arguments)
        #expect(text.exitCode == 0)
        #expect(text.standardOutput.contains("Release �[2J�H"))
        #expect(!text.standardOutput.contains("\u{001B}"))
        #expect(!text.standardOutput.contains("\u{009B}"))

        let json = await runner.run(arguments: arguments + ["--format", "json"])
        let envelope = try responseEnvelope(json)
        #expect(envelope["data"]?.objectValue?["workflow"]?.objectValue?["name"] == .string(name))
    }

    @Test(arguments: [([], nil as Bool?), (["--clean"], true), (["--no-clean"], false)])
    func startsBuildDirectly(cleanArguments: [String], clean: Bool?) async throws {
        let provider = XcodeCloudDataProvider()
        let interaction = TestCLIInteraction()
        let runner = makeRunner(provider: provider, interaction: interaction)
        let command = ["startBuild", "--workflow-id", "workflow-1"]
        let source = clean == nil ? [] : ["--source-branch-or-tag-id", "reference-1"]
        let arguments = arguments(for: command + source + cleanArguments)
        let result = await runner.run(arguments: arguments + (clean == true ? [] : ["--format", "json"]))

        #expect(result.exitCode == 0)
        #expect(interaction.standardError.isEmpty)
        #expect(await provider.startRequests == [
            .init(workflowID: "workflow-1", sourceBranchOrTagID: source.last, clean: clean),
        ])
        if clean == true {
            #expect(result.standardOutput.contains("Queued Xcode Cloud build"))
            #expect(result.standardOutput.contains("run-1"))
        } else {
            let envelope = try responseEnvelope(result)
            #expect(envelope["action"] == .string("start_xcode_cloud_build"))
            #expect(envelope["data"]?.objectValue?["buildRun"]?.objectValue?["buildRunID"] == .string("run-1"))
            #expect(envelope["plan"] == nil)
            #expect(envelope["receipt"] == nil)
        }
    }

    @Test(arguments: [
        ["listWorkflows", "--app-id", "app-1", "--limit", "201"],
        ["listGitReferences", "--repository-id", "repository-1", "--cursor", "next"],
        ["getWorkflow"],
        ["getBuild"],
        ["startBuild", "--workflow-id", "workflow-1", "--source-branch-or-tag-id", ""],
        ["startBuild", "--workflow-id", "workflow-1", "--preview"],
    ])
    func rejectsInvalidOptions(command: [String]) {
        #expect(throws: CLIUsageError.self) {
            try CLIParser().parse(arguments(for: command))
        }
    }

    @Test func showsXcodeCloudHelp() async {
        let runner = makeRunner(provider: XcodeCloudDataProvider())
        let group = await runner.run(arguments: ["xcodeCloud", "--help"])
        let startBuild = await runner.run(arguments: ["help", "xcodeCloud", "startBuild"])

        #expect(group.exitCode == 0)
        #expect(group.standardOutput.contains("listGitReferences"))
        #expect(startBuild.exitCode == 0)
        #expect(startBuild.standardOutput.contains("--clean/--no-clean"))
        #expect(startBuild.standardOutput.contains("--source-branch-or-tag-id"))
    }

    private func arguments(for command: [String]) -> [String] {
        ["xcodeCloud"] + command + ["--account-id", "account-1"]
    }

    private func makeRunner(provider: XcodeCloudDataProvider, interaction: TestCLIInteraction? = nil) -> CLIRunner {
        let auditURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppDabCLIXcodeCloudTests-\(UUID().uuidString)")
            .appendingPathComponent("audit.sqlite")
        return .init(
            executor: Executor(dataProvider: provider, auditStore: AutomationSQLiteAuditStore(databaseURL: auditURL)),
            interaction: interaction,
        )
    }

    private func responseEnvelope(_ result: CLIResult) throws -> [String: JSONValue] {
        #expect(result.exitCode == 0)
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(result.standardOutput.utf8))
        return try #require(value.objectValue)
    }
}
