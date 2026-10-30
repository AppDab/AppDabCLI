import AppDabAutomation
import AppDabServices
import Foundation

struct VersionMediaTextRenderer {
    func render(_ output: VersionMediaActionOutput, style: TextStyle) -> String {
        let placements = output.list?.placements ?? output.result?.placements ?? []
        var sections: [String] = []
        if let path = output.result?.destinationPath {
            sections.append(path.lowercased().hasSuffix(".m3u8")
                ? "Downloaded HLS playlist to \(path). Playback requires an Internet connection."
                : "Downloaded to \(path).")
        }
        if let list = output.list {
            sections.append(style.heading("Media placements (\(placements.count))"))
            if placements.isEmpty {
                sections.append("No media placements.")
            }
            // Group for readability without changing the order of placements within a group.
            let groups = unique(placements.map(\.placementGroup))
            for group in groups {
                let items = placements.filter { $0.placementGroup == group }
                let maximum = list.requirements.first { $0.placementGroup == group }?.maximumCount
                let count = maximum.map { "\(items.count)/\($0)" } ?? "\(items.count)"
                var lines = [style.subheading("\(group) (\(count))")]
                for (index, item) in items.enumerated() {
                    lines.append("  \(index + 1). \(shortFileName(item.fileName, width: style.maximumWidth ?? 100))")
                    lines.append("     \(style.detailLabel("Placement:")) \(item.id)")
                    lines.append("     State: \(state(item.placementState)) | Asset: \(state(item.assetState))")
                    lines += diagnostics(item).map { "     \($0)" }
                }
                sections.append(lines.joined(separator: "\n"))
            }
            if !placements.isEmpty {
                sections.append("Use get --placement-id ID for full filenames and asset details.")
            }
            sections.append(requirements(list.requirements, style: style))
        } else if placements.isEmpty {
            if output.result?.destinationPath == nil {
                sections.append("No media placements.")
            }
        } else {
            for placement in placements {
                var rows = [
                    ("Placement ID", placement.id), ("Asset ID", placement.assetID),
                    ("Group", placement.placementGroup), ("File", placement.fileName),
                    ("Asset state", state(placement.assetState)),
                    ("Placement state", state(placement.placementState)),
                ]
                if let size = placement.fileSize {
                    rows.append(("File size", bytes(size)))
                }
                sections.append(([TextDetails(rows: rows).render(style: style)] + diagnostics(placement)).joined(separator: "\n"))
            }
        }
        return sections.filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    private func requirements(_ requirements: [VersionMediaRequirement], style: TextStyle) -> String {
        var lines = [style.subheading("Valid placement groups:")]
        for requirement in requirements {
            let maximum = requirement.maximumCount.map { " (maximum \($0))" } ?? ""
            lines.append("  \(requirement.placementGroup)\(maximum)")
            for spec in unique(requirement.specs.map(specification)) {
                lines += wrap(spec, width: max(30, (style.maximumWidth ?? 100) - 4)).map { "    \($0)" }
            }
        }
        lines.append("Full media requirements are available with --format json.")
        return lines.joined(separator: "\n")
    }

    private func specification(_ spec: JSONValue) -> String {
        let values = spec.objectValue ?? [:]
        var parts: [String] = []
        if let dimensions = values["dimensions"]?.objectValue,
           let width = range(dimensions["minWidth"], dimensions["maxWidth"]),
           let height = range(dimensions["minHeight"], dimensions["maxHeight"])
        {
            parts.append("\(width) × \(height) px")
        }
        if case let .array(extensions) = values["fileExtensions"] {
            parts.append(extensions.compactMap(\.stringValue).joined(separator: ", "))
        }
        if let size = values["maxFileSize"]?.intValue {
            parts.append("max \(bytes(size))")
        }
        if let duration = values["duration"]?.objectValue {
            let min = seconds(duration["min"]?.stringValue)
            let max = seconds(duration["max"]?.stringValue)
            if let min, let max {
                parts.append(min == max ? min : "\(min) to \(max)")
            }
        }
        if case let .array(rates) = values["frameRates"] {
            let ranges = rates.compactMap { rate in
                range(rate.objectValue?["minFps"], rate.objectValue?["maxFps"])
            }
            if !ranges.isEmpty {
                parts.append(ranges.joined(separator: ", ") + " fps")
            }
        }
        if values["audioRequired"] == .bool(true) {
            parts.append("audio required")
        }
        if values["alphaAllowed"] == .bool(true) {
            parts.append("alpha allowed")
        }
        return parts.isEmpty ? "Additional specifications available with --format json." : parts.joined(separator: "; ")
    }

    private func range(_ minimum: JSONValue?, _ maximum: JSONValue?) -> String? {
        guard let min = minimum?.intValue, let max = maximum?.intValue else { return nil }
        return min == max ? "\(min)" : "\(min) to \(max)"
    }

    private func seconds(_ value: String?) -> String? {
        guard let value else { return nil }
        if value.hasPrefix("PT"), value.hasSuffix("S"), let number = Double(value.dropFirst(2).dropLast()) {
            return "\(number.formatted(.number.grouping(.never))) s"
        }
        return value
    }

    private func bytes(_ count: Int) -> String {
        for (unit, divisor) in [("GiB", 1_073_741_824), ("MiB", 1_048_576), ("KiB", 1024)] where count >= divisor {
            return "\((Double(count) / Double(divisor)).formatted(.number.precision(.fractionLength(0 ... 1)))) \(unit)"
        }
        return "\(count) bytes"
    }

    private func state(_ value: String) -> String {
        value.replacingOccurrences(of: "_", with: " ").lowercased().capitalized
    }

    private func diagnostics(_ placement: VersionMediaPlacement) -> [String] {
        placement.stateDetails.map { detail in
            let values = detail.objectValue ?? [:]
            let parts = [values["code"]?.stringValue, values["description"]?.stringValue ?? values["message"]?.stringValue].compactMap(\.self)
            return parts.isEmpty ? ((try? JSONValueEncoding.string(from: detail)) ?? "Details unavailable.") : parts.joined(separator: ": ")
        }
    }

    private func shortFileName(_ name: String, width: Int) -> String {
        let limit = max(20, width - 8)
        guard name.count > limit else { return name }
        return String(name.prefix(limit - 15)) + "..." + String(name.suffix(12))
    }

    private func unique(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.filter { seen.insert($0).inserted }
    }

    private func wrap(_ value: String, width: Int) -> [String] {
        var lines: [String] = []
        var line = ""
        for word in value.split(separator: " ") {
            if !line.isEmpty, line.count + word.count + 1 > width {
                lines.append(line)
                line = ""
            }
            line += (line.isEmpty ? "" : " ") + word
        }
        if !line.isEmpty {
            lines.append(line)
        }
        return lines
    }
}
