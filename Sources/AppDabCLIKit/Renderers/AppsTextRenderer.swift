import AppDabLocales
import AppDabServices

struct AppsTextRenderer {
    func render(_ output: AppList, style: TextStyle) -> String {
        render(apps: output.apps, pagination: output.pagination, style: style)
    }

    private func render(apps: [AppSummary], pagination: PaginationMetadata, style: TextStyle) -> String {
        var sections = [style.heading("Apps (\(apps.count) of \(pagination.total))")]
        if apps.isEmpty {
            sections.append("No apps found for this account.")
        } else {
            sections.append(TextTable(
                headers: ["Name", "Bundle ID", "SKU", "Locale", "App ID"],
                rows: apps.map { [$0.name, $0.bundleID, $0.sku, PrimaryLocaleTextFormatter.format($0.primaryLocale), $0.appID] },
            ).render(style: style))
        }
        return sections.joined(separator: "\n\n")
    }
}
