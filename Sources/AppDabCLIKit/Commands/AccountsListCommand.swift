import AppDabAutomation
import ArgumentParser

struct AccountsListCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: AutomationActionCatalog.descriptor(for: .listAccounts)?.description ?? "List configured accounts."
    )

    @OptionGroup var output: OutputOptions

    var invocation: CLIInvocation {
        .read(
            ListAccountsAction.self,
            input: .init(),
            format: output.format,
            verbose: output.verbose,
            render: { accounts, style in AccountsTextRenderer().render(accounts, style: style) }
        )
    }
}
