struct TextStyle: Sendable {
    let supportsColor: Bool
    let maximumWidth: Int?

    init(supportsColor: Bool, maximumWidth: Int? = nil) {
        self.supportsColor = supportsColor
        self.maximumWidth = maximumWidth
    }

    func heading(_ text: String) -> String {
        decorate(text, codes: ["1", "36"])
    }

    func subheading(_ text: String) -> String {
        decorate(text, codes: ["1"])
    }

    func tableHeader(_ text: String) -> String {
        decorate(text, codes: ["1"])
    }

    func detailLabel(_ text: String) -> String {
        decorate(text, codes: ["2"])
    }

    func reviewTitle(_ text: String) -> String {
        decorate(text, codes: ["1", "33"])
    }

    private func decorate(_ text: String, codes: [String]) -> String {
        guard supportsColor else {
            return text
        }
        return "\u{001B}[\(codes.joined(separator: ";"))m\(text)\u{001B}[0m"
    }
}
