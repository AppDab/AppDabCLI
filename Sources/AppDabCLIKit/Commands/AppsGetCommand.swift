import AppDabAutomation
import AppDabServices
import ArgumentParser

struct AppsGetCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(
        commandName: "get",
        abstract: AutomationActionCatalog.descriptor(for: .getApp)?.description ?? "Fetch an app.",
    )

    @Option(name: .customLong("account-id"), help: "The AppDab account identifier.")
    var accountID: String

    @Option(name: .customLong("app-id"), help: "The App Store Connect app identifier.")
    var appID: String

    @OptionGroup var output: OutputOptions

    var invocation: CLIInvocation {
        .read(
            GetAppAction.self,
            input: .init(accountID: accountID, appID: appID),
            format: output.format,
            verbose: output.verbose,
            render: { app, style in AppTextRenderer().render(app, style: style) },
        )
    }
}
