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

    private var typedInput: DownloadScreenshotInput {
        .init(accountID: scope.accountID, versionID: scope.versionID, locale: scope.locale, placementID: placementID, destinationPath: destinationPath)
    }

    mutating func validate() throws {
        try typedInput.validate()
    }

    var invocation: CLIInvocation {
        .directWrite(
            DownloadScreenshotAction.self,
            input: typedInput,
            format: output.format, verbose: output.verbose,
            render: { media, style in VersionMediaTextRenderer().render(media, style: style) },
        )
    }
}
