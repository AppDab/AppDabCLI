import AppDabAutomation
import ArgumentParser
import Foundation

struct BetaGroupsCreateCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(
        commandName: "create",
        abstract: AutomationActionCatalog.descriptor(for: .createBetaGroup)?.description ?? "Create a beta group."
    )

    @Option(name: .customLong("account-id"), help: "The AppDab account identifier.")
    var accountID: String

    @Option(name: .customLong("app-id"), help: "The App Store Connect app identifier.")
    var appID: String

    @Option(help: "The beta group name.")
    var name: String

    @Flag(name: .customLong("internal"), help: "Create an internal group. The default is external.")
    var isInternalGroup = false

    @Option(name: .customLong("access-to-all-builds"), help: "For an internal group, true or false. Defaults to true.")
    var hasAccessToAllBuilds: Bool?

    @OptionGroup var output: OutputOptions
    @OptionGroup var execution: ExecutionOptions

    mutating func validate() throws {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ValidationError("The value for '--name' must be nonempty.")
        }
        if !isInternalGroup, hasAccessToAllBuilds != nil {
            throw ValidationError("'--access-to-all-builds' requires '--internal'.")
        }
    }

    var invocation: CLIInvocation {
        let accountID = accountID
        let appID = appID
        let name = name
        let isInternalGroup = isInternalGroup
        let hasAccessToAllBuilds = hasAccessToAllBuilds
        return .write(
            CreateBetaGroupAction.self,
            input: .init(accountID: accountID, appID: appID, name: name, isInternalGroup: isInternalGroup, hasAccessToAllBuilds: hasAccessToAllBuilds),
            format: output.format, verbose: output.verbose,
            executionContext: execution.context,
            operationDescription: "create beta group \(name) for app \(appID)",
            render: { group, style in BetaGroupTextRenderer().render(group, style: style) }
        )
    }
}
