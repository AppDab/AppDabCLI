import AppDabAutomation
import ArgumentParser

struct BetaGroupsRemoveBuildCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(commandName: "removeBuild", abstract: "Remove a build from a beta group.")

    @OptionGroup var options: BetaGroupBuildOptions

    var invocation: CLIInvocation {
        .write(
            RemoveBuildFromBetaGroupAction.self,
            input: .init(accountID: options.accountID, betaGroupID: options.betaGroupID, buildID: options.buildID),
            format: options.output.format, verbose: options.output.verbose,
            executionContext: options.execution.context,
            operationDescription: "remove build \(options.buildID) from beta group \(options.betaGroupID)",
            render: { membership, style in BetaGroupBuildTextRenderer().render(membership, style: style) },
        )
    }
}
