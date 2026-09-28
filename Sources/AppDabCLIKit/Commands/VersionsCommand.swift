import ArgumentParser

struct VersionsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "versions",
        abstract: "List, inspect, or create App Store Connect versions.",
        subcommands: [
            VersionsListCommand.self,
            VersionsGetCommand.self,
            VersionsCreateCommand.self
        ],
        defaultSubcommand: VersionsListCommand.self
    )
}
