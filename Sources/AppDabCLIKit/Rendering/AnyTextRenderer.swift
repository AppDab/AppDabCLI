import AppDabAutomation
import AppDabServices

struct AnyTextRenderer: Sendable {
    let actionID: AutomationActionID
    private let renderContent: @Sendable (JSONValue, TextStyle) throws -> String

    init<Renderer: TextRenderer>(_ renderer: Renderer) {
        actionID = renderer.actionID
        renderContent = renderer.render
    }

    func render(_ content: JSONValue, style: TextStyle) throws -> String {
        try renderContent(content, style)
    }
}
