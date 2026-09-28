import ArgumentParser

struct AppsVersionsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "versions",
        abstract: "List, inspect, or create App Store Connect versions.",
        subcommands: [
            AppsVersionsListCommand.self,
            AppsVersionsGetCommand.self,
            AppsVersionsCreateCommand.self
        ],
        defaultSubcommand: AppsVersionsListCommand.self
    )
}
