import AppDabAutomation
import AppDabServices

struct AccountsTextRenderer: TextRenderer {
    let actionID = AutomationActionID.listAccounts

    func render(_ content: JSONValue, style: TextStyle) throws -> String {
        let accounts = try TextDecoder.decode(Payload.self, from: content).accounts
        var sections = [style.heading("Accounts (\(accounts.count))")]
        if accounts.isEmpty {
            sections.append("No accounts found. Add an App Store Connect account in AppDab, then run this command again.")
        } else {
            sections.append(TextTable(
                headers: ["Name", "Account ID"],
                rows: accounts.map { [$0.name, $0.accountID] }
            ).render(style: style))
        }
        return sections.joined(separator: "\n\n")
    }

    private struct Payload: Decodable {
        let accounts: [AccountSummary]
    }
}
