import AppDabAutomation
import ArgumentParser

struct BuildMutationOptions: ParsableArguments {
    @Option(name: .customLong("account-id"), help: "The AppDab account identifier.")
    var accountID: String

    @Option(name: .customLong("build-id"), help: "The App Store Connect build identifier.")
    var buildID: String

    @OptionGroup var output: OutputOptions
    @OptionGroup var execution: ExecutionOptions
}

struct BuildsAddTesterCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(commandName: "addTester", abstract: "Add an individual tester to a build.")

    @OptionGroup var options: BuildMutationOptions

    @Option(name: .customLong("tester-id"), help: "The beta tester identifier.")
    var testerID: String

    var invocation: CLIInvocation {
        .write(
            AddIndividualTesterToBuildAction.self,
            input: .init(accountID: options.accountID, buildID: options.buildID, targetID: testerID),
            format: options.output.format, verbose: options.output.verbose,
            executionContext: options.execution.context,
            operationDescription: "add tester \(testerID) to build \(options.buildID)",
            render: { build, style in BuildTextRenderer().render(build, style: style) }
        )
    }
}

struct BuildsRemoveTesterCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(commandName: "removeTester", abstract: "Remove an individual tester from a build.")

    @OptionGroup var options: BuildMutationOptions

    @Option(name: .customLong("tester-id"), help: "The beta tester identifier.")
    var testerID: String

    var invocation: CLIInvocation {
        .write(
            RemoveIndividualTesterFromBuildAction.self,
            input: .init(accountID: options.accountID, buildID: options.buildID, targetID: testerID),
            format: options.output.format, verbose: options.output.verbose,
            executionContext: options.execution.context,
            operationDescription: "remove tester \(testerID) from build \(options.buildID)",
            render: { build, style in BuildTextRenderer().render(build, style: style) }
        )
    }
}

struct BuildsAddBetaGroupCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(commandName: "addBetaGroup", abstract: "Add a beta group to a build.")

    @OptionGroup var options: BuildMutationOptions

    @Option(name: .customLong("beta-group-id"), help: "The beta group identifier.")
    var betaGroupID: String

    var invocation: CLIInvocation {
        .write(
            AddBetaGroupToBuildAction.self,
            input: .init(accountID: options.accountID, buildID: options.buildID, targetID: betaGroupID),
            format: options.output.format, verbose: options.output.verbose,
            executionContext: options.execution.context,
            operationDescription: "add beta group \(betaGroupID) to build \(options.buildID)",
            render: { build, style in BuildTextRenderer().render(build, style: style) }
        )
    }
}

struct BuildsRemoveBetaGroupCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(commandName: "removeBetaGroup", abstract: "Remove a beta group from a build.")

    @OptionGroup var options: BuildMutationOptions

    @Option(name: .customLong("beta-group-id"), help: "The beta group identifier.")
    var betaGroupID: String

    var invocation: CLIInvocation {
        .write(
            RemoveBetaGroupFromBuildAction.self,
            input: .init(accountID: options.accountID, buildID: options.buildID, targetID: betaGroupID),
            format: options.output.format, verbose: options.output.verbose,
            executionContext: options.execution.context,
            operationDescription: "remove beta group \(betaGroupID) from build \(options.buildID)",
            render: { build, style in BuildTextRenderer().render(build, style: style) }
        )
    }
}

struct BuildsSubmitForBetaReviewCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(commandName: "submitForBetaReview", abstract: "Submit a build for beta review.")

    @OptionGroup var options: BuildMutationOptions

    @Flag(name: .customLong("auto-notify"), inversion: .prefixedNo, help: "Notify testers automatically when approved.")
    var autoNotifyEnabled = true

    var invocation: CLIInvocation {
        .write(
            SubmitBuildForBetaReviewAction.self,
            input: .init(accountID: options.accountID, buildID: options.buildID, autoNotifyEnabled: autoNotifyEnabled),
            format: options.output.format, verbose: options.output.verbose,
            executionContext: options.execution.context,
            operationDescription: "submit build \(options.buildID) for beta review",
            render: { build, style in BuildTextRenderer().render(build, style: style) }
        )
    }
}

struct BuildsExpireCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(commandName: "expire", abstract: "Expire a build for TestFlight distribution.")

    @OptionGroup var options: BuildMutationOptions

    var invocation: CLIInvocation {
        .write(
            ExpireBuildAction.self,
            input: .init(accountID: options.accountID, buildID: options.buildID),
            format: options.output.format, verbose: options.output.verbose,
            executionContext: options.execution.context,
            operationDescription: "expire build \(options.buildID)",
            render: { build, style in BuildTextRenderer().render(build, style: style) }
        )
    }
}
