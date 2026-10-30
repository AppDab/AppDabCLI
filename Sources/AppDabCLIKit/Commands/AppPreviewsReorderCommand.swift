import AppDabAutomation
import ArgumentParser

struct AppPreviewsReorderCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(commandName: "reorder", abstract: ReorderAppPreviewsAction.descriptor.description)

    @OptionGroup var scope: VersionMediaOptions
    @Option(name: .customLong("placement-group"), help: "Apple placement group to reorder.")
    var placementGroup: String

    @Option(name: .customLong("placement-ids"), parsing: .upToNextOption, help: "All placement IDs in the group, in their desired order.")
    var placementIDs: [String] = []

    @OptionGroup var output: OutputOptions
    @OptionGroup var execution: ExecutionOptions

    private var typedInput: ReorderAppPreviewsInput {
        .init(accountID: scope.accountID, versionID: scope.versionID, locale: scope.locale, placementGroup: placementGroup, placementIDs: placementIDs)
    }

    mutating func validate() throws {
        try typedInput.validate()
    }

    var invocation: CLIInvocation {
        .write(
            ReorderAppPreviewsAction.self,
            input: typedInput,
            format: output.format, verbose: output.verbose,
            executionContext: execution.context, operationDescription: "reorder app previews",
            render: { media, style in VersionMediaTextRenderer().render(media, style: style) },
        )
    }
}
