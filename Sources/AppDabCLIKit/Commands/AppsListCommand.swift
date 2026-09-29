import AppDabAutomation
import AppDabServices
import ArgumentParser

struct AppsListCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: AutomationActionCatalog.descriptor(for: .listApps)?.description ?? "List apps for an account."
    )

    @Option(name: .customLong("account-id"), help: "The AppDab account identifier.")
    var accountID: String

    @Option(help: "Opaque pagination token returned by a previous list response.")
    var cursor: String?

    @Option(help: "Maximum apps to return, from 1 through 200.")
    var limit: Int?

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
        let accountID = accountID
        let cursor = cursor
        let limit = limit
        return .read(
            ListAppsAction.self,
            input: .init(accountID: accountID, pagination: .init(cursor: cursor, limit: limit)),
            format: output.format,
            verbose: output.verbose,
            render: { apps, style in AppsTextRenderer().render(apps, style: style) },
            pagination: { $0.pagination }
        )
    }
}
