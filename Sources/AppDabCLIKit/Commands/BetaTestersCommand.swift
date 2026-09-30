import AppDabAutomation
import AppDabServices
import ArgumentParser

struct BetaTestersCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "betaTesters",
        abstract: "List and invite TestFlight beta testers.",
        subcommands: [BetaTestersListCommand.self, BetaTestersInviteCommand.self, BetaTestersSendInvitationCommand.self],
        defaultSubcommand: BetaTestersListCommand.self,
    )
}

struct BetaTestersListCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List beta testers for an app, group, or build.")

    @Option(name: .customLong("account-id"), help: "The AppDab account identifier.") var accountID: String
    @Option(name: .customLong("app-id"), help: "List testers for this app.") var appID: String?
    @Option(name: .customLong("beta-group-id"), help: "List testers for this beta group.") var betaGroupID: String?
    @Option(name: .customLong("build-id"), help: "List testers for this build.") var buildID: String?
    @Option(help: "Opaque pagination token from the previous page.") var cursor: String?
    @Option(help: "Maximum testers to return, from 1 through 200.") var limit: Int?
    @OptionGroup var output: OutputOptions

    mutating func validate() throws {
        guard [appID, betaGroupID, buildID].compactMap(\.self).count == 1 else {
            throw ValidationError("Provide exactly one of '--app-id', '--beta-group-id', or '--build-id'.")
        }
        if let limit, !(1 ... PaginationRequest.maximumLimit).contains(limit) {
            throw ValidationError("The value for '--limit' must be from 1 through 200.")
        }
        if cursor != nil, limit == nil {
            throw ValidationError("The value for '--limit' is required when '--cursor' is provided.")
        }
    }

    var invocation: CLIInvocation {
        .read(
            ListBetaTestersAction.self,
            input: .init(accountID: accountID, appID: appID, betaGroupID: betaGroupID, buildID: buildID,
                         pagination: .init(cursor: cursor, limit: limit)),
            format: output.format, verbose: output.verbose,
            render: { list, _ in
                guard !list.testers.isEmpty else { return "No beta testers found." }
                return list.testers.map { "\($0.email)  \($0.betaTesterID)  \($0.state ?? "Unknown")" }.joined(separator: "\n")
            },
            pagination: { $0.pagination },
        )
    }
}

struct BetaTestersInviteCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(commandName: "invite", abstract: "Invite a beta tester to a group or build.")

    @Option(name: .customLong("account-id"), help: "The AppDab account identifier.") var accountID: String
    @Option(help: "The tester's email address.") var email: String
    @Option(name: .customLong("first-name")) var firstName: String?
    @Option(name: .customLong("last-name")) var lastName: String?
    @Option(name: .customLong("beta-group-id"), help: "Invite the tester to this beta group.") var betaGroupID: String?
    @Option(name: .customLong("build-id"), help: "Invite the tester to this build.") var buildID: String?
    @OptionGroup var output: OutputOptions
    @OptionGroup var execution: ExecutionOptions

    mutating func validate() throws {
        guard [betaGroupID, buildID].compactMap(\.self).count == 1 else {
            throw ValidationError("Provide exactly one of '--beta-group-id' or '--build-id'.")
        }
    }

    var invocation: CLIInvocation {
        .write(
            InviteBetaTesterAction.self,
            input: .init(accountID: accountID, email: email, firstName: firstName, lastName: lastName,
                         betaGroupID: betaGroupID, buildID: buildID),
            format: output.format, verbose: output.verbose, executionContext: execution.context,
            operationDescription: "invite beta tester \(email)",
            render: { tester, _ in "Invited \(tester.email).\nID: \(tester.betaTesterID)" },
        )
    }
}

struct BetaTestersSendInvitationCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(commandName: "sendInvitation", abstract: "Send an invitation to an existing beta tester.")

    @Option(name: .customLong("account-id"), help: "The AppDab account identifier.") var accountID: String
    @Option(name: .customLong("app-id"), help: "The App Store Connect app identifier.") var appID: String
    @Option(name: .customLong("tester-id"), help: "The beta tester identifier.") var testerID: String
    @OptionGroup var output: OutputOptions
    @OptionGroup var execution: ExecutionOptions

    var invocation: CLIInvocation {
        .write(
            SendBetaTesterInvitationAction.self,
            input: .init(accountID: accountID, appID: appID, testerID: testerID),
            format: output.format, verbose: output.verbose, executionContext: execution.context,
            operationDescription: "send invitation to beta tester \(testerID)",
            render: { tester, _ in "Sent invitation to \(tester.email).\nID: \(tester.betaTesterID)" },
        )
    }
}
