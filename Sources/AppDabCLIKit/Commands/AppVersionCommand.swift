import ArgumentParser

struct AppVersionCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "appVersion",
        abstract: "List, inspect, or create App Store Connect app versions.",
        subcommands: [
            AppVersionListCommand.self,
            AppVersionGetCommand.self,
            AppVersionCreateCommand.self
        ],
        defaultSubcommand: AppVersionListCommand.self
    )
}
