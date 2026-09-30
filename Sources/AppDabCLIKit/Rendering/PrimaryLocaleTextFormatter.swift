import AppDabLocales

enum PrimaryLocaleTextFormatter {
    static func format(_ identifier: String) -> String {
        guard AppLocale.getStrict(fromId: identifier) != nil else { return identifier }
        let name = AppLocale.getDisplayName(forLocale: identifier)
        return "\(name) (\(identifier))"
    }
}
