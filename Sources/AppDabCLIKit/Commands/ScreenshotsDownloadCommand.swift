import AppDabAutomation
import ArgumentParser

struct ScreenshotsDownloadCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(commandName: "download", abstract: DownloadScreenshotAction.descriptor.description)

    @OptionGroup var scope: VersionMediaOptions
    @Option(name: .customLong("placement-id"), help: "Version placement identifier.")
    var placementID: String

    @Option(name: .customLong("destination"), help: "New destination file. Existing files are never overwritten.")
    var destinationPath: String

    @OptionGroup var output: OutputOptions
    @OptionGroup var execution: ExecutionOptions

    private var typedInput: DownloadScreenshotInput {
        .init(accountID: scope.accountID, versionID: scope.versionID, locale: scope.locale, placementID: placementID, destinationPath: destinationPath)
    }

    mutating func validate() throws {
        try typedInput.validate()
    }

    var invocation: CLIInvocation {
        .write(
            DownloadScreenshotAction.self,
            input: typedInput,
            format: output.format, verbose: output.verbose,
            executionContext: execution.context, operationDescription: "download screenshots",
            render: { media, style in VersionMediaTextRenderer().render(media, style: style) },
        )
    }
}
