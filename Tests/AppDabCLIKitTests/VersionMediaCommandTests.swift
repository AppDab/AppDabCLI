import AppDabAutomation
@testable import AppDabCLIKit
import AppDabKitTestSupport
import AppDabServices
import Foundation
import Testing

struct VersionMediaCommandTests {
    private let options = ["--account-id", "account", "--version-id", "version", "--locale", "en-US"]

    @Test func parsesEveryMediaCommandAndPreservesWriteOptions() throws {
        for (group, ids) in [("screenshots", [AutomationActionID.listScreenshots, .getScreenshot, .uploadScreenshot, .downloadScreenshot, .removeScreenshot, .reorderScreenshots]), ("appPreviews", [.listAppPreviews, .getAppPreview, .uploadAppPreview, .downloadAppPreview, .removeAppPreview, .reorderAppPreviews])] {
            let commands = ["list", "get", "upload", "download", "remove", "reorder"]
            let extra = [[], ["--placement-id", "placement"], ["--file", "/tmp/file.png", "--placement-group", "group", "--wait", "--timeout", "30", "--preview"], ["--placement-id", "placement", "--destination", "/tmp/destination.png", "--preview"], ["--placement-id", "placement", "--preview"], ["--placement-group", "group", "--placement-ids", "p2", "p1", "--preview"]]
            for index in commands.indices {
                let invocation = try CLIParser().parse([group, commands[index]] + options + extra[index])
                #expect(invocation.actionID == ids[index])
                if index > 1 {
                    #expect(invocation.executionContext.mode == .preview)
                }
            }
        }
    }

    @Test func helpDescribesBothGroupsAndMissingScopeIsRejected() throws {
        for group in ["screenshots", "appPreviews"] {
            do { _ = try CLIParser().parse([group, "upload", "--help"]); Issue.record("Expected help.") }
            catch let help as CLIHelpRequest { #expect(help.message.contains("--placement-group")); #expect(help.message.contains("--file")) }
            #expect(throws: CLIUsageError.self) { try CLIParser().parse([group, "list", "--account-id", "account"]) }
        }
        #expect(throws: CLIUsageError.self) { try CLIParser().parse(["screenshots", "upload"] + options + ["--file", "x", "--placement-group", "g", "--preview-frame-time-code", "00:00:01"]) }
    }

    @Test(arguments: ["screenshots", "appPreviews"])
    func listRendersTextAndJSONThroughSharedServices(group: String) async throws {
        let fixture = CLIReadMediaFixture()
        let runner = CLIRunner(executor: Executor(dataProvider: MockAutomationDataProvider(mediaService: fixture)))
        let text = await runner.run(arguments: [group, "list"] + options + ["--placement-group", "IPHONE"])
        #expect(text.exitCode == 0)
        #expect(text.standardOutput.contains("screen.png"))
        #expect(text.standardOutput.contains("IPHONE"))
        #expect(text.standardOutput.contains("Valid placement groups:"))
        #expect(text.standardOutput.contains("maximum 10"))
        let json = await runner.run(arguments: [group, "list"] + options + ["--format", "json"])
        #expect(json.exitCode == 0)
        let envelope = try JSONDecoder().decode(JSONValue.self, from: Data(json.standardOutput.utf8))
        let list = envelope.objectValue?["data"]?.objectValue?["list"]?.objectValue
        #expect(list?["appID"] == .string("app"))
        #expect(list?["localizationID"] == .string("loc"))
        #expect(list?["placements"] != nil)
        #expect(list?["requirements"] != nil)
        #expect(await fixture.requestedGroups == ["IPHONE", nil])
        #expect(await fixture.scopes.allSatisfy { $0 == scope(group) })
    }

    @Test(arguments: ["screenshots", "appPreviews"])
    func getShowsAssetAndProcessingDiagnostics(group: String) async throws {
        let fixture = CLIReadMediaFixture()
        let runner = CLIRunner(executor: Executor(dataProvider: MockAutomationDataProvider(mediaService: fixture)))
        let arguments = [group, "get"] + options + ["--placement-id", "p1"]
        let result = await runner.run(arguments: arguments)
        #expect(result.exitCode == 0)
        for value in ["p1", "a1", "ACTIVE", "COMPLETE", "PROCESSING_DETAIL", "Apple diagnostic"] {
            #expect(result.standardOutput.contains(value))
        }
        let json = await runner.run(arguments: arguments + ["--format", "json"])
        let envelope = try JSONDecoder().decode(JSONValue.self, from: Data(json.standardOutput.utf8))
        #expect(envelope.objectValue?["data"]?.objectValue?["result"] != nil)
        #expect(await fixture.scopes.allSatisfy { $0 == scope(group) })
    }

    @Test(arguments: ["screenshots", "appPreviews"])
    func rejectsInvalidMediaOptions(group: String) throws {
        let invalid: [[String]] = [
            ["get"], ["download", "--placement-id", "p1"], ["remove"],
            ["upload", "--file", "file.png"],
            ["upload", "--file", "file.png", "--placement-group", "IPHONE", "--timeout", "0"],
            ["upload", "--file", "file.png", "--placement-group", "IPHONE", "--timeout", "3601"],
            ["reorder", "--placement-group", "IPHONE"],
            ["reorder", "--placement-group", "IPHONE", "--placement-ids", "p1", "p1"],
            ["remove", "--placement-id", "p1", "--confirm", "fingerprint"],
            ["remove", "--placement-id", "p1", "--reconcile"],
        ]
        for arguments in invalid {
            #expect(throws: CLIUsageError.self) {
                try CLIParser().parse([group] + arguments + options)
            }
        }
    }

    @Test(arguments: ["screenshots", "appPreviews"])
    func uploadPreviewAndCommitForwardTheConfirmedOptions(group: String) async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("media.mov")
        try Data("media bytes".utf8).write(to: file)
        let fixture = CLIReadMediaFixture()
        let runner = runner(fixture, directory: directory)
        let arguments = [group, "upload"] + options + [
            "--file", file.path, "--placement-group", "IPHONE", "--wait", "--timeout", "17",
        ] + (group == "appPreviews" ? ["--preview-frame-time-code", "00:00:01:00"] : [])
        let preview = await runner.run(arguments: arguments + ["--preview", "--format", "json"])
        let confirmation = try fingerprint(preview)
        #expect(await fixture.mutations == 0)
        let wrong = await runner.run(arguments: arguments + ["--confirm", "wrong", "--idempotency-key", "upload"])
        #expect(wrong.exitCode != 0)
        #expect(await fixture.mutations == 0)
        let result = await runner.run(arguments: arguments + ["--confirm", confirmation, "--idempotency-key", "upload"])
        #expect(result.exitCode == 0)
        #expect(result.standardOutput.contains("p1"))
        let request = try #require(await fixture.uploads.first)
        #expect(request.filePath == file.path)
        #expect(request.placementGroup == "IPHONE")
        #expect(request.wait)
        #expect(request.timeout == 17)
        #expect(request.previewFrameTimeCode == (group == "appPreviews" ? "00:00:01:00" : nil))
        #expect(try request.fingerprint == (MediaFileFingerprint.read(path: file.path)))
        #expect(await fixture.mutations == 1)
        #expect(await fixture.scopes.allSatisfy { $0 == scope(group) })
    }

    @Test(arguments: ["screenshots", "appPreviews"])
    func interruptedUploadReconcilesWithoutAnotherUpload(group: String) async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("media.mov")
        try Data("media bytes".utf8).write(to: file)
        let fixture = CLIReadMediaFixture()
        await fixture.failUpload()
        let runner = runner(fixture, directory: directory)
        let arguments = [group, "upload"] + options + ["--file", file.path, "--placement-group", "IPHONE"]
        let preview = await runner.run(arguments: arguments + ["--preview", "--format", "json"])
        let commit = try arguments + ["--confirm", fingerprint(preview), "--idempotency-key", "recover", "--format", "json"]
        let failed = await runner.run(arguments: commit)
        #expect(failed.exitCode != 0)
        #expect(failed.standardError.contains("indeterminate_outcome"))
        let recovered = await runner.run(arguments: commit + ["--reconcile"])
        #expect(recovered.exitCode == 0)
        #expect(recovered.standardOutput.contains("uploadComplete"))
        #expect(await fixture.uploads.count == 1)
        #expect(await fixture.recoveredOperationIDs == fixture.uploadOperationIDs)
        #expect(await fixture.recoveredRequests == fixture.uploads)
    }

    @Test(arguments: ["screenshots", "appPreviews"])
    func reorderPreservesTheSuppliedOrder(group: String) async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let fixture = CLIReadMediaFixture()
        let runner = runner(fixture, directory: directory)
        let arguments = [group, "reorder"] + options + ["--placement-group", "IPHONE", "--placement-ids", "p2", "p1"]
        let preview = await runner.run(arguments: arguments + ["--preview", "--format", "json"])
        #expect(await fixture.mutations == 0)
        let result = try await runner.run(arguments: arguments + ["--confirm", fingerprint(preview), "--idempotency-key", "order"])
        #expect(result.exitCode == 0)
        #expect(await fixture.orderedIDs == ["p2", "p1"])
        #expect(await fixture.scopes.allSatisfy { $0 == scope(group) })
    }

    @Test(arguments: ["screenshots", "appPreviews"])
    func removalConfirmsAndExplainsAssetRetention(group: String) async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let fixture = CLIReadMediaFixture()
        let interaction = TestCLIInteraction(responses: ["y"])
        let runner = runner(fixture, directory: directory, interaction: interaction)
        let result = await runner.run(arguments: [group, "remove"] + options + ["--placement-id", "p1"])
        #expect(result.exitCode == 0)
        #expect(result.standardOutput.contains("reusable asset was retained"))
        #expect(interaction.standardError.contains("Proceed?"))
        #expect(interaction.standardError.contains("--reconcile"))
        #expect(await fixture.removedIDs == ["p1"])
    }

    @Test(arguments: ["screenshots", "appPreviews"])
    func cancelledUploadPerformsNoMutation(group: String) async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("media.mov")
        try Data("media bytes".utf8).write(to: file)
        let fixture = CLIReadMediaFixture()
        let runner = runner(fixture, directory: directory, interaction: TestCLIInteraction(responses: ["n"]))
        let result = await runner.run(arguments: [group, "upload"] + options + ["--file", file.path, "--placement-group", "IPHONE"])
        #expect(result.exitCode == 0)
        #expect(result.standardOutput.contains("Cancelled"))
        #expect(await fixture.mutations == 0)
    }

    @Test(arguments: ["screenshots", "appPreviews"])
    func downloadWritesOnlyAfterConfirmationAndValidatesReplay(group: String) async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appendingPathComponent(group == "appPreviews" ? "preview.m3u8" : "screen.png")
        let fixture = CLIReadMediaFixture()
        let runner = runner(fixture, directory: directory)
        let arguments = [group, "download"] + options + ["--placement-id", "p2", "--destination", destination.path]
        let preview = await runner.run(arguments: arguments + ["--preview", "--format", "json"])
        #expect(!FileManager.default.fileExists(atPath: destination.path))
        #expect(await fixture.mutations == 0)
        let commit = try arguments + ["--confirm", fingerprint(preview), "--idempotency-key", "download"]
        let result = await runner.run(arguments: commit)
        #expect(result.exitCode == 0)
        #expect(result.standardOutput.contains(destination.path))
        if group == "appPreviews" {
            #expect(result.standardOutput.contains("HLS playlist"))
            #expect(result.standardOutput.contains("Internet connection"))
        }
        #expect(try Data(contentsOf: destination) == Data("download".utf8))
        let replay = await runner.run(arguments: commit + ["--format", "json"])
        #expect(replay.exitCode == 0)
        #expect(replay.standardOutput.contains("destinationPath"))
        try FileManager.default.removeItem(at: destination)
        let missing = await runner.run(arguments: commit)
        #expect(missing.exitCode != 0)
        #expect(await fixture.downloadedIDs == ["p2"])
    }

    private func scope(_ group: String) -> VersionMediaScope {
        .init(accountID: "account", versionID: "version", locale: "en-US", kind: group == "screenshots" ? .screenshot : .appPreview)
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func runner(_ fixture: CLIReadMediaFixture, directory: URL, interaction: TestCLIInteraction? = nil) -> CLIRunner {
        .init(executor: Executor(dataProvider: MockAutomationDataProvider(mediaService: fixture), auditStore: AutomationSQLiteAuditStore(databaseURL: directory.appendingPathComponent("audit.sqlite"))), interaction: interaction)
    }

    private func fingerprint(_ result: CLIResult) throws -> String {
        #expect(result.exitCode == 0)
        let envelope = try JSONDecoder().decode(JSONValue.self, from: Data(result.standardOutput.utf8))
        return try #require(envelope.objectValue?["plan"]?.objectValue?["confirmationFingerprint"]?.stringValue)
    }
}

private actor CLIReadMediaFixture: VersionMediaServing {
    var scopes: [VersionMediaScope] = []
    var requestedGroups: [String?] = []
    var uploads: [VersionMediaUpload] = []
    var uploadOperationIDs: [String] = []
    var recoveredOperationIDs: [String] = []
    var recoveredRequests: [VersionMediaUpload] = []
    var removedIDs: [String] = []
    var downloadedIDs: [String] = []
    var orderedIDs: [String] = []
    var mutations = 0
    var uploadShouldFail = false

    func failUpload() {
        uploadShouldFail = true
    }

    private let placements = [
        VersionMediaPlacement(id: "p1", assetID: "a1", placementGroup: "IPHONE", fileName: "screen.png", assetState: "COMPLETE", placementState: "ACTIVE", stateDetails: [.object(["code": .string("PROCESSING_DETAIL"), "message": .string("Apple diagnostic")])]),
        VersionMediaPlacement(id: "p2", assetID: "a2", placementGroup: "IPHONE", fileName: "second.png", assetState: "COMPLETE", placementState: "ACTIVE"),
    ]

    func list(scope: VersionMediaScope, placementGroup: String?) async throws -> VersionMediaList {
        scopes.append(scope)
        requestedGroups.append(placementGroup)
        return .init(appID: "app", localizationID: "loc", placements: placements, requirements: [.init(placementGroup: "IPHONE", maximumCount: 10)])
    }

    func upload(scope: VersionMediaScope, request: VersionMediaUpload, operationID: String) async throws -> VersionMediaResult {
        scopes.append(scope)
        uploads.append(request)
        uploadOperationIDs.append(operationID)
        mutations += 1
        if uploadShouldFail {
            throw ServiceError.network("Upload response lost.")
        }
        return .init(placements: [placements[0]], assetID: "a1", uploadComplete: true)
    }

    func recoverUpload(scope: VersionMediaScope, request: VersionMediaUpload, operationID: String) async throws -> VersionMediaResult? {
        scopes.append(scope)
        recoveredOperationIDs.append(operationID)
        recoveredRequests.append(request)
        return .init(placements: [placements[0]], assetID: "a1", uploadComplete: true)
    }

    func download(scope: VersionMediaScope, placementID: String, destinationPath: String) async throws -> VersionMediaResult {
        scopes.append(scope)
        downloadedIDs.append(placementID)
        mutations += 1
        try Data("download".utf8).write(to: URL(fileURLWithPath: destinationPath), options: .withoutOverwriting)
        return try .init(destinationPath: destinationPath, fingerprint: .read(path: destinationPath))
    }

    func remove(scope: VersionMediaScope, placementID: String) async throws -> VersionMediaResult {
        scopes.append(scope)
        removedIDs.append(placementID)
        mutations += 1
        return .init()
    }

    func reorder(scope: VersionMediaScope, placementGroup: String, placementIDs: [String]) async throws -> VersionMediaResult {
        scopes.append(scope)
        requestedGroups.append(placementGroup)
        orderedIDs = placementIDs
        mutations += 1
        return .init(placements: placementIDs.compactMap { id in placements.first { $0.id == id } })
    }
}
