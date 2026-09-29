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
