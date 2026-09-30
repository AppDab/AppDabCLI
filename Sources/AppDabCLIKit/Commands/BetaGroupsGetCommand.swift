import AppDabAutomation
import ArgumentParser

struct BetaGroupsGetCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(
        commandName: "get",
        abstract: AutomationActionCatalog.descriptor(for: .getBetaGroup)?.description ?? "Get a beta group.",
    )

    @Option(name: .customLong("account-id"), help: "The AppDab account identifier.")
    var accountID: String

    @Option(name: .customLong("beta-group-id"), help: "The beta group identifier.")
    var betaGroupID: String

    @OptionGroup var output: OutputOptions

    var invocation: CLIInvocation {
        .read(
            GetBetaGroupAction.self,
            input: .init(accountID: accountID, betaGroupID: betaGroupID),
            format: output.format, verbose: output.verbose,
            render: { group, style in BetaGroupTextRenderer().render(group, style: style) },
        )
    }
}
