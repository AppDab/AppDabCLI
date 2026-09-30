import AppDabLocales

enum PrimaryLocaleTextFormatter {
    static func format(_ identifier: String) -> String {
        guard AppStoreConnectLocale.getStrict(fromId: identifier) != nil else { return identifier }
        let name = AppStoreConnectLocale.getDisplayName(forLocale: identifier)
        return "\(name) (\(identifier))"
    }
}
