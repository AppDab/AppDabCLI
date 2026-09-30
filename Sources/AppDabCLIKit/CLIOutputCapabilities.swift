import Foundation

public struct CLIOutputCapabilities: Equatable, Sendable {
    public let standardOutputSupportsColor: Bool
    public let standardErrorSupportsColor: Bool
    public let standardOutputMaximumWidth: Int?

    public init(
        standardOutputIsTerminal: Bool,
        standardErrorIsTerminal: Bool,
        environment: [String: String] = ProcessInfo.processInfo.environment,
    ) {
        let colorAllowed = environment["NO_COLOR"] == nil && environment["TERM"]?.lowercased() != "dumb"
        standardOutputSupportsColor = standardOutputIsTerminal && colorAllowed
        standardErrorSupportsColor = standardErrorIsTerminal && colorAllowed
        standardOutputMaximumWidth = standardOutputIsTerminal
            ? Int(environment["COLUMNS"] ?? "")
            : nil
    }

    public static let plain = CLIOutputCapabilities(
        standardOutputIsTerminal: false,
        standardErrorIsTerminal: false,
        environment: [:],
    )
}
