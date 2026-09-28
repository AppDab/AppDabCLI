import AppDabServices

struct AccountAdditionTextRenderer {
    func render(_ addition: AccountAddition, style: TextStyle) -> String {
        var output = "Added API key \(addition.account.name).\n\nAccount ID: \(addition.account.accountID)"
        if let issue = addition.issue {
            output += "\n\nWarning: \(issue.message)"
            if let resolutionURL = issue.resolutionURL {
                output += "\n\(resolutionURL.absoluteString)"
            }
        }
        return output
    }
}
