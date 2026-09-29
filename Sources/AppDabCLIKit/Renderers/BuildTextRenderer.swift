import AppDabServices
import Foundation

struct BuildTextRenderer {
    func render(_ build: BuildSummary, style: TextStyle) -> String {
        [
            style.heading("Build"),
            TextDetails(rows: [
                ("Build", build.version),
                ("Platform", build.platform ?? "-"),
                ("Processing", build.processingState ?? "-"),
                ("Uploaded", build.uploadedDate?.formatted(.iso8601) ?? "-"),
                ("Expiration", build.expirationDate?.formatted(.iso8601) ?? "-"),
                ("Expired", build.expired.map { $0 ? "Yes" : "No" } ?? "-"),
                ("Build ID", build.buildID)
            ]).render(style: style)
        ].joined(separator: "\n\n")
    }
}
