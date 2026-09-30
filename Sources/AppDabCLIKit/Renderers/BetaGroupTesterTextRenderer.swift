import AppDabServices

struct BetaGroupTesterTextRenderer {
    func render(_ membership: BetaGroupTesterMembership, style: TextStyle) -> String {
        [
            style.heading("Beta Group Tester"),
            TextDetails(rows: [
                ("Group", membership.betaGroupName),
                ("Group ID", membership.betaGroupID),
                ("Tester ID", membership.testerID),
                ("Member", membership.isMember ? "Yes" : "No"),
            ]).render(style: style),
        ].joined(separator: "\n\n")
    }
}
