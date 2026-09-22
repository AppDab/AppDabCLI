import AppDabAutomation
import AppDabServices

struct AccountVerificationTextRenderer: TextRenderer {
    let actionID = AutomationActionID.verifyAccount

    func render(_ content: JSONValue, style: TextStyle) throws -> String {
        let payload = try TextDecoder.decode(Payload.self, from: content)
        var output = "API key \(payload.account.name) is valid.\n\nAccount ID: \(payload.account.accountID)"
        if let issue = payload.issue {
            output += "\n\nWarning: \(issue.message)"
            if let resolutionURL = issue.resolutionURL {
                output += "\n\(resolutionURL.absoluteString)"
            }
        }
        return output
    }

    private struct Payload: Decodable {
        let account: AccountSummary
        let issue: AccountVerificationIssue?
    }
}
