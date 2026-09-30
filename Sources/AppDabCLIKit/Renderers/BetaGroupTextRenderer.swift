import AppDabServices

struct BetaGroupTextRenderer {
    func render(_ group: BetaGroupSummary, style: TextStyle) -> String {
        [
            style.heading("Beta Group"),
            TextDetails(rows: [
                ("Name", group.name),
                ("Group ID", group.betaGroupID),
                ("Internal", yesNo(group.isInternalGroup)),
                ("Access to All Builds", yesNo(group.hasAccessToAllBuilds)),
                ("Feedback Enabled", yesNo(group.feedbackEnabled)),
                ("iOS Builds on Apple Silicon Mac", yesNo(group.iosBuildsAvailableForAppleSiliconMac)),
                ("iOS Builds on Apple Vision", yesNo(group.iosBuildsAvailableForAppleVision)),
                ("Public Link Enabled", yesNo(group.publicLinkEnabled)),
                ("Public Link Limit", group.publicLinkLimit.map(String.init) ?? "-"),
                ("Public Link Limit Enabled", yesNo(group.publicLinkLimitEnabled)),
                ("Public Link", group.publicLink ?? "-")
            ]).render(style: style)
        ].joined(separator: "\n\n")
    }

    private func yesNo(_ value: Bool?) -> String {
        value.map { $0 ? "Yes" : "No" } ?? "-"
    }
}
