import AppDabServices

struct AccountRemovalTextRenderer {
    func render(_ account: AccountSummary, style _: TextStyle) -> String {
        "Removed API key \(account.name).\n\nAccount ID: \(account.accountID)"
    }
}
