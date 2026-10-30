import AppDabAutomation
import ArgumentParser

struct ScreenshotsUploadCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(commandName: "upload", abstract: UploadScreenshotAction.descriptor.description)

    @OptionGroup var scope: VersionMediaOptions
    @Option(name: .customLong("file"), help: "Local media file to upload.")
    var filePath: String

    @Option(name: .customLong("placement-group"), help: "Apple placement group. Use list --requirements to see valid groups.")
    var placementGroup: String

    @Flag(name: .customLong("wait"), help: "Wait for Apple to process the uploaded media.")
    var wait: Bool = false

    @Option(name: .customLong("timeout"), help: "Processing timeout in seconds, from 1 to 3600.")
    var timeout: Int = 300

    @OptionGroup var output: OutputOptions
    @OptionGroup var execution: ExecutionOptions

    private var typedInput: UploadScreenshotInput {
        .init(accountID: scope.accountID, versionID: scope.versionID, locale: scope.locale, filePath: filePath, placementGroup: placementGroup, wait: wait, timeout: timeout)
    }

    mutating func validate() throws {
        try typedInput.validate()
    }

    var invocation: CLIInvocation {
        .write(
            UploadScreenshotAction.self,
            input: typedInput,
            format: output.format, verbose: output.verbose,
            executionContext: execution.context, operationDescription: "upload screenshots",
            render: { media, style in VersionMediaTextRenderer().render(media, style: style) },
        )
    }
}
