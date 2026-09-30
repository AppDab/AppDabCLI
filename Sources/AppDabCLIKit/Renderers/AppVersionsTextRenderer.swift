import AppDabServices
import Foundation

struct AppVersionsTextRenderer {
    func render(_ list: AppVersionList, style: TextStyle) -> String {
        var sections = [style.heading("Versions (\(list.versions.count) of \(list.pagination.total))")]
        if list.versions.isEmpty {
            sections.append("No versions found.")
        } else {
            sections.append(TextTable(
                headers: ["Version", "Platform", "State", "Created", "Version ID"],
                rows: list.versions.map {
                    [$0.version, $0.platform, $0.state, $0.createdDate.formatted(.iso8601), $0.versionID]
                },
            ).render(style: style))
        }
        return sections.joined(separator: "\n\n")
    }
}
