import AppDabAutomation
import ArgumentParser

struct BetaGroupsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "betaGroups",
        abstract: "Work with an app's beta groups, builds, and testers.",
        subcommands: [
            BetaGroupsListCommand.self, BetaGroupsGetCommand.self,
            BetaGroupsCreateCommand.self, BetaGroupsUpdateCommand.self,
            BetaGroupsAddBuildCommand.self, BetaGroupsRemoveBuildCommand.self,
            BetaGroupsAddTesterCommand.self, BetaGroupsRemoveTesterCommand.self
        ]
    )
}

struct BetaGroupTesterOptions: ParsableArguments {
    @Option(name: .customLong("account-id"), help: "The AppDab account identifier.")
    var accountID: String

    @Option(name: .customLong("beta-group-id"), help: "The beta group identifier.")
    var betaGroupID: String

    @Option(name: .customLong("tester-id"), help: "The beta tester identifier.")
    var testerID: String

    @OptionGroup var output: OutputOptions
    @OptionGroup var execution: ExecutionOptions
}

struct BetaGroupsAddTesterCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(commandName: "addTester", abstract: "Add a tester to a beta group.")

    @OptionGroup var options: BetaGroupTesterOptions

    var invocation: CLIInvocation {
        .write(
            AddTesterToBetaGroupAction.self,
            input: .init(accountID: options.accountID, betaGroupID: options.betaGroupID, testerID: options.testerID),
            format: options.output.format, verbose: options.output.verbose,
            executionContext: options.execution.context,
            operationDescription: "add tester \(options.testerID) to beta group \(options.betaGroupID)",
            render: { membership, style in BetaGroupTesterTextRenderer().render(membership, style: style) }
        )
    }
}

struct BetaGroupsRemoveTesterCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(commandName: "removeTester", abstract: "Remove a tester from a beta group.")

    @OptionGroup var options: BetaGroupTesterOptions

    var invocation: CLIInvocation {
        .write(
            RemoveTesterFromBetaGroupAction.self,
            input: .init(accountID: options.accountID, betaGroupID: options.betaGroupID, testerID: options.testerID),
            format: options.output.format, verbose: options.output.verbose,
            executionContext: options.execution.context,
            operationDescription: "remove tester \(options.testerID) from beta group \(options.betaGroupID)",
            render: { membership, style in BetaGroupTesterTextRenderer().render(membership, style: style) }
        )
    }
}
