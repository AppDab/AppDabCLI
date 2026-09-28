import ArgumentParser

struct AppsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "apps",
        abstract: "List apps and inspect apps or versions.",
        subcommands: [
            AppsListCommand.self,
            AppsGetCommand.self,
            AppsVersionsCommand.self
        ],
        defaultSubcommand: AppsListCommand.self
    )
}
