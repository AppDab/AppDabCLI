import AppDabAutomation
import ArgumentParser

struct AppPreviewsGetCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(commandName: "get", abstract: GetAppPreviewAction.descriptor.description)

    @OptionGroup var scope: VersionMediaOptions
    @Option(name: .customLong("placement-id"), help: "Version placement identifier.")
    var placementID: String

    @OptionGroup var output: OutputOptions

    private var typedInput: GetAppPreviewInput {
        .init(accountID: scope.accountID, versionID: scope.versionID, locale: scope.locale, placementID: placementID)
    }

    mutating func validate() throws {
        try typedInput.validate()
    }

    var invocation: CLIInvocation {
        .read(
            GetAppPreviewAction.self,
            input: typedInput,
            format: output.format, verbose: output.verbose,
            render: { media, style in VersionMediaTextRenderer().render(media, style: style) },
        )
    }
}
