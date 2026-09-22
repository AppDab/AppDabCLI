import AppDabAutomation
import AppDabCLIKit
import AppDabServices
import Darwin
import Foundation

@main
struct AppDabCLI {
    static func main() async {
        let outputCapabilities = CLIOutputCapabilities(
            standardOutputIsTerminal: isatty(STDOUT_FILENO) == 1,
            standardErrorIsTerminal: isatty(STDERR_FILENO) == 1
        )
        let runner = CLIRunner(
            executor: StandaloneAutomationExecutor.make(),
            outputCapabilities: outputCapabilities,
            interaction: StandardCLIInteraction(
                executablePath: CommandLine.arguments.first ?? "dab"
            )
        )
        let result = await runner.run(arguments: Array(CommandLine.arguments.dropFirst()))
        if !result.standardOutput.isEmpty {
            print(result.standardOutput)
        }
        if !result.standardError.isEmpty {
            FileHandle.standardError.write(Data(result.standardError.utf8))
            FileHandle.standardError.write(Data("\n".utf8))
        }
        Foundation.exit(result.exitCode)
    }
}
