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
          dab appVersion list --account-id <account-id> --app-id <app-id>
          dab builds list --account-id <account-id> --app-id <app-id>
          dab builds get --account-id <account-id> --build-id <build-id>
          dab betaGroups list --account-id <account-id> --app-id <app-id>
          dab reviews get --account-id <account-id> --review-id <review-id>
          dab appVersion create --account-id <account-id> --app-id <app-id> --platform iOS --version 2.0
        """,
        subcommands: [
            AccountsCommand.self,
            AppsCommand.self,
            AppVersionCommand.self,
            BuildsCommand.self,
            BetaGroupsCommand.self,
            BetaTestersCommand.self,
            BetaBuildLocalizationsCommand.self,
            BetaAppTestingCommand.self,
            ReviewsCommand.self,
        ],
    )
}
