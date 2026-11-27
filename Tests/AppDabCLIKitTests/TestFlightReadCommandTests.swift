import AppDabAutomation
@testable import AppDabCLIKit
import Testing

struct TestFlightReadCommandTests {
    @Test(arguments: [
        (["builds", "get", "--build-id", "build"], AutomationActionID.getTestFlightBuild),
        (["feedback", "get", "--submission-id", "submission"], AutomationActionID.getTestFlightScreenshotFeedback),
    ])
    func parsesDetailWithoutAnAppID(arguments: [String], id: AutomationActionID) throws {
        let parser = CLIParser()
        let result = try parser.parse(["testflight"] + arguments + ["--account-id", "account"])
        #expect(result.actionID == id)
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
