import ArgumentParser

struct RootCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dab",
        abstract: "Work with App Store Connect through AppDab.",
        discussion: """
        Text output is the default for people. Use '--format json' for structured automation output.

        Examples:
          dab accounts list
          dab apps list --account-id <account-id>
          dab apps versions create --account-id <account-id> --app-id <app-id> --platform iOS --version 2.0
        """,
        subcommands: [
            AccountsCommand.self,
            AppsCommand.self,
            ReviewsCommand.self
        ]
    )
}
