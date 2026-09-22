import AppDabAutomation
import AppDabServices

protocol TextRenderer: Sendable {
    var actionID: AutomationActionID { get }
    func render(_ content: JSONValue, style: TextStyle) throws -> String
}
