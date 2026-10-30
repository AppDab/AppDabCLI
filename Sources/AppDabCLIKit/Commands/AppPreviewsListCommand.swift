import AppDabAutomation
import ArgumentParser

struct AppPreviewsListCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: ListAppPreviewsAction.descriptor.description)

    @OptionGroup var scope: VersionMediaOptions
    @Option(name: .customLong("placement-group"), help: "Apple placement group. Omit to list all groups.")
    var placementGroup: String?

    @Flag(name: .customLong("requirements"), help: "Include valid placement groups and media requirements in text output.")
    var showRequirements = false

    @OptionGroup var output: OutputOptions

    private var typedInput: ListAppPreviewsInput {
        .init(accountID: scope.accountID, versionID: scope.versionID, locale: scope.locale, placementGroup: placementGroup)
    }

    mutating func validate() throws {
        try typedInput.validate()
    }

    var invocation: CLIInvocation {
        .read(
            ListAppPreviewsAction.self,
            input: typedInput,
            format: output.format, verbose: output.verbose,
            render: { [showRequirements] media, style in VersionMediaTextRenderer().render(media, style: style, showRequirements: showRequirements) },
        )
    }
}
