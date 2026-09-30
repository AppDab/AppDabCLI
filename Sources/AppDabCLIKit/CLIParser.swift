import AppDabAutomation
import AppDabServices
import ArgumentParser
import Foundation

public struct CLIParser: Sendable {
    public init() {}

    public func parse(_ arguments: [String]) throws -> CLIInvocation {
        guard !arguments.isEmpty else {
            throw CLIHelpRequest(RootCommand.helpMessage())
        }
        if arguments.last == "--help" || arguments.last == "-h" {
            throw CLIHelpRequest(helpMessage(for: Array(arguments.dropLast())))
        }
        if arguments.first == "help" {
            throw CLIHelpRequest(helpMessage(for: Array(arguments.dropFirst())))
        }

        do {
            let parsedCommand = try RootCommand.parseAsRoot(arguments)
            guard let command = parsedCommand as? any InvokingCommand else {
                throw CLIHelpRequest(RootCommand.helpMessage())
            }
            return command.invocation.withOriginalArguments(arguments)
        } catch let helpRequest as CLIHelpRequest {
            throw helpRequest
        } catch let cleanExit as CleanExit {
            throw CLIHelpRequest(RootCommand.fullMessage(for: cleanExit))
        } catch {
            throw CLIUsageError(RootCommand.fullMessage(for: error))
        }
    }

    private func helpMessage(for commandPath: [String]) -> String {
        switch commandPath {
        case ["accounts"]:
            RootCommand.helpMessage(for: AccountsCommand.self)
        case ["accounts", "list"]:
            RootCommand.helpMessage(for: AccountsListCommand.self)
        case ["accounts", "add"]:
            RootCommand.helpMessage(for: AccountsAddCommand.self)
        case ["accounts", "remove"]:
            RootCommand.helpMessage(for: AccountsRemoveCommand.self)
        case ["accounts", "verify"]:
            RootCommand.helpMessage(for: AccountsVerifyCommand.self)
        case ["apps"]:
            RootCommand.helpMessage(for: AppsCommand.self)
        case ["apps", "list"]:
            RootCommand.helpMessage(for: AppsListCommand.self)
        case ["apps", "get"]:
            RootCommand.helpMessage(for: AppsGetCommand.self)
        case ["appVersion"]:
            RootCommand.helpMessage(for: AppVersionCommand.self)
        case ["appVersion", "list"]:
            RootCommand.helpMessage(for: AppVersionListCommand.self)
        case ["appVersion", "get"]:
            RootCommand.helpMessage(for: AppVersionGetCommand.self)
        case ["appVersion", "create"]:
            RootCommand.helpMessage(for: AppVersionCreateCommand.self)
        case ["builds"]:
            RootCommand.helpMessage(for: BuildsCommand.self)
        case ["builds", "list"]:
            RootCommand.helpMessage(for: BuildsListCommand.self)
        case ["builds", "get"]:
            RootCommand.helpMessage(for: BuildsGetCommand.self)
        case ["builds", "addTester"]:
            RootCommand.helpMessage(for: BuildsAddTesterCommand.self)
        case ["builds", "removeTester"]:
            RootCommand.helpMessage(for: BuildsRemoveTesterCommand.self)
        case ["builds", "addBetaGroup"]:
            RootCommand.helpMessage(for: BuildsAddBetaGroupCommand.self)
        case ["builds", "removeBetaGroup"]:
            RootCommand.helpMessage(for: BuildsRemoveBetaGroupCommand.self)
        case ["builds", "submitForBetaReview"]:
            RootCommand.helpMessage(for: BuildsSubmitForBetaReviewCommand.self)
        case ["builds", "expire"]:
            RootCommand.helpMessage(for: BuildsExpireCommand.self)
        case ["betaGroups"]:
            RootCommand.helpMessage(for: BetaGroupsCommand.self)
        case ["betaGroups", "list"]:
            RootCommand.helpMessage(for: BetaGroupsListCommand.self)
        case ["betaGroups", "get"]:
            RootCommand.helpMessage(for: BetaGroupsGetCommand.self)
        case ["betaGroups", "create"]:
            RootCommand.helpMessage(for: BetaGroupsCreateCommand.self)
        case ["betaGroups", "update"]:
            RootCommand.helpMessage(for: BetaGroupsUpdateCommand.self)
        case ["betaGroups", "addBuild"]:
            RootCommand.helpMessage(for: BetaGroupsAddBuildCommand.self)
        case ["betaGroups", "removeBuild"]:
            RootCommand.helpMessage(for: BetaGroupsRemoveBuildCommand.self)
        case ["betaGroups", "addTester"]:
            RootCommand.helpMessage(for: BetaGroupsAddTesterCommand.self)
        case ["betaGroups", "removeTester"]:
            RootCommand.helpMessage(for: BetaGroupsRemoveTesterCommand.self)
        case ["betaTesters"]:
            RootCommand.helpMessage(for: BetaTestersCommand.self)
        case ["betaTesters", "list"]:
            RootCommand.helpMessage(for: BetaTestersListCommand.self)
        case ["betaTesters", "invite"]:
            RootCommand.helpMessage(for: BetaTestersInviteCommand.self)
        case ["betaTesters", "sendInvitation"]:
            RootCommand.helpMessage(for: BetaTestersSendInvitationCommand.self)
        case ["reviews"]:
            RootCommand.helpMessage(for: ReviewsCommand.self)
        case ["reviews", "list"]:
            RootCommand.helpMessage(for: ReviewsListCommand.self)
        case ["reviews", "get"]:
            RootCommand.helpMessage(for: ReviewsGetCommand.self)
        default:
            RootCommand.helpMessage()
        }
    }
}

extension CLIOutputFormat: ExpressibleByArgument {
    public static var allValueStrings: [String] {
        allCases.map(\.rawValue)
    }
}
