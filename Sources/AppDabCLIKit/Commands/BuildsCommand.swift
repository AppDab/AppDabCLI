import ArgumentParser

struct BuildsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "builds",
        abstract: "Work with an app's builds.",
        subcommands: [
            BuildsListCommand.self, BuildsGetCommand.self,
            BuildsAddTesterCommand.self, BuildsRemoveTesterCommand.self,
            BuildsAddBetaGroupCommand.self, BuildsRemoveBetaGroupCommand.self,
            BuildsSubmitForBetaReviewCommand.self, BuildsExpireCommand.self
        ],
        defaultSubcommand: BuildsListCommand.self
    )
}
