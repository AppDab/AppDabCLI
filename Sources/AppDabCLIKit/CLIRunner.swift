import AppDabAutomation
import AppDabServices
import Foundation

public final class CLIRunner: Sendable {
    private let parser: CLIParser
    private let executor: Executor
    private let textRenderers: CLITextRendererRegistry
    private let outputCapabilities: CLIOutputCapabilities
    private let interaction: (any CLIInteraction)?
    private let makeIdempotencyKey: @Sendable () -> String

    public init(
        parser: CLIParser = .init(),
        executor: Executor,
        textRenderers: CLITextRendererRegistry = .init(),
        outputCapabilities: CLIOutputCapabilities = .plain,
        interaction: (any CLIInteraction)? = nil,
        makeIdempotencyKey: @escaping @Sendable () -> String = { UUID().uuidString.lowercased() }
    ) {
        self.parser = parser
        self.executor = executor
        self.textRenderers = textRenderers
        self.outputCapabilities = outputCapabilities
        self.interaction = interaction
        self.makeIdempotencyKey = makeIdempotencyKey
    }

    public func run(arguments: [String]) async -> CLIResult {
        let invocation: CLIInvocation
        do {
            invocation = try parser.parse(arguments)
        } catch let helpRequest as CLIHelpRequest {
            return .init(exitCode: 0, standardOutput: helpRequest.message)
        } catch let usageError as CLIUsageError {
            if format(from: arguments) == .json {
                return .init(exitCode: 2, standardError: Self.fallbackJSONError(
                    code: "invalid_arguments", message: usageError.message
                ))
            }
            return .init(exitCode: 2, standardError: usageError.message)
        } catch {
            return genericErrorResult(error, format: format(from: arguments))
        }

        do {
            let response = try await executor.execute(.init(
                actionID: invocation.actionID,
                arguments: invocation.arguments,
                surface: .cli,
                executionContext: invocation.executionContext
            ))
            if shouldConfirmInteractively(response: response, invocation: invocation) {
                return try await confirmInteractively(
                    preview: response,
                    invocation: invocation,
                    commandArguments: arguments
                )
            }
            return renderedResult(response, invocation: invocation)
        } catch {
            return errorResult(error, invocation: invocation)
        }
    }

    private func shouldConfirmInteractively(
        response: AutomationResponse,
        invocation: CLIInvocation
    ) -> Bool {
        response.plan != nil
            && invocation.format == .text
            && invocation.executionContext.mode == .execute
            && interaction?.isInteractive == true
    }

    private func confirmInteractively(
        preview: AutomationResponse,
        invocation: CLIInvocation,
        commandArguments: [String]
    ) async throws -> CLIResult {
        guard let plan = preview.plan, let interaction else {
            throw AutomationExecutionError.persistence("An interactive confirmation is missing its mutation plan.")
        }
        interaction.writeToStandardError("\(plan.redactedSummary)\n\n")
        guard promptForConfirmation(interaction) else {
            return .init(exitCode: 0, standardOutput: "Cancelled. No changes made.")
        }

        let idempotencyKey = makeIdempotencyKey()
        let recoveryCommand = makeRecoveryCommand(
            executablePath: interaction.executablePath,
            commandArguments: commandArguments,
            confirmationFingerprint: plan.confirmationFingerprint,
            idempotencyKey: idempotencyKey
        )
        interaction.writeToStandardError("""
        Recovery command, if the outcome is indeterminate:
        \(recoveryCommand)

        """)

        do {
            let committed = try await executor.execute(.init(
                actionID: invocation.actionID,
                arguments: invocation.arguments,
                surface: .cli,
                executionContext: .init(
                    mode: .commit,
                    confirmationFingerprint: plan.confirmationFingerprint,
                    idempotencyKey: idempotencyKey
                )
            ))
            return renderedResult(committed, invocation: invocation)
        } catch {
            if let executionError = error as? AutomationExecutionError,
               executionError == .indeterminate {
                interaction.writeToStandardError("The outcome is indeterminate. Run the recovery command above before retrying.\n")
            }
            throw error
        }
    }

    private func promptForConfirmation(_ interaction: any CLIInteraction) -> Bool {
        while true {
            interaction.writeToStandardError("Proceed? [y/N] ")
            guard let response = interaction.readLine() else {
                return false
            }
            switch response.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "y", "yes":
                return true
            case "", "n", "no":
                return false
            default:
                interaction.writeToStandardError("Please enter y or n.\n")
            }
        }
    }

    private func makeRecoveryCommand(
        executablePath: String,
        commandArguments: [String],
        confirmationFingerprint: String,
        idempotencyKey: String
    ) -> String {
        CLICommandFormatter.render(
            arguments: commandArguments + ["--confirm", confirmationFingerprint, "--idempotency-key", idempotencyKey],
            executable: executablePath
        )
    }

    private func renderedResult(_ response: AutomationResponse, invocation: CLIInvocation) -> CLIResult {
        do {
            return try .init(exitCode: 0, standardOutput: output(for: response, invocation: invocation))
        } catch {
            let message = response.plan != nil
                ? "The preview was created, but its output could not be displayed. No changes were made."
                : "The operation succeeded, but its output could not be displayed. Do not repeat the operation."
            if invocation.format == .json {
                return .init(exitCode: 1, standardError: Self.fallbackJSONError(code: "output_rendering_failed", message: message))
            }
            var text = message + "\n\n" + response.summary
            if invocation.verbose {
                text += "\n\nCode: output_rendering_failed\nDiagnostic: " + error.localizedDescription
            }
            return .init(exitCode: 1, standardError: text)
        }
    }

    private func output(
        for result: AutomationResponse,
        invocation: CLIInvocation
    ) throws -> String {
        switch invocation.format {
        case .json:
            return try JSONValueEncoding.string(from: result.envelope)
        case .text:
            if let plan = result.plan {
                let executable = interaction?.executablePath ?? "dab"
                let commitCommand = CLICommandFormatter.render(
                    arguments: invocation.originalArguments + [
                        "--confirm", plan.confirmationFingerprint,
                        "--idempotency-key", makeIdempotencyKey()
                    ],
                    executable: executable,
                    reconcile: false
                )
                return MutationPlanTextRenderer().render(
                    plan,
                    commitCommand: commitCommand,
                    style: .init(supportsColor: outputCapabilities.standardOutputSupportsColor)
                )
            }
            if result.data == .object([:]) {
                return result.summary
            }
            let rendered = try textRenderers.render(
                actionID: result.actionID,
                structuredContent: result.structuredContent,
                supportsColor: outputCapabilities.standardOutputSupportsColor,
                maximumWidth: outputCapabilities.standardOutputMaximumWidth
            )
            guard let continuationCommand = continuationCommand(for: result, invocation: invocation) else {
                return rendered
            }
            return "\(rendered)\n\nNext page command:\n\(continuationCommand)"
        }
    }

    private func continuationCommand(for result: AutomationResponse, invocation: CLIInvocation) -> String? {
        guard result.actionID == .listApps || result.actionID == .listCustomerReviews,
              let pagination = try? TextDecoder.decode(PaginationPayload.self, from: result.structuredContent).pagination,
              let cursor = pagination.nextCursor
        else {
            return nil
        }
        let arguments = continuationArguments(
            from: invocation.originalArguments,
            cursor: cursor,
            limit: pagination.limit
        )
        return CLICommandFormatter.render(
            arguments: arguments,
            executable: interaction?.executablePath ?? "dab",
            reconcile: false
        )
    }

    private func continuationArguments(from originalArguments: [String], cursor: String, limit: Int) -> [String] {
        var arguments: [String] = []
        var index = 0
        while index < originalArguments.count {
            let argument = originalArguments[index]
            let option = String(argument.prefix { $0 != "=" })
            if option == "--cursor" || option == "--limit" {
                index += argument.contains("=") ? 1 : 2
                continue
            }
            arguments.append(argument)
            index += 1
        }
        arguments += ["--cursor", cursor, "--limit", String(limit)]
        return arguments
    }

    private struct PaginationPayload: Decodable {
        let pagination: PaginationMetadata
    }

    private func errorResult(_ error: Error, invocation: CLIInvocation) -> CLIResult {
        let presentedError = CLIErrorPresentation(error: error, invocation: invocation)
        switch invocation.format {
        case .json:
            let value = JSONValue.object([
                "error": .object([
                    "code": .string(presentedError.code),
                    "message": .string(presentedError.message)
                ])
            ])
            let output = (try? JSONValueEncoding.string(from: value)) ?? Self.fallbackJSONError(code: presentedError.code, message: presentedError.message)
            return .init(exitCode: 1, standardError: output)
        case .text:
            var output = "\(styledErrorLabel(presentedError.title))\n\n\(presentedError.guidance)"
            if let recoveryCommand = presentedError.recoveryCommand {
                output += "\n\nRecovery command:\n\(recoveryCommand)"
            }
            if invocation.verbose {
                output += "\n\n\(styledErrorCodeLabel("Code:")) \(presentedError.code)\nDiagnostic: \(presentedError.diagnostic)"
            }
            return .init(
                exitCode: 1,
                standardError: output
            )
        }
    }

    private func genericErrorResult(_ error: Error, format: CLIOutputFormat) -> CLIResult {
        let presentedError = AutomationErrorPresentation.present(error)
        switch format {
        case .json:
            let value = JSONValue.object([
                "error": .object([
                    "code": .string(presentedError.code),
                    "message": .string(presentedError.message)
                ])
            ])
            let output = (try? JSONValueEncoding.string(from: value)) ?? Self.fallbackJSONError(code: presentedError.code, message: presentedError.message)
            return .init(exitCode: 1, standardError: output)
        case .text:
            return .init(
                exitCode: 1,
                standardError: "\(styledErrorLabel("Could not run the command."))\n\nCheck the command and try again."
            )
        }
    }

    private func format(from arguments: [String]) -> CLIOutputFormat {
        for (index, argument) in arguments.enumerated() {
            if argument == "--format", arguments.indices.contains(index + 1) {
                return CLIOutputFormat(rawValue: arguments[index + 1]) ?? .text
            }
            if argument.hasPrefix("--format=") {
                let value = String(argument.dropFirst("--format=".count))
                return CLIOutputFormat(rawValue: value) ?? .text
            }
        }
        return .text
    }

    private func styledErrorLabel(_ value: String) -> String {
        guard outputCapabilities.standardErrorSupportsColor else {
            return value
        }
        return "\u{001B}[1;31m\(value)\u{001B}[0m"
    }

    private func styledErrorCodeLabel(_ value: String) -> String {
        guard outputCapabilities.standardErrorSupportsColor else {
            return value
        }
        return "\u{001B}[2m\(value)\u{001B}[0m"
    }

    private static func fallbackJSONError(code: String, message: String) -> String {
        let object: [String: Any] = [
            "error": [
                "code": code,
                "message": message
            ]
        ]
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else {
            return #"{"error":{"code":"encoding_failed","message":"Failed to encode error."}}"#
        }
        return String(decoding: data, as: UTF8.self)
    }
}
