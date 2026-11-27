import AppDabAutomation
@testable import AppDabCLIKit
import Testing

struct TestFlightReadCommandTests {
    @Test func detailsUseOnlyAccountAndResourceIdentifiers() throws {
        let parser = CLIParser()
        let build = try parser.parse(["builds", "get", "--build-id", "build", "--account-id", "account"])
        let feedback = try parser.parse([
            "testflight", "feedback", "get", "--submission-id", "submission", "--account-id", "account",
        ])
        #expect(build.actionID == .getBuild)
        #expect(feedback.actionID == .getTestFlightScreenshotFeedback)
    }

    @Test func feedbackListRequiresAnAppID() throws {
        let parser = CLIParser()
        let arguments = ["testflight", "feedback", "list", "--account-id", "account"]
        #expect(throws: CLIUsageError.self) { try parser.parse(arguments) }
        #expect(try parser.parse(arguments + ["--app-id", "app"]).actionID == .listTestFlightScreenshotFeedback)
    }

    @Test func existingBuildListAcceptsVersionSort() throws {
        let parser = CLIParser()
        let arguments = ["builds", "list", "--account-id", "account", "--app-id", "app", "--sort"]
        #expect(try parser.parse(arguments + ["version"]).actionID == .listBuilds)
        #expect(throws: CLIUsageError.self) { try parser.parse(arguments + ["unrecognized"]) }
    }
}
