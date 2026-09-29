import AppDabAutomation
import ArgumentParser

struct ReviewsGetCommand: TypedAutomationCLICommand {
    static let actionID: AutomationActionID = .getCustomerReview
    static let actionPath = ["reviews", "get"]
    static let configuration = CommandConfiguration(
        commandName: "get",
        abstract: AutomationActionCatalog.descriptor(for: .getCustomerReview)?.description
            ?? "Fetch a customer review."
    )

    @Option(name: .customLong("account-id"), help: "The AppDab account identifier.")
    var accountID: String

    @Option(name: .customLong("review-id"), help: "The App Store Connect review identifier.")
    var reviewID: String

    @OptionGroup var output: OutputOptions

    var invocation: CLIInvocation {
        .read(
            GetCustomerReviewAction.self,
            input: .init(accountID: accountID, reviewID: reviewID),
            format: output.format,
            verbose: output.verbose,
            render: { review, style in CustomerReviewsTextRenderer().render(review, style: style) }
        )
    }
}
