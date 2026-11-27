import AppDabAutomation
import AppDabServices
import ArgumentParser
import Foundation

struct TestFlightCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "testflight",
        abstract: "Read TestFlight builds and screenshot feedback.",
        subcommands: [TestFlightBuildsCommand.self, TestFlightFeedbackCommand.self],
    )
}

struct TestFlightBuildsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "builds",
        abstract: "Read TestFlight builds.",
        subcommands: [TestFlightBuildsGetCommand.self],
    )
}

struct TestFlightFeedbackCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "feedback",
        abstract: "Read TestFlight screenshot feedback.",
        subcommands: [TestFlightFeedbackListCommand.self, TestFlightFeedbackGetCommand.self],
        defaultSubcommand: TestFlightFeedbackListCommand.self,
    )
}

struct TestFlightScope: ParsableArguments {
    @Option(name: .customLong("account-id"), help: "The AppDab account identifier.")
    var accountID: String

    @Option(name: .customLong("app-id"), help: "The App Store Connect app identifier.")
    var appID: String
}

struct TestFlightPagination: ParsableArguments {
    @Option(help: "Opaque pagination token returned by the preceding page.")
    var cursor: String?

    @Option(help: "Page size from 1 through 200. Reuse the preceding page size with a cursor.")
    var limit: Int?

    var request: PaginationRequest {
        .init(cursor: cursor, limit: limit)
    }

    mutating func validate() throws {
        do {
            try request.validate()
        } catch {
            throw ValidationError(error.localizedDescription)
        }
    }
}

struct TestFlightBuildsGetCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(commandName: "get", abstract: "Read TestFlight build details.")

    @Option(name: .customLong("account-id"), help: "The AppDab account identifier.")
    var accountID: String

    @Option(name: .customLong("build-id"), help: "The App Store Connect build identifier.")
    var buildID: String
    @OptionGroup var output: OutputOptions

    var invocation: CLIInvocation {
        .read(
            GetTestFlightBuildAction.self,
            input: .init(accountID: accountID, buildID: buildID),
            format: output.format,
            verbose: output.verbose,
            render: { result, style in
                let build = result.build
                var lines = [style.heading(build.id), "Version: \(build.version ?? "-")", "Build: \(build.buildNumber ?? "-")",
                             "Platform: \(build.platform ?? "-")", "Internal state: \(result.internalState ?? "-")",
                             "External state: \(build.externalState ?? "-")"]
                lines += result.localizations.map { "What to Test (\($0.locale ?? $0.id)): \($0.whatToTest ?? "-")" }
                lines += result.bundles.map { "Bundle: \($0.bundleID ?? $0.id) (\($0.bundleType ?? "-"))" }
                return lines.joined(separator: "\n")
            },
        )
    }
}

struct TestFlightFeedbackListCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List an app's screenshot submissions.")

    @OptionGroup var scope: TestFlightScope
    @OptionGroup var pagination: TestFlightPagination
    @OptionGroup var output: OutputOptions

    var invocation: CLIInvocation {
        .read(
            ListTestFlightScreenshotFeedbackAction.self,
            input: .init(accountID: scope.accountID, appID: scope.appID, pagination: pagination.request),
            format: output.format,
            verbose: output.verbose,
            render: { result, style in
                TextTable(
                    headers: ["Submitted", "Build", "Screenshots", "Submission ID"],
                    rows: result.submissions.map {
                        [$0.createdDate?.formatted(.iso8601) ?? "-", $0.buildNumber ?? "-", String($0.attachments.count), $0.id]
                    },
                ).render(style: style)
            },
            pagination: { $0.pagination },
        )
    }
}

struct TestFlightFeedbackGetCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(commandName: "get", abstract: "Read a screenshot submission.")

    @Option(name: .customLong("account-id"), help: "The AppDab account identifier.")
    var accountID: String

    @Option(name: .customLong("submission-id"), help: "The App Store Connect screenshot submission identifier.")
    var submissionID: String
    @OptionGroup var output: OutputOptions

    var invocation: CLIInvocation {
        .read(
            GetTestFlightScreenshotFeedbackAction.self,
            input: .init(accountID: accountID, submissionID: submissionID),
            format: output.format,
            verbose: output.verbose,
            render: { result, style in
                let submission = result.submission
                var lines = [style.heading(submission.id), "App ID: \(result.appID)", "Submitted: \(submission.createdDate?.formatted(.iso8601) ?? "-")",
                             "Build: \(submission.buildNumber ?? "-")", "Device: \(submission.deviceModel ?? "-")",
                             "OS version: \(submission.osVersion ?? "-")", "Screenshots: \(submission.attachments.count)"]
                if let comment = submission.comment {
                    lines.append(comment)
                }
                return lines.joined(separator: "\n")
            },
        )
    }
}
