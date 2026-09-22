import ArgumentParser

struct AppsVersionsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "versions",
        abstract: "Create an App Store Connect version.",
        subcommands: [AppsVersionsCreateCommand.self]
    )
}
