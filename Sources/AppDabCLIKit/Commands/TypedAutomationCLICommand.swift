import AppDabAutomation
import ArgumentParser

/// A first class CLI command backed by one typed automation action.
///
/// Keep the command's typed input construction and text renderer in its own
/// source file. Register the command here through `AutomationCLIActionCatalog`.
protocol TypedAutomationCLICommand: ParsableCommand, InvokingCommand {
    static var actionID: AutomationActionID { get }
    static var actionPath: [String] { get }
}

struct AutomationCLIAction: Equatable, Sendable {
    let id: AutomationActionID
    let path: [String]
    let commandType: String
}

enum AutomationCLIActionCatalog {
    /// Keep this list in the same order as `AutomationRegistry.standard`.
    static let all: [AutomationCLIAction] = [
        entry(AccountsListCommand.self),
        entry(AccountsAddCommand.self),
        entry(AccountsRemoveCommand.self),
        entry(AccountsVerifyCommand.self),
        entry(AppsListCommand.self),
        entry(AppsGetCommand.self),
        entry(AppVersionListCommand.self),
        entry(AppVersionGetCommand.self),
        entry(BuildsListCommand.self),
        entry(AppVersionCreateCommand.self),
        entry(ReviewsListCommand.self),
        entry(ReviewsGetCommand.self)
    ]

    static func entry<Command: TypedAutomationCLICommand>(
        _ command: Command.Type
    ) -> AutomationCLIAction {
        .init(
            id: command.actionID,
            path: command.actionPath,
            commandType: String(reflecting: command)
        )
    }
}
