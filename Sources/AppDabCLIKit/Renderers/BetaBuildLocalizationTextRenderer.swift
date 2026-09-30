import AppDabServices

struct BetaBuildLocalizationTextRenderer {
    func render(_ localization: BetaBuildLocalizationSummary) -> String {
        "Updated What to Test for \(AppStoreConnectLocaleTextFormatter.format(localization.locale)).\nID: \(localization.localizationID)\n\(localization.whatsNew)"
    }
}
