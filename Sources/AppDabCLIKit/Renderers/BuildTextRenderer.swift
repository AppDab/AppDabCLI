import AppDabServices
import Foundation

struct BuildTextRenderer {
    func render(_ build: BuildSummary, style: TextStyle) -> String {
        var sections = [
            style.heading("Build"),
            TextDetails(rows: [
                ("Build", build.version),
                ("Platform", build.platform ?? "-"),
                ("Processing", build.processingState ?? "-"),
                ("Uploaded", build.uploadedDate?.formatted(.iso8601) ?? "-"),
                ("Expiration", build.expirationDate?.formatted(.iso8601) ?? "-"),
                ("Expired", build.expired.map { $0 ? "Yes" : "No" } ?? "-"),
                ("Build ID", build.buildID),
            ]).render(style: style),
        ]
        if let detail = build.testFlight {
            var rows = [
                ("App ID", detail.appID ?? "-"),
                ("Prerelease version", build.prereleaseVersion ?? "-"),
                ("Internal beta state", build.internalBetaState ?? "-"),
                ("External beta state", build.externalBetaState ?? "-"),
            ]
            rows += detail.localizations.map { ("What to Test (\($0.locale ?? $0.id))", $0.whatToTest ?? "-") }
            rows += detail.bundles.map { ("Bundle", "\($0.bundleID ?? $0.id) (\($0.bundleType ?? "-"))") }
            sections.append(style.heading("TestFlight"))
            sections.append(TextDetails(rows: rows).render(style: style))
        }
        return sections.joined(separator: "\n\n")
    }
}
