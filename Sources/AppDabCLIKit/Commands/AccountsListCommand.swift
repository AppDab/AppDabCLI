import AppDabAutomation
import ArgumentParser

struct AccountsListCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: AutomationActionCatalog.descriptor(for: .listAccounts)?.description ?? "List configured accounts."
    )

    @OptionGroup var output: OutputOptions

    var invocation: CLIInvocation {
        .init(
            actionID: .listAccounts,
            arguments: [:],
            format: output.format,
            verbose: output.verbose,
            executionContext: .init()
        )
    }
}
