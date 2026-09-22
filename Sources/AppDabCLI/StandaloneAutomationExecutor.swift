import AppDabAutomation
import AppDabCLIKit
import AppDabServices
import Foundation

enum StandaloneAutomationExecutor {
    static func make() -> Executor {
        let accountStore = CLIAccountStore()
        let accountProvider = StoredAccountProvider(loadAPIKeys: accountStore.loadAPIKeys)
        let services = LiveServices(accountProvider: accountProvider)
        let dataProvider = ServiceAutomationDataProvider(
            services: services,
            accountStore: accountStore
        )
        return Executor(
            dataProvider: dataProvider,
            auditStore: AutomationSQLiteAuditStore(databaseURL: auditDatabaseURL())
        )
    }

    private static func auditDatabaseURL() -> URL {
        let fileManager = FileManager.default
        let containerURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        return containerURL
            .appendingPathComponent("AppDabCLI", isDirectory: true)
            .appendingPathComponent("dab-audit.sqlite")
    }
}
