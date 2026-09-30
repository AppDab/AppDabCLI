import AppDabAutomation
import ArgumentParser

struct BetaBuildLocalizationsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "betaBuildLocalizations",
        abstract: "Work with localized TestFlight build details.",
        subcommands: [BetaBuildLocalizationsUpdateCommand.self],
    )
}

struct BetaBuildLocalizationsUpdateCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(
        commandName: "update",
        abstract: "Update the localized What to Test text for a build.",
    )

    @Option(name: .customLong("account-id"), help: "The AppDab account identifier.") var accountID: String
    @Option(name: .customLong("localization-id"), help: "The beta build localization identifier.") var localizationID: String
    @Option(name: .customLong("whats-new"), help: "The What to Test text, up to 4000 characters.") var whatsNew: String
    @OptionGroup var output: OutputOptions
    @OptionGroup var execution: ExecutionOptions

    mutating func validate() throws {
        if whatsNew.count > 4000 {
            throw ValidationError("'--whats-new' must be 4000 characters or fewer.")
        }
    }

    var invocation: CLIInvocation {
        .write(
            UpdateBetaBuildLocalizationAction.self,
            input: .init(accountID: accountID, localizationID: localizationID, whatsNew: whatsNew),
            format: output.format, verbose: output.verbose, executionContext: execution.context,
            operationDescription: "update beta build localization \(localizationID)",
            render: { localization, _ in
                "Updated What to Test for \(localization.locale).\nID: \(localization.localizationID)\n\(localization.whatsNew)"
            },
        )
    }
}
