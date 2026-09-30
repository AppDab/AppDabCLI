import AppDabServices
import Foundation

struct BuildsTextRenderer {
    func render(_ list: BuildList, style: TextStyle) -> String {
        var sections = [style.heading("Builds (\(list.builds.count) of \(list.pagination.total))")]
        if list.builds.isEmpty {
            sections.append("No builds found.")
        } else {
            sections.append(TextTable(
                headers: ["Build", "Platform", "Processing", "Uploaded", "Expired", "Build ID"],
                rows: list.builds.map {
                    [
                        $0.version,
                        $0.platform ?? "-",
                        $0.processingState ?? "-",
                        $0.uploadedDate?.formatted(.iso8601) ?? "-",
                        $0.expired.map { $0 ? "Yes" : "No" } ?? "-",
                        $0.buildID,
                    ]
                },
            ).render(style: style))
        }
        return sections.joined(separator: "\n\n")
    }
}
