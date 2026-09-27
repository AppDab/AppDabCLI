import AppDabAutomation
import ArgumentParser

struct AccountsRemoveCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(
        commandName: "remove",
        abstract: "Remove a configured App Store Connect API key from the local Keychain."
    )

    @Option(name: .customLong("account-id"), help: "The AppDab account identifier to remove.")
    var accountID: String

    @OptionGroup var output: OutputOptions

    mutating func validate() throws {
        guard !accountID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError("'--account-id' must be a nonempty string.")
        }
    }

    var invocation: CLIInvocation {
        .directWrite(
            RemoveAccountAction.self,
            input: .init(accountID: accountID),
            format: output.format,
            verbose: output.verbose,
            render: { account, style in AccountRemovalTextRenderer().render(account, style: style) }
        )
    }
}
