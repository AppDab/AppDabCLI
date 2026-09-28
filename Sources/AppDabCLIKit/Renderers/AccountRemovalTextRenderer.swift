import AppDabServices

struct AccountRemovalTextRenderer {
    func render(_ account: AccountSummary, style: TextStyle) -> String {
        return "Removed API key \(account.name).\n\nAccount ID: \(account.accountID)"
    }
}
