import AppDabAutomation
import ConnectAccounts
import ConnectKeychain
import Foundation

enum CLIAccountStoreError: LocalizedError, Equatable {
    case accountNotFound(String)

    var errorDescription: String? {
        switch self {
        case let .accountNotFound(accountID):
            "Could not find the account \(accountID)."
        }
    }
}

final class CLIAccountStore: AutomationAccountStoring, Sendable {
    static let serviceName = "AppDabCLI"

    private let keychain: any KeychainProtocol
    @MainActor private var cachedController: APIKeyController?

    init(keychain: any KeychainProtocol = Keychain.macOSLogin()) {
        self.keychain = keychain
    }

    @MainActor
    func loadAPIKeys() async throws -> [APIKey] {
        let controller = makeController()
        if controller.apiKeys == nil {
            try controller.loadAPIKeys()
        }
        return controller.apiKeys ?? []
    }

    @MainActor
    func saveAPIKey(_ apiKey: APIKey) async throws {
        try makeController().addAPIKey(apiKey)
    }

    @MainActor
    func removeAPIKey(accountID: String) async throws -> APIKey {
        let controller = makeController()
        if controller.apiKeys == nil {
            try controller.loadAPIKeys()
        }
        guard let apiKey = controller.apiKeys?.first(where: { $0.id == accountID }) else {
            throw CLIAccountStoreError.accountNotFound(accountID)
        }
        try controller.deleteAPIKey(apiKey)
        return apiKey
    }

    @MainActor
    private func makeController() -> APIKeyController {
        if let cachedController {
            return cachedController
        }
        let controller = APIKeyController(keychainServiceName: Self.serviceName, keychain: keychain)
        cachedController = controller
        return controller
    }
}
