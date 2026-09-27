import AppDabServices
import Foundation

struct VersionTextRenderer {
    func render(_ version: AppVersion, style: TextStyle) -> String {
        return [
            style.heading("Created Version"),
            TextDetails(rows: [
                ("Version", version.version),
                ("Platform", version.platform),
                ("State", version.state),
                ("Created", version.createdDate.formatted(.iso8601)),
                ("Version ID", version.versionID),
            ]).render(style: style),
        ].joined(separator: "\n\n")
    }

}
