import ArgumentParser

struct BuildsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "builds",
        abstract: "Work with an app's builds.",
        subcommands: [BuildsListCommand.self],
        defaultSubcommand: BuildsListCommand.self
    )
}
