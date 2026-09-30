import AppDabServices

struct BetaGroupBuildTextRenderer {
    func render(_ membership: BetaGroupBuildMembership, style: TextStyle) -> String {
        [
            style.heading("Beta Group Build"),
            TextDetails(rows: [
                ("Group", membership.betaGroup.name),
                ("Group ID", membership.betaGroup.betaGroupID),
                ("Build ID", membership.buildID),
                ("Member", membership.isMember ? "Yes" : "No"),
            ]).render(style: style),
        ].joined(separator: "\n\n")
    }
}
