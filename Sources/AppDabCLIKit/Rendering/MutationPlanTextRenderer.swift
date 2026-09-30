import AppDabAutomation
import Foundation

struct MutationPlanTextRenderer {
    func summary(for plan: AutomationMutationPlan) -> String {
        guard plan.actionID == .updateBetaBuildLocalization,
              let locale = plan.remotePreconditions["localization"]?.objectValue?["locale"]?.stringValue,
              !locale.isEmpty
        else {
            return plan.redactedSummary
        }
        let displayLocale = AppStoreConnectLocaleTextFormatter.format(locale)
        guard displayLocale != locale else { return plan.redactedSummary }
        return plan.redactedSummary.replacingOccurrences(of: locale, with: displayLocale)
    }

    func render(_ plan: AutomationMutationPlan, commitCommand: String, style: TextStyle) -> String {
        [
            style.heading("Preview"),
            summary(for: plan),
            TextDetails(rows: [
                ("Confirmation fingerprint", plan.confirmationFingerprint),
                ("Expires", plan.expiresAt.formatted(.iso8601)),
            ]).render(style: style),
            "No changes have been made.",
            "Commit command:\n\(commitCommand)",
        ].joined(separator: "\n\n")
    }
}
