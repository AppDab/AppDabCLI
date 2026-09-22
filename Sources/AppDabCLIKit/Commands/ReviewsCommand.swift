import ArgumentParser

struct ReviewsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "reviews",
        abstract: "Read customer reviews for an app.",
        subcommands: [ReviewsListCommand.self],
        defaultSubcommand: ReviewsListCommand.self
    )
}
