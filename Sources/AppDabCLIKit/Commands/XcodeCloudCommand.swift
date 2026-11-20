import AppDabAutomation
import AppDabServices
import ArgumentParser
import Foundation

struct XcodeCloudCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "xcodeCloud",
        abstract: "Discover Xcode Cloud workflows and manage build runs.",
        subcommands: [
            XcodeCloudListWorkflowsCommand.self,
            XcodeCloudGetWorkflowCommand.self,
            XcodeCloudListGitReferencesCommand.self,
            XcodeCloudStartBuildCommand.self,
            XcodeCloudGetBuildCommand.self,
        ],
    )
}

struct XcodeCloudOptions: ParsableArguments {
    @Option(name: .customLong("account-id"), help: "The AppDab account identifier.")
    var accountID: String

    @OptionGroup var output: OutputOptions
}

struct XcodeCloudPaginationOptions: ParsableArguments {
    @Option(help: "Opaque pagination token returned by a previous list response.")
    var cursor: String?

    @Option(help: "Maximum results to return, from 1 through 200.")
    var limit: Int?

    var request: PaginationRequest {
        .init(cursor: cursor, limit: limit)
    }

    func validate() throws {
        do {
            try request.validate()
        } catch {
            throw ValidationError(error.localizedDescription)
        }
    }
}

struct XcodeCloudListWorkflowsCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(
        commandName: "listWorkflows",
        abstract: ListXcodeCloudWorkflowsAction.descriptor.description,
    )

    @OptionGroup var options: XcodeCloudOptions
    @OptionGroup var pagination: XcodeCloudPaginationOptions

    @Option(name: .customLong("app-id"), help: "The App Store Connect app identifier.")
    var appID: String

    var invocation: CLIInvocation {
        .read(
            ListXcodeCloudWorkflowsAction.self,
            input: .init(accountID: options.accountID, appID: appID, pagination: pagination.request),
            format: options.output.format,
            verbose: options.output.verbose,
            render: { list, style in XcodeCloudTextRenderer().render(list, style: style) },
            pagination: { $0.pagination },
        )
    }
}

struct XcodeCloudGetWorkflowCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(
        commandName: "getWorkflow",
        abstract: GetXcodeCloudWorkflowAction.descriptor.description,
    )

    @OptionGroup var options: XcodeCloudOptions

    @Option(name: .customLong("workflow-id"), help: "The Xcode Cloud workflow identifier.")
    var workflowID: String

    var invocation: CLIInvocation {
        .read(
            GetXcodeCloudWorkflowAction.self,
            input: .init(accountID: options.accountID, workflowID: workflowID),
            format: options.output.format,
            verbose: options.output.verbose,
            render: { workflow, style in XcodeCloudTextRenderer().render(workflow, style: style) },
        )
    }
}

struct XcodeCloudListGitReferencesCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(
        commandName: "listGitReferences",
        abstract: ListXcodeCloudGitReferencesAction.descriptor.description,
    )

    @OptionGroup var options: XcodeCloudOptions
    @OptionGroup var pagination: XcodeCloudPaginationOptions

    @Option(name: .customLong("repository-id"), help: "The Xcode Cloud repository identifier.")
    var repositoryID: String

    var invocation: CLIInvocation {
        .read(
            ListXcodeCloudGitReferencesAction.self,
            input: .init(accountID: options.accountID, repositoryID: repositoryID, pagination: pagination.request),
            format: options.output.format,
            verbose: options.output.verbose,
            render: { list, style in XcodeCloudTextRenderer().render(list, style: style) },
            pagination: { $0.pagination },
        )
    }
}

struct XcodeCloudStartBuildCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(
        commandName: "startBuild",
        abstract: StartXcodeCloudBuildAction.descriptor.description,
    )

    @OptionGroup var options: XcodeCloudOptions

    @Option(name: .customLong("workflow-id"), help: "The Xcode Cloud workflow identifier.")
    var workflowID: String

    @Option(name: .customLong("source-branch-or-tag-id"), help: "The Git reference identifier returned by listGitReferences. Omit to use the default source.")
    var sourceBranchOrTagID: String?

    @Flag(inversion: .prefixedNo, help: "Override the workflow's clean build setting.")
    var clean: Bool?

    private var input: StartXcodeCloudBuildInput {
        .init(accountID: options.accountID, workflowID: workflowID, sourceBranchOrTagID: sourceBranchOrTagID, clean: clean)
    }

    func validate() throws {
        do {
            try input.validate()
        } catch {
            throw ValidationError(error.localizedDescription)
        }
    }

    var invocation: CLIInvocation {
        .directWrite(
            StartXcodeCloudBuildAction.self,
            input: input,
            format: options.output.format,
            verbose: options.output.verbose,
            render: { run, style in XcodeCloudTextRenderer().render(run, heading: "Queued Xcode Cloud build", style: style) },
        )
    }
}

struct XcodeCloudGetBuildCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(
        commandName: "getBuild",
        abstract: GetXcodeCloudBuildAction.descriptor.description,
    )

    @OptionGroup var options: XcodeCloudOptions

    @Option(name: .customLong("build-run-id"), help: "The Xcode Cloud build run identifier.")
    var buildRunID: String

    var invocation: CLIInvocation {
        .read(
            GetXcodeCloudBuildAction.self,
            input: .init(accountID: options.accountID, buildRunID: buildRunID),
            format: options.output.format,
            verbose: options.output.verbose,
            render: { run, style in XcodeCloudTextRenderer().render(run, heading: "Xcode Cloud build", style: style) },
        )
    }
}
