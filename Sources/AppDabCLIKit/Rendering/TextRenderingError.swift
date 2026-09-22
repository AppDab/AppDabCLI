import Foundation

enum TextRenderingError: LocalizedError {
    case invalidStructuredContent(String)
    case missingRenderer(String)

    var errorDescription: String? {
        switch self {
        case .invalidStructuredContent(let description):
            "Could not render the command result: \(description)"
        case .missingRenderer(let actionID):
            "No text renderer is available for \(actionID). Use JSON output."
        }
    }
}
