import AppDabAutomation
import ArgumentParser

struct AccountsAddCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(
        commandName: "add",
        abstract: "Add and validate an App Store Connect API key.",
    )

    @Option(help: "The display name for this account.")
    var name: String

    @Option(name: .customLong("key-id"), help: "The App Store Connect API key identifier.")
    var keyID: String

    @Option(name: .customLong("issuer-id"), help: "The optional App Store Connect API issuer identifier.")
    var issuerID = ""

    @Option(name: .customLong("private-key-file"), help: "The path to a .p8 private key file.")
    var privateKeyFilePath: String

    @OptionGroup var output: OutputOptions

    mutating func validate() throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError("'--name' must be a nonempty string.")
        }
        guard !keyID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError("'--key-id' must be a nonempty string.")
        }
        guard !privateKeyFilePath.isEmpty else {
            throw ValidationError("'--private-key-file' must be a nonempty path.")
        }
        guard privateKeyFilePath != "-" else {
            throw ValidationError("'--private-key-file' must name a local file.")
        }
    }

    var invocation: CLIInvocation {
        .directWrite(
            AddAccountAction.self,
            input: .init(name: name, keyID: keyID, issuerID: issuerID, privateKeyFile: privateKeyFilePath),
            format: output.format,
            verbose: output.verbose,
            render: { addition, style in AccountAdditionTextRenderer().render(addition, style: style) },
        )
    }
}
