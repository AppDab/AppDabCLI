import AppDabAutomation
import AppDabServices

public struct CLIInvocation: Sendable {
    public let actionID: AutomationActionID
    public let format: CLIOutputFormat
    public let verbose: Bool
    public let executionContext: AutomationExecutionContext
    public let originalArguments: [String]
    let typedExecution: @Sendable (Executor, AutomationExecutionContext) async throws -> CLITypedResult
    let operationDescription: String?

    private init(
        actionID: AutomationActionID,
        format: CLIOutputFormat = .text,
        verbose: Bool = false,
        executionContext: AutomationExecutionContext = .init(),
        originalArguments: [String] = [],
        typedExecution: @escaping @Sendable (Executor, AutomationExecutionContext) async throws -> CLITypedResult,
        operationDescription: String? = nil,
    ) {
        self.actionID = actionID
        self.format = format
        self.verbose = verbose
        self.executionContext = executionContext
        self.originalArguments = originalArguments
        self.typedExecution = typedExecution
        self.operationDescription = operationDescription
    }

    func withOriginalArguments(_ arguments: [String]) -> Self {
        .init(
            actionID: actionID,
            format: format,
            verbose: verbose,
            executionContext: executionContext,
            originalArguments: arguments,
            typedExecution: typedExecution,
            operationDescription: operationDescription,
        )
    }
}

struct CLITypedResult: Sendable {
    let response: AutomationResponse
    let render: (@Sendable (TextStyle) throws -> String)?
    let pagination: PaginationMetadata?
    let jsonResponse: (@Sendable () throws -> AutomationResponse)?

    init(
        response: AutomationResponse,
        render: (@Sendable (TextStyle) throws -> String)?,
        pagination: PaginationMetadata?,
        jsonResponse: (@Sendable () throws -> AutomationResponse)? = nil,
    ) {
        self.response = response
        self.render = render
        self.pagination = pagination
        self.jsonResponse = jsonResponse
    }
}

extension CLIInvocation {
    static func read<Action: AutomationAction>(
        _ actionType: Action.Type,
        input: Action.Input,
        format: CLIOutputFormat,
        verbose: Bool,
        render: @escaping @Sendable (Action.Output, TextStyle) throws -> String,
        pagination: @escaping @Sendable (Action.Output) -> PaginationMetadata? = { _ in nil },
    ) -> Self {
        .init(
            actionID: actionType.descriptor.id,
            format: format,
            verbose: verbose,
            typedExecution: { executor, _ in
                let output = try await executor.execute(actionType, input: input)
                let action = actionType.init()
                return .init(
                    response: .init(
                        actionID: actionType.descriptor.id,
                        summary: action.summary(for: output), data: .object([:]),
                    ),
                    render: { style in try render(output, style) },
                    pagination: pagination(output),
                    jsonResponse: {
                        try .init(
                            actionID: actionType.descriptor.id,
                            summary: action.summary(for: output),
                            data: action.data(for: output),
                        )
                    },
                )
            },
        )
    }

    static func write<Action: ReplayableGuardedAutomationAction>(
        _ actionType: Action.Type,
        input: Action.Input,
        format: CLIOutputFormat,
        verbose: Bool,
        executionContext: AutomationExecutionContext,
        operationDescription: String,
        render: @escaping @Sendable (Action.Output, TextStyle) throws -> String,
    ) -> Self {
        .init(
            actionID: actionType.descriptor.id,
            format: format,
            verbose: verbose,
            executionContext: executionContext,
            typedExecution: { executor, context in
                let result: AutomationTypedResult<Action.Output>
                switch context.mode {
                case .execute, .preview:
                    let plan = try await executor.preview(actionType, input: input)
                    result = .init(response: .init(
                        actionID: actionType.descriptor.id, summary: plan.redactedSummary,
                        data: .object([:]), plan: plan,
                    ), output: nil)
                case .commit:
                    result = try await executor.commitResult(
                        actionType, input: input,
                        confirmationFingerprint: context.confirmationFingerprint ?? "",
                        idempotencyKey: context.idempotencyKey ?? "",
                    )
                case .reconcile:
                    result = try await executor.reconcileResult(
                        actionType, input: input,
                        confirmationFingerprint: context.confirmationFingerprint ?? "",
                        idempotencyKey: context.idempotencyKey ?? "",
                    )
                }
                let rendered = result.output.map { output in
                    { @Sendable (style: TextStyle) in try render(output, style) }
                }
                return .init(response: result.response, render: rendered, pagination: nil)
            },
            operationDescription: operationDescription,
        )
    }

    static func directWrite<Action: AutomationAction>(
        _ actionType: Action.Type,
        input: Action.Input,
        format: CLIOutputFormat,
        verbose: Bool,
        render: @escaping @Sendable (Action.Output, TextStyle) throws -> String,
    ) -> Self {
        .init(
            actionID: actionType.descriptor.id,
            format: format,
            verbose: verbose,
            typedExecution: { executor, _ in
                let output = try await executor.execute(actionType, input: input)
                let action = actionType.init()
                return .init(
                    response: .init(
                        actionID: actionType.descriptor.id,
                        summary: action.summary(for: output),
                        data: .object([:]),
                    ),
                    render: { style in try render(output, style) },
                    pagination: nil,
                    jsonResponse: {
                        try .init(
                            actionID: actionType.descriptor.id,
                            summary: action.summary(for: output),
                            data: action.data(for: output),
                        )
                    },
                )
            },
        )
    }
}
