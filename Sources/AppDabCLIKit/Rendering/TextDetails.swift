struct TextDetails {
    let rows: [(String, String)]

    func render(style: TextStyle) -> String {
        let labelWidth = rows.map(\.0.count).max() ?? 0
        return rows.map { label, value in
            let spacing = String(repeating: " ", count: labelWidth - label.count + 2)
            return "\(style.detailLabel(label + ":"))\(spacing)\(value)"
        }.joined(separator: "\n")
    }
}
