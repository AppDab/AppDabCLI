import AppDabAutomation
import AppDabServices

struct AppsTextRenderer: TextRenderer {
    let actionID = AutomationActionID.listApps

    func render(_ content: JSONValue, style: TextStyle) throws -> String {
        let payload = try TextDecoder.decode(Payload.self, from: content)
        let apps = payload.apps
        var sections = [style.heading("Apps (\(apps.count) of \(payload.pagination.total))")]
        if apps.isEmpty {
            sections.append("No apps found for this account.")
        } else {
            sections.append(TextTable(
                headers: ["Name", "Bundle ID", "SKU", "Locale", "App ID"],
                rows: apps.map { [$0.name, $0.bundleID, $0.sku, $0.primaryLocale, $0.appID] }
            ).render(style: style))
        }
        return sections.joined(separator: "\n\n")
    }

    private struct Payload: Decodable {
        let apps: [AppSummary]
        let pagination: PaginationMetadata
    }
}
