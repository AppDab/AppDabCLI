import AppDabAutomation
import AppDabServices
import ArgumentParser

struct AccountsVerifyCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(
        commandName: "verify",
        abstract: "Verify a configured App Store Connect API key."
    )

    @Option(name: .customLong("account-id"), help: "The AppDab account identifier to verify.")
    var accountID: String

    @OptionGroup var output: OutputOptions

    mutating func validate() throws {
        guard !accountID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError("'--account-id' must be a nonempty string.")
        }
    }

    var invocation: CLIInvocation {
        .init(
            actionID: .verifyAccount,
            arguments: ["accountID": .string(accountID.trimmingCharacters(in: .whitespacesAndNewlines))],
            format: output.format,
            verbose: output.verbose
        )
    }
}
