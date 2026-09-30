import AppDabAutomation
import ArgumentParser

struct BetaGroupsDeleteCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(
        commandName: "delete",
        abstract: "Delete a beta group.",
    )

    @Option(name: .customLong("account-id"), help: "The AppDab account identifier.")
    var accountID: String

    @Option(name: .customLong("beta-group-id"), help: "The beta group identifier.")
    var betaGroupID: String

    @OptionGroup var output: OutputOptions
    @OptionGroup var execution: ExecutionOptions

    var invocation: CLIInvocation {
        .write(
            DeleteBetaGroupAction.self,
            input: .init(accountID: accountID, betaGroupID: betaGroupID),
            format: output.format,
            verbose: output.verbose,
            executionContext: execution.context,
            operationDescription: "delete beta group \(betaGroupID)",
            render: { group, _ in "Deleted \(group.name) (\(group.betaGroupID))." },
        )
    }
}
