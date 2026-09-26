import AppDabAutomation
import AppDabServices

struct AppsTextRenderer: TextRenderer {
    let actionID = AutomationActionID.listApps

    func render(_ content: JSONValue, style: TextStyle) throws -> String {
        let payload = try TextDecoder.decode(Payload.self, from: content)
        return render(apps: payload.apps, pagination: payload.pagination, style: style)
    }

    func render(_ output: AppList, style: TextStyle) -> String {
        render(apps: output.apps, pagination: output.pagination, style: style)
    }

    private func render(apps: [AppSummary], pagination: PaginationMetadata, style: TextStyle) -> String {
        var sections = [style.heading("Apps (\(apps.count) of \(pagination.total))")]
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
