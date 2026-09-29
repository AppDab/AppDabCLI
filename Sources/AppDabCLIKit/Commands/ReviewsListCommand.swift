import AppDabAutomation
import AppDabServices
import ArgumentParser

struct ReviewsListCommand: TypedAutomationCLICommand {
    static let actionID: AutomationActionID = .listCustomerReviews
    static let actionPath = ["reviews", "list"]
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: AutomationActionCatalog.descriptor(for: .listCustomerReviews)?.description ?? "List customer reviews."
    )

    @Option(name: .customLong("account-id"), help: "The AppDab account identifier.")
    var accountID: String

    @Option(name: .customLong("app-id"), help: "The App Store Connect app identifier.")
    var appID: String

    @Option(help: "Maximum number of reviews to return, from 1 through 200.")
    var limit: Int?

    @Option(help: "Opaque pagination token returned by a previous list response.")
    var cursor: String?

    @OptionGroup var output: OutputOptions

    mutating func validate() throws {
        if let limit, !(1 ... PaginationRequest.maximumLimit).contains(limit) {
            throw ValidationError("The value for '--limit' must be from 1 through 200.")
        }
        if cursor != nil, limit == nil {
            throw ValidationError("The value for '--limit' is required when '--cursor' is provided.")
        }
        if cursor?.isEmpty == true {
            throw ValidationError("The value for '--cursor' must be a nonempty pagination token.")
        }
    }

    var invocation: CLIInvocation {
        return .read(
            ListCustomerReviewsAction.self,
            input: .init(accountID: accountID, appID: appID, pagination: .init(cursor: cursor, limit: limit)),
            format: output.format,
            verbose: output.verbose,
            render: { reviews, style in CustomerReviewsTextRenderer().render(reviews, style: style) },
            pagination: { $0.pagination }
        )
    }
}
