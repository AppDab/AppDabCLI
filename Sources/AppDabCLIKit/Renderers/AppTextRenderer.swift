import AppDabServices
import Foundation

struct AppTextRenderer {
    func render(_ app: AppDetail, style: TextStyle) -> String {
        var sections = [
            style.heading(app.name),
            TextDetails(rows: [
                ("App ID", app.appID),
                ("Bundle ID", app.bundleID),
                ("SKU", app.sku),
                ("Primary Locale", AppStoreConnectLocaleTextFormatter.format(app.primaryLocale)),
                ("Content Rights", app.contentRightsDeclaration ?? "Not available"),
                ("Icon URL", app.iconURL?.absoluteString ?? "Not available"),
            ]).render(style: style),
            style.heading("Versions (\(app.displayVersions.count))"),
        ]
        if app.displayVersions.isEmpty {
            sections.append("No versions found.")
        } else {
            sections.append(TextTable(
                headers: ["Version", "Platform", "State", "Created", "Version ID"],
                rows: app.displayVersions.map {
                    [$0.version, $0.platform, $0.state, $0.createdDate.formatted(.iso8601), $0.versionID]
                },
            ).render(style: style))
        }
        return sections.joined(separator: "\n\n")
    }
}
