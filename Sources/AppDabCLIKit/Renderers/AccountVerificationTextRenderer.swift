import AppDabServices

struct AccountVerificationTextRenderer {
    func render(_ verification: AccountVerification, style: TextStyle) -> String {
        var output = "API key \(verification.account.name) is valid.\n\nAccount ID: \(verification.account.accountID)"
        if let issue = verification.issue {
            output += "\n\nWarning: \(issue.message)"
            if let resolutionURL = issue.resolutionURL {
                output += "\n\(resolutionURL.absoluteString)"
            }
        }
        return output
    }
}
