import AppDabAutomation
import ArgumentParser

struct AppVersionGetCommand: TypedAutomationCLICommand {
    static let actionID: AutomationActionID = .getAppVersion
    static let actionPath = ["appVersion", "get"]
    static let configuration = CommandConfiguration(
        commandName: "get",
        abstract: AutomationActionCatalog.descriptor(for: .getAppVersion)?.description
            ?? "Fetch an app version."
    )

    @Option(name: .customLong("account-id"), help: "The AppDab account identifier.")
    var accountID: String

    @Option(name: .customLong("app-id"), help: "The App Store Connect app identifier.")
    var appID: String

    @Option(name: .customLong("version-id"), help: "The App Store Connect version identifier.")
    var versionID: String

    @OptionGroup var output: OutputOptions

    var invocation: CLIInvocation {
        .read(
            GetAppVersionAction.self,
            input: .init(accountID: accountID, appID: appID, versionID: versionID),
            format: output.format,
            verbose: output.verbose,
            render: { version, style in VersionTextRenderer().render(version, title: "Version", style: style) }
        )
    }
}
