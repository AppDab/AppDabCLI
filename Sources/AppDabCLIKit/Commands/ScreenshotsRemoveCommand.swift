import AppDabAutomation
import ArgumentParser

struct ScreenshotsRemoveCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(commandName: "remove", abstract: RemoveScreenshotAction.descriptor.description)

    @OptionGroup var scope: VersionMediaOptions
    @Option(name: .customLong("placement-id"), help: "Version placement identifier.")
    var placementID: String

    @OptionGroup var output: OutputOptions
    @OptionGroup var execution: ExecutionOptions

    private var typedInput: RemoveScreenshotInput {
        .init(accountID: scope.accountID, versionID: scope.versionID, locale: scope.locale, placementID: placementID)
    }

    mutating func validate() throws {
        try typedInput.validate()
    }

    var invocation: CLIInvocation {
        .write(
            RemoveScreenshotAction.self,
            input: typedInput,
            format: output.format, verbose: output.verbose,
            executionContext: execution.context, operationDescription: "remove screenshots",
            render: { media, _ in RemoveScreenshotAction().summary(for: media) },
        )
    }
}
