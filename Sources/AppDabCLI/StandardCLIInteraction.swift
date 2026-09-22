import AppDabCLIKit
import Darwin
import Foundation

struct StandardCLIInteraction: CLIInteraction {
    let executablePath: String

    var isInteractive: Bool {
        isatty(STDIN_FILENO) == 1
            && isatty(STDOUT_FILENO) == 1
            && isatty(STDERR_FILENO) == 1
    }

    func writeToStandardError(_ text: String) {
        FileHandle.standardError.write(Data(text.utf8))
    }

    func readLine() -> String? {
        Swift.readLine()
    }
}
