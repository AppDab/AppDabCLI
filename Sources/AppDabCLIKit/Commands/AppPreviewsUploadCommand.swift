import AppDabAutomation
import ArgumentParser

struct AppPreviewsUploadCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(commandName: "upload", abstract: UploadAppPreviewAction.descriptor.description)

    @OptionGroup var scope: VersionMediaOptions
    @Option(name: .customLong("file"), help: "Local media file to upload.")
    var filePath: String

    @Option(name: .customLong("placement-group"), help: "Apple placement group. Use list --requirements to see valid groups.")
    var placementGroup: String

    @Option(name: .customLong("preview-frame-time-code"), help: "Preview frame in HH:MM:SS:FF format, for example 00:00:01:00.")
    var previewFrameTimeCode: String?

    @Flag(name: .customLong("wait"), help: "Wait for processing and availability of the preview download.")
    var wait: Bool = false

    @Option(name: .customLong("timeout"), help: "Processing timeout in seconds, from 1 to 3600.")
    var timeout: Int = 300

    @OptionGroup var output: OutputOptions
    @OptionGroup var execution: ExecutionOptions

    private var typedInput: UploadAppPreviewInput {
        .init(accountID: scope.accountID, versionID: scope.versionID, locale: scope.locale, filePath: filePath, placementGroup: placementGroup, previewFrameTimeCode: previewFrameTimeCode, wait: wait, timeout: timeout)
    }

    mutating func validate() throws {
        try typedInput.validate()
    }

    var invocation: CLIInvocation {
        .write(
            UploadAppPreviewAction.self,
            input: typedInput,
            format: output.format, verbose: output.verbose,
            executionContext: execution.context, operationDescription: "upload app previews",
            render: { media, style in VersionMediaTextRenderer().render(media, style: style) },
        )
    }
}
