import AppDabAutomation
import AppDabServices

public struct CLIInvocation: Equatable, Sendable {
    public let actionID: AutomationActionID
    public let arguments: [String: JSONValue]
    public let format: CLIOutputFormat
    public let verbose: Bool
    public let executionContext: AutomationExecutionContext
    public let originalArguments: [String]

    public init(
        actionID: AutomationActionID,
        arguments: [String: JSONValue],
        format: CLIOutputFormat = .text,
        verbose: Bool = false,
        executionContext: AutomationExecutionContext = .init(),
        originalArguments: [String] = []
    ) {
        self.actionID = actionID
        self.arguments = arguments
        self.format = format
        self.verbose = verbose
        self.executionContext = executionContext
        self.originalArguments = originalArguments
    }

    func withOriginalArguments(_ arguments: [String]) -> Self {
        .init(
            actionID: actionID,
            arguments: self.arguments,
            format: format,
            verbose: verbose,
            executionContext: executionContext,
            originalArguments: arguments
        )
    }
}
