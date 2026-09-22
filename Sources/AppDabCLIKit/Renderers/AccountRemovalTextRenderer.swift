import AppDabAutomation
import AppDabServices

struct AccountRemovalTextRenderer: TextRenderer {
    let actionID = AutomationActionID.removeAccount

    func render(_ content: JSONValue, style: TextStyle) throws -> String {
        let account = try TextDecoder.decode(Payload.self, from: content).account
        return "Removed API key \(account.name).\n\nAccount ID: \(account.accountID)"
    }

    private struct Payload: Decodable {
        let account: AccountSummary
    }
}
