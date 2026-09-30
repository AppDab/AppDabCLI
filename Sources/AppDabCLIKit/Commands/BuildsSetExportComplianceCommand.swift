import AppDabAutomation
import AppDabServices
import ArgumentParser

struct BuildsSetExportComplianceCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(
        commandName: "setExportCompliance",
        abstract: "Set a build's export compliance answers and upload a required document.",
    )

    @Option(name: .customLong("account-id"), help: "The AppDab account identifier.") var accountID: String
    @Option(name: .customLong("app-id"), help: "The App Store Connect app identifier.") var appID: String
    @Option(name: .customLong("build-id"), help: "The build identifier.") var buildID: String
    @Option(name: .customLong("needs-documents"), help: "Whether compliance documents are required: true or false.") var needsDocuments: Bool
    @Option(name: .customLong("available-on-french-store"), help: "Whether the app is available on the French App Store: true or false.") var availableOnFrenchStore: Bool
    @Option(name: .customLong("contains-proprietary-cryptography"), help: "Whether the app uses proprietary cryptography: true or false.") var containsProprietaryCryptography: Bool
    @Option(name: .customLong("contains-third-party-cryptography"), help: "Whether the app uses third party cryptography: true or false.") var containsThirdPartyCryptography: Bool
    @Option(help: "The cryptography purpose, up to 300 characters.") var purpose: String?
    @Option(name: .customLong("document-path"), help: "Path to a PDF or ZIP compliance document.") var documentPath: String?
    @OptionGroup var output: OutputOptions
    @OptionGroup var execution: ExecutionOptions

    mutating func validate() throws {
        if needsDocuments, purpose?.isEmpty != false || documentPath?.isEmpty != false {
            throw ValidationError("'--purpose' and '--document-path' are required when '--needs-documents' is true.")
        }
        if let purpose, purpose.count > 300 {
            throw ValidationError("'--purpose' must be 300 characters or fewer.")
        }
    }

    var invocation: CLIInvocation {
        var arguments: [String: JSONValue] = [
            "accountID": .string(accountID), "appID": .string(appID), "buildID": .string(buildID),
            "needsDocuments": .bool(needsDocuments), "availableOnFrenchStore": .bool(availableOnFrenchStore),
            "containsProprietaryCryptography": .bool(containsProprietaryCryptography),
            "containsThirdPartyCryptography": .bool(containsThirdPartyCryptography),
        ]
        if let purpose {
            arguments["purpose"] = .string(purpose)
        }
        if let documentPath {
            arguments["documentPath"] = .string(documentPath)
        }
        return .guardedRequest(
            actionID: .setBuildExportCompliance, arguments: arguments,
            format: output.format, verbose: output.verbose, executionContext: execution.context,
            operationDescription: "set export compliance for build \(buildID)",
        )
    }
}
