@testable import AppDabAutomation
@testable import AppDabCLIKit
import Testing

struct BuildExportComplianceCommandTests {
    private let requiredArguments = [
        "builds", "setExportCompliance", "--account-id", "account-1", "--app-id", "app-1",
        "--build-id", "build-1", "--needs-documents", "false",
        "--available-on-french-store", "true", "--contains-proprietary-cryptography", "false",
        "--contains-third-party-cryptography", "true",
    ]

    @Test func previewsExportComplianceAsGuardedWrite() throws {
        let invocation = try CLIParser().parse(requiredArguments + ["--preview"])
        #expect(invocation.actionID == .setBuildExportCompliance)
        #expect(invocation.executionContext.mode == .preview)
    }

    @Test func requiresPurposeAndDocumentWhenDocumentsAreNeeded() {
        var arguments = requiredArguments
        arguments[9] = "true"
        #expect(throws: CLIUsageError.self) {
            try CLIParser().parse(arguments)
        }
    }
}
