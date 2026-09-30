import AppDabServices

struct BetaGroupsTextRenderer {
    func render(_ list: BetaGroupList, style: TextStyle) -> String {
        var sections = [style.heading("Beta Groups (\(list.betaGroups.count) of \(list.pagination.total))")]
        if list.betaGroups.isEmpty {
            sections.append("No beta groups found.")
        } else {
            sections.append(TextTable(
                headers: ["Name", "Type", "All Builds", "Group ID"],
                rows: list.betaGroups.map {
                    [$0.name, $0.isInternalGroup.map { $0 ? "Internal" : "External" } ?? "-",
                     $0.hasAccessToAllBuilds.map { $0 ? "Yes" : "No" } ?? "-", $0.betaGroupID]
                },
            ).render(style: style))
        }
        return sections.joined(separator: "\n\n")
    }
}
