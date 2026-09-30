import AppDabAutomation
import AppDabServices
import ArgumentParser
import Foundation

struct BetaGroupsUpdateCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(
        commandName: "update",
        abstract: AutomationActionCatalog.descriptor(for: .updateBetaGroup)?.description ?? "Update a beta group."
    )

    @Option(name: .customLong("account-id"), help: "The AppDab account identifier.")
    var accountID: String

    @Option(name: .customLong("beta-group-id"), help: "The beta group identifier.")
    var betaGroupID: String

    @Option(help: "A new beta group name.")
    var name: String?

    @Option(name: .customLong("feedback-enabled"), help: "Enable or disable tester feedback: true or false.")
    var feedbackEnabled: Bool?

    @Option(name: .customLong("ios-builds-available-for-apple-silicon-mac"), help: "Allow iOS builds on Apple silicon Mac: true or false.")
    var iosBuildsAvailableForAppleSiliconMac: Bool?

    @Option(name: .customLong("ios-builds-available-for-apple-vision"), help: "Allow iOS builds on Apple Vision: true or false.")
    var iosBuildsAvailableForAppleVision: Bool?

    @Option(name: .customLong("public-link-enabled"), help: "Enable or disable the public link: true or false.")
    var publicLinkEnabled: Bool?

    @Option(name: .customLong("public-link-limit"), help: "A positive tester limit for the public link.")
    var publicLinkLimit: Int?

    @Option(name: .customLong("public-link-limit-enabled"), help: "Enable or disable the public link limit: true or false.")
    var publicLinkLimitEnabled: Bool?

    @OptionGroup var output: OutputOptions
    @OptionGroup var execution: ExecutionOptions

    private var changes: BetaGroupChanges {
        .init(name: name?.trimmingCharacters(in: .whitespacesAndNewlines),
              feedbackEnabled: feedbackEnabled,
              iosBuildsAvailableForAppleSiliconMac: iosBuildsAvailableForAppleSiliconMac,
              iosBuildsAvailableForAppleVision: iosBuildsAvailableForAppleVision,
              publicLinkEnabled: publicLinkEnabled,
              publicLinkLimit: publicLinkLimit,
              publicLinkLimitEnabled: publicLinkLimitEnabled)
    }

    mutating func validate() throws {
        if changes.isEmpty {
            throw ValidationError("Provide at least one beta group field to update.")
        }
        if name != nil, changes.name?.isEmpty == true {
            throw ValidationError("The value for '--name' must be nonempty.")
        }
        if let publicLinkLimit, publicLinkLimit <= 0 {
            throw ValidationError("The value for '--public-link-limit' must be positive.")
        }
    }

    var invocation: CLIInvocation {
        let accountID = accountID
        let betaGroupID = betaGroupID
        let changes = changes
        return .write(
            UpdateBetaGroupAction.self,
            input: .init(accountID: accountID, betaGroupID: betaGroupID, changes: changes),
            format: output.format, verbose: output.verbose,
            executionContext: execution.context,
            operationDescription: "update beta group \(betaGroupID)",
            render: { group, style in BetaGroupTextRenderer().render(group, style: style) }
        )
    }
}
