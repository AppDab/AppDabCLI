import AppDabAutomation
import Foundation

struct CLIErrorPresentation: Sendable {
    let code: String
    let message: String
    let title: String
    let guidance: String
    let diagnostic: String
    let recoveryCommand: String?

    init(error: Error, invocation: CLIInvocation) {
        let automationPresentation = AutomationErrorPresentation.present(error)
        code = automationPresentation.code
        message = automationPresentation.message
        diagnostic = automationPresentation.message
        title = "Could not \(Self.operationDescription(for: invocation))."

        switch error {
        case let actionError as AutomationActionError:
            guidance = Self.guidance(for: actionError)
            recoveryCommand = nil
        case let executionError as AutomationExecutionError:
            guidance = Self.guidance(for: executionError)
            recoveryCommand = Self.requiresReconciliation(executionError)
                ? Self.recoveryCommand(from: invocation.originalArguments)
                : nil
        default:
            guidance = "App Store Connect could not complete the request. Try again later. Use --format json or --verbose for diagnostics."
            recoveryCommand = nil
        }
    }

    private static func operationDescription(for invocation: CLIInvocation) -> String {
        let actionID = invocation.actionID
        if invocation.executionContext.mode == .reconcile {
            return "reconcile the previous write"
        }
        if let operationDescription = invocation.operationDescription {
            return operationDescription
        }
        if actionID == .listAccounts {
            return "list accounts"
        }
        if actionID == .listApps {
            return "list apps"
        }
        if actionID == .getApp {
            return "get the app"
        }
        if actionID == .listCustomerReviews {
            return "list customer reviews"
        }
        return "complete \(actionID.rawValue.replacingOccurrences(of: "_", with: " "))"
    }

    private static func guidance(for error: AutomationActionError) -> String {
        switch error {
        case .network:
            "App Store Connect could not be reached. Check your Internet connection and try again."
        case .authentication:
            "Sign in again or check your App Store Connect credentials."
        case .permissionDenied:
            "This App Store Connect account does not have access to perform this action."
        case .invalidArguments, .invalidLimit, .accountNotFound, .appNotFound:
            error.errorDescription ?? "Check the supplied arguments and try again."
        case .upstream:
            "App Store Connect could not complete the request. Try again later. Use --format json or --verbose for diagnostics."
        }
    }

    private static func guidance(for error: AutomationExecutionError) -> String {
        switch error {
        case .previewNotFound, .previewExpired, .inputChanged, .actionChanged, .preconditionFailed:
            let message = error.errorDescription ?? "The preview is no longer valid."
            return message.localizedCaseInsensitiveContains("create a new preview")
                ? message
                : "\(message) Create a new preview before trying again."
        case .indeterminate, .commitBlocked(.indeterminate), .reconciliationUnresolved:
            return "The write may have succeeded. Reconcile the remote state before retrying."
        default:
            return error.errorDescription ?? "Check the command and try again."
        }
    }

    private static func requiresReconciliation(_ error: AutomationExecutionError) -> Bool {
        switch error {
        case .indeterminate, .commitBlocked(.indeterminate), .reconciliationUnresolved:
            true
        default:
            false
        }
    }

    private static func recoveryCommand(from arguments: [String]) -> String? {
        guard !arguments.isEmpty,
              containsOption("--confirm", in: arguments),
              containsOption("--idempotency-key", in: arguments)
        else {
            return nil
        }
        return CLICommandFormatter.render(arguments: arguments)
    }

    private static func containsOption(_ option: String, in arguments: [String]) -> Bool {
        arguments.contains(option) || arguments.contains(where: { $0.hasPrefix("\(option)=") })
    }
}
