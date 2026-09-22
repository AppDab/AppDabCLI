public protocol CLIInteraction: Sendable {
    var isInteractive: Bool { get }
    var executablePath: String { get }

    func writeToStandardError(_ text: String)
    func readLine() -> String?
}
