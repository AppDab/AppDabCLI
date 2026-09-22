import AppDabAutomation
import Foundation

struct MutationPlanTextRenderer {
    func render(_ plan: AutomationMutationPlan, commitCommand: String, style: TextStyle) -> String {
        [
            style.heading("Preview"),
            plan.redactedSummary,
            TextDetails(rows: [
                ("Confirmation fingerprint", plan.confirmationFingerprint),
                ("Expires", plan.expiresAt.formatted(.iso8601)),
            ]).render(style: style),
            "No changes have been made.",
            "Commit command:\n\(commitCommand)",
        ].joined(separator: "\n\n")
    }
}
