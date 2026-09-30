import AppDabAutomation
import AppDabServices

struct BetaAppLocalizationsTextRenderer {
    func render(_ value: JSONValue) -> String {
        guard case let .array(items)? = value.objectValue?["localizations"] else {
            return "No beta app localizations found."
        }
        return items.map { item in
            let fields = item.objectValue ?? [:]
            let locale = fields["locale"]?.stringValue ?? "Unknown"
            let localizationID = fields["localizationID"]?.stringValue ?? ""
            return "\(AppStoreConnectLocaleTextFormatter.format(locale))  \(localizationID)"
        }.joined(separator: "\n")
    }

    func created(locale: String) -> String {
        "Created beta app localization for \(AppStoreConnectLocaleTextFormatter.format(locale))."
    }

    func updated(_ value: JSONValue, fallbackID: String) -> String {
        mutationSummary("Updated", value: value, fallbackID: fallbackID)
    }

    func deleted(_ value: JSONValue, fallbackID: String) -> String {
        mutationSummary("Deleted", value: value, fallbackID: fallbackID)
    }

    private func mutationSummary(_ verb: String, value: JSONValue, fallbackID: String) -> String {
        let localization = value.objectValue?["localization"]?.objectValue ?? [:]
        guard let locale = localization["locale"]?.stringValue else {
            return "\(verb) beta app localization \(fallbackID)."
        }
        let localizationID = localization["localizationID"]?.stringValue ?? fallbackID
        return "\(verb) beta app localization for \(AppStoreConnectLocaleTextFormatter.format(locale)).\nID: \(localizationID)"
    }
}
