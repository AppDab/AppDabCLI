import AppDabServices

struct AccountsTextRenderer {
    func render(_ accounts: [AccountSummary], style: TextStyle) -> String {
        var sections = [style.heading("Accounts (\(accounts.count))")]
        if accounts.isEmpty {
            sections.append("No accounts found. Add one with `dab accounts add`, then run this command again.")
        } else {
            sections.append(TextTable(
                headers: ["Name", "Account ID"],
                rows: accounts.map { [$0.name, $0.accountID] }
            ).render(style: style))
        }
        return sections.joined(separator: "\n\n")
    }
}
