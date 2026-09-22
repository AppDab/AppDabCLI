import AppDabAutomation
import ArgumentParser

struct AppsVersionsCreateCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(
        commandName: "create",
        abstract: AutomationActionCatalog.descriptor(for: .createAppVersion)?.description
            ?? "Create an App Store Connect version."
    )

    @Option(name: .customLong("account-id"), help: "The AppDab account identifier.")
    var accountID: String

    @Option(name: .customLong("app-id"), help: "The App Store Connect app identifier.")
    var appID: String

    @Option(help: "The app platform: iOS, macOS, tvOS, or visionOS.")
    var platform: PlatformArgument

    @Option(help: "The new version string.")
    var version: String

    @OptionGroup var output: OutputOptions

    @OptionGroup var execution: ExecutionOptions

    var invocation: CLIInvocation {
        .init(
            actionID: .createAppVersion,
            arguments: [
                "account_id": .string(accountID),
                "app_id": .string(appID),
                "platform": .string(platform.value.rawValue),
                "version": .string(version),
            ],
            format: output.format,
            verbose: output.verbose,
            executionContext: execution.context
        )
    }
}
