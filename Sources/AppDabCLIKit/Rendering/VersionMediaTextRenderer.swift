import AppDabAutomation

struct VersionMediaTextRenderer {
    func render(_ output: VersionMediaActionOutput, style: TextStyle) -> String {
        let placements = output.list?.placements ?? output.result?.placements ?? []
        var sections: [String] = []
        if let path = output.result?.destinationPath {
            if path.lowercased().hasSuffix(".m3u8") {
                sections.append("Downloaded HLS playlist to \(path). Playback requires an Internet connection.")
            } else {
                sections.append("Downloaded to \(path).")
            }
        }
        if placements.isEmpty {
            sections.append("No media placements.")
        } else {
            sections.append(TextTable(headers: ["Placement ID", "Asset ID", "Group", "File", "Asset State", "Placement State"], rows: placements.map { [$0.id, $0.assetID, $0.placementGroup, $0.fileName, $0.assetState, $0.placementState] }).render(style: style))
            for placement in placements where !placement.stateDetails.isEmpty {
                let details = (try? JSONValueEncoding.string(fromEncodable: placement.stateDetails)) ?? "Details unavailable."
                sections.append("\(placement.id): \(details)")
            }
        }
        if let list = output.list {
            sections.append("Valid placement groups:\n" + list.requirements.map { requirement in
                let specs = (try? JSONValueEncoding.string(fromEncodable: requirement.specs, prettyPrinted: false)) ?? "[]"
                return "\(requirement.placementGroup)\(requirement.maximumCount.map { " (maximum \($0))" } ?? ""): \(specs)"
            }.joined(separator: "\n"))
        }
        return sections.joined(separator: "\n\n")
    }
}
