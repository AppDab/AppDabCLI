import AppDabAutomation
import ArgumentParser

struct BetaGroupBuildOptions: ParsableArguments {
    @Option(name: .customLong("account-id"), help: "The AppDab account identifier.")
    var accountID: String

    @Option(name: .customLong("beta-group-id"), help: "The beta group identifier.")
    var betaGroupID: String

    @Option(name: .customLong("build-id"), help: "The App Store Connect build identifier.")
    var buildID: String

    @OptionGroup var output: OutputOptions
    @OptionGroup var execution: ExecutionOptions
}
