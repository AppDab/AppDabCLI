import ArgumentParser

struct AccountsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "accounts",
        abstract: "Work with configured App Store Connect accounts.",
        subcommands: [
            AccountsListCommand.self,
            AccountsAddCommand.self,
            AccountsRemoveCommand.self,
            AccountsVerifyCommand.self,
        ],
        defaultSubcommand: AccountsListCommand.self
    )
}
