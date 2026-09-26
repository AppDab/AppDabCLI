import AppDabAutomation
import AppDabServices
import Foundation

struct VersionTextRenderer: TextRenderer {
    let actionID = AutomationActionID.createAppVersion

    func render(_ content: JSONValue, style: TextStyle) throws -> String {
        guard let versionValue = content.objectValue?["version"] else {
            throw TextRenderingError.invalidStructuredContent("Missing version.")
        }
        let version = try TextDecoder.decode(AppVersion.self, from: versionValue)
        return render(version, style: style)
    }

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
