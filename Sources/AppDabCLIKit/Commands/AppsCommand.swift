import ArgumentParser

struct AppsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "apps",
        abstract: "List apps, inspect an app, or create a version.",
        subcommands: [
            AppsListCommand.self,
            AppsGetCommand.self,
            AppsVersionsCommand.self
        ],
        defaultSubcommand: AppsListCommand.self
    )
}
