import AppDabAutomation
import AppDabServices

public struct CLITextRendererRegistry: Sendable {
    private static let standardRenderers = [
        AnyTextRenderer(AccountsTextRenderer()),
        AnyTextRenderer(AccountAdditionTextRenderer()),
        AnyTextRenderer(AccountRemovalTextRenderer()),
        AnyTextRenderer(AccountVerificationTextRenderer()),
        AnyTextRenderer(AppsTextRenderer()),
        AnyTextRenderer(AppTextRenderer()),
        AnyTextRenderer(VersionTextRenderer()),
        AnyTextRenderer(CustomerReviewsTextRenderer())
    ]

    public static let supportedActionIDs = Set(standardRenderers.map(\.actionID))

    private let renderersByActionID: [AutomationActionID: AnyTextRenderer]

    public init() {
        renderersByActionID = Dictionary(
            uniqueKeysWithValues: Self.standardRenderers.map { ($0.actionID, $0) }
        )
    }

    init(renderers: [AnyTextRenderer]) {
        renderersByActionID = Dictionary(uniqueKeysWithValues: renderers.map { ($0.actionID, $0) })
    }

    public func render(
        actionID: AutomationActionID,
        structuredContent: JSONValue,
        supportsColor: Bool,
        maximumWidth: Int?
    ) throws -> String {
        guard let renderer = renderersByActionID[actionID] else {
            throw TextRenderingError.missingRenderer(actionID.rawValue)
        }
        return try renderer.render(
            structuredContent,
            style: .init(supportsColor: supportsColor, maximumWidth: maximumWidth)
        )
    }
}
