import AppDabAutomation
import ArgumentParser

struct AppVersionCreateCommand: TypedAutomationCLICommand {
    static let actionID: AutomationActionID = .createAppVersion
    static let actionPath = ["appVersion", "create"]
    static let configuration = CommandConfiguration(
        commandName: "create",
        abstract: AutomationActionCatalog.descriptor(for: .createAppVersion)?.description
            ?? "Create an App Store Connect version."
    )

    @Option(name: .customLong("account-id"), help: "The AppDab account identifier.")
    var accountID: String

    @Option(name: .customLong("app-id"), help: "The App Store Connect app identifier.")
    var appID: String

    @Option(help: "The app platform: iOS, macOS, tvOS, or visionOS.")
    var platform: PlatformArgument

    @Option(help: "The new version string.")
    var version: String

    @OptionGroup var output: OutputOptions

    @OptionGroup var execution: ExecutionOptions

    var invocation: CLIInvocation {
        let accountID = accountID
        let appID = appID
        let platform = platform.value
        let version = version
        return .write(
            CreateAppVersionAction.self,
            input: .init(accountID: accountID, appID: appID, platform: platform, version: version),
            format: output.format,
            verbose: output.verbose,
            executionContext: execution.context,
            operationDescription: "create version \(version) for \(platform.prettyName)",
            render: { version, style in VersionTextRenderer().render(version, style: style) }
        )
    }
}
