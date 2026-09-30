import AppDabAutomation
import ArgumentParser

struct BetaGroupsAddBuildCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(commandName: "addBuild", abstract: "Add a build to a beta group.")

    @OptionGroup var options: BetaGroupBuildOptions

    var invocation: CLIInvocation {
        .write(
            AddBuildToBetaGroupAction.self,
            input: .init(accountID: options.accountID, betaGroupID: options.betaGroupID, buildID: options.buildID),
            format: options.output.format, verbose: options.output.verbose,
            executionContext: options.execution.context,
            operationDescription: "add build \(options.buildID) to beta group \(options.betaGroupID)",
            render: { membership, style in BetaGroupBuildTextRenderer().render(membership, style: style) },
        )
    }
}
