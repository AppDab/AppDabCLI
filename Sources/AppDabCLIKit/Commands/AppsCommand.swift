import ArgumentParser

struct AppsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "apps",
        abstract: "List or inspect App Store Connect apps.",
        subcommands: [
            AppsListCommand.self,
            AppsGetCommand.self,
        ],
        defaultSubcommand: AppsListCommand.self,
    )
}
