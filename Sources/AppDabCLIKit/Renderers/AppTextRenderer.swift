import AppDabAutomation
import AppDabServices
import Foundation

struct AppTextRenderer: TextRenderer {
    let actionID = AutomationActionID.getApp

    func render(_ content: JSONValue, style: TextStyle) throws -> String {
        let app = try TextDecoder.decode(Payload.self, from: content).app
        var sections = [
            style.heading(app.name),
            TextDetails(rows: [
                ("App ID", app.appID),
                ("Bundle ID", app.bundleID),
                ("SKU", app.sku),
                ("Primary Locale", app.primaryLocale),
                ("Content Rights", app.contentRightsDeclaration ?? "Not available"),
                ("Icon URL", app.iconURL?.absoluteString ?? "Not available")
            ]).render(style: style),
            style.heading("Versions (\(app.versions.count))")
        ]
        if app.versions.isEmpty {
            sections.append("No versions found.")
        } else {
            sections.append(TextTable(
                headers: ["Version", "Platform", "State", "Created", "Version ID"],
                rows: app.versions.map {
                    [$0.version, $0.platform, $0.state, $0.createdDate.formatted(.iso8601), $0.versionID]
                }
            ).render(style: style))
        }
        return sections.joined(separator: "\n\n")
    }

    private struct Payload: Decodable {
        let app: AppDetail
    }
}
