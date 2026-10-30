import AppDabAutomation
import ArgumentParser

struct AppPreviewsRemoveCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(commandName: "remove", abstract: RemoveAppPreviewAction.descriptor.description)

    @OptionGroup var scope: VersionMediaOptions
    @Option(name: .customLong("placement-id"), help: "Version placement identifier.")
    var placementID: String

    @OptionGroup var output: OutputOptions
    @OptionGroup var execution: ExecutionOptions

    private var typedInput: RemoveAppPreviewInput {
        .init(accountID: scope.accountID, versionID: scope.versionID, locale: scope.locale, placementID: placementID)
    }

    mutating func validate() throws {
        try typedInput.validate()
    }

    var invocation: CLIInvocation {
        .write(
            RemoveAppPreviewAction.self,
            input: typedInput,
            format: output.format, verbose: output.verbose,
            executionContext: execution.context, operationDescription: "remove app previews",
            render: { media, _ in RemoveAppPreviewAction().summary(for: media) },
        )
    }
}
