struct TextTable {
    let headers: [String]
    let rows: [[String]]

    func render(style: TextStyle) -> String {
        let sanitizedHeaders = headers.map(Self.sanitize)
        let sanitizedRows = rows.map { $0.map(Self.sanitize) }
        let widths = sanitizedHeaders.indices.map { column in
            ([sanitizedHeaders[column]] + sanitizedRows.compactMap { $0.indices.contains(column) ? $0[column] : nil })
                .map(Self.displayWidth)
                .max() ?? 0
        }
        let naturalWidth = widths.reduce(0, +) + max(0, widths.count - 1) * 2
        if let maximumWidth = style.maximumWidth, naturalWidth > maximumWidth {
            return renderRecords(headers: sanitizedHeaders, rows: sanitizedRows, style: style)
        }
        let header = renderRow(sanitizedHeaders, widths: widths, transform: style.tableHeader)
        let body = sanitizedRows.map { renderRow($0, widths: widths, transform: { $0 }) }
        return ([header] + body).joined(separator: "\n")
    }

    private func renderRow(
        _ cells: [String],
        widths: [Int],
        transform: (String) -> String
    ) -> String {
        cells.indices.map { column in
            let cell = cells[column]
            let padded = if column == cells.indices.last {
                cell
            } else {
                cell + String(repeating: " ", count: max(0, widths[column] - Self.displayWidth(cell)))
            }
            return transform(padded)
        }.joined(separator: "  ")
    }

    private func renderRecords(headers: [String], rows: [[String]], style: TextStyle) -> String {
        rows.map { row in
            zip(headers, row).map { header, value in
                "\(style.detailLabel(header + ":")) \(value)"
            }.joined(separator: "\n")
        }.joined(separator: "\n\n")
    }

    private static func displayWidth(_ value: String) -> Int {
        value.unicodeScalars.reduce(0) { width, scalar in
            if scalar.properties.generalCategory == .control { return width }
            return width + (scalar.value >= 0x1100 ? 2 : 1)
        }
    }

    private static func sanitize(_ value: String) -> String {
        String(value.unicodeScalars.map { scalar in
            scalar.properties.generalCategory == .control && scalar != "\n" ? "�" : Character(String(scalar))
        })
    }
}
