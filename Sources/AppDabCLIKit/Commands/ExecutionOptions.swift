import AppDabAutomation
import ArgumentParser

struct ExecutionOptions: ParsableArguments {
    @Option(
        name: .customLong("confirm"),
        help: "Commit the exact preview identified by this confirmation fingerprint.",
    )
    var confirmationFingerprint: String?

    @Option(
        name: .customLong("idempotency-key"),
        help: "Use a unique key that makes a committed write safe to retry.",
    )
    var idempotencyKey: String?

    @Flag(help: "Reconcile an indeterminate write instead of retrying it.")
    var reconcile = false

    @Flag(help: "Show a write preview without asking for confirmation.")
    var preview = false

    mutating func validate() throws {
        guard (confirmationFingerprint == nil) == (idempotencyKey == nil) else {
            throw ValidationError("Both '--confirm' and '--idempotency-key' are required together.")
        }
        if reconcile, confirmationFingerprint == nil {
            throw ValidationError("'--reconcile' requires '--confirm' and '--idempotency-key'.")
        }
        if preview, confirmationFingerprint != nil || reconcile {
            throw ValidationError("'--preview' cannot be combined with '--confirm', '--idempotency-key', or '--reconcile'.")
        }
    }

    var context: AutomationExecutionContext {
        let mode: AutomationExecutionMode = if preview {
            .preview
        } else if reconcile {
            .reconcile
        } else if confirmationFingerprint != nil {
            .commit
        } else {
            .execute
        }
        return .init(
            mode: mode,
            confirmationFingerprint: confirmationFingerprint,
            idempotencyKey: idempotencyKey,
        )
    }
}
