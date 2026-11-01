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
    private let keychain: any KeychainProtocol
    private let serviceName: String
    @MainActor private var cachedController: APIKeyController?

    init(keychain: (any KeychainProtocol)? = nil, configuration: CLIKeychainConfiguration = .current) {
        self.keychain = keychain ?? configuration.makeKeychain()
        serviceName = configuration.serviceName
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
        let controller = APIKeyController(keychainServiceName: serviceName, keychain: keychain)
        cachedController = controller
        return controller
    }
}
