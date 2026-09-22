@testable import AppDabCLIKit

final class TestCLIInteraction: @unchecked Sendable, CLIInteraction {
    let isInteractive: Bool
    let executablePath: String
    private var responses: [String?]
    private(set) var standardError = ""

    init(
        isInteractive: Bool = true,
        executablePath: String = "/usr/local/bin/dab",
        responses: [String?] = []
    ) {
        self.isInteractive = isInteractive
        self.executablePath = executablePath
        self.responses = responses
    }

    func writeToStandardError(_ text: String) {
        standardError += text
    }

    func readLine() -> String? {
        guard !responses.isEmpty else {
            return nil
        }
        return responses.removeFirst()
    }
}
