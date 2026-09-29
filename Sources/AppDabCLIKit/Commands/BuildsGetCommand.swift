import AppDabAutomation
import ArgumentParser

struct BuildsGetCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(
        commandName: "get",
        abstract: AutomationActionCatalog.descriptor(for: .getBuild)?.description ?? "Fetch a build."
    )

    @Option(name: .customLong("account-id"), help: "The AppDab account identifier.")
    var accountID: String

    @Option(name: .customLong("build-id"), help: "The App Store Connect build identifier.")
    var buildID: String

    @OptionGroup var output: OutputOptions

    var invocation: CLIInvocation {
        .read(
            GetBuildAction.self,
            input: .init(accountID: accountID, buildID: buildID),
            format: output.format,
            verbose: output.verbose,
            render: { build, style in BuildTextRenderer().render(build, style: style) }
        )
    }
}
