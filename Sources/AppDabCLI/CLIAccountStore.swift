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

    init(keychain: any KeychainProtocol = Keychain.macOSLogin()) {
        self.keychain = keychain
    }

    func loadAPIKeys() async throws -> [APIKey] {
        let controller = await makeController()
        try await controller.loadAPIKeys()
        return await controller.apiKeys ?? []
    }

    func saveAPIKey(_ apiKey: APIKey) async throws {
        let controller = await makeController()
        try await controller.addAPIKey(apiKey)
    }

    func removeAPIKey(accountID: String) async throws -> APIKey {
        let controller = await makeController()
        try await controller.loadAPIKeys()
        guard let apiKey = await controller.apiKeys?.first(where: { $0.id == accountID }) else {
            throw CLIAccountStoreError.accountNotFound(accountID)
        }
        try await controller.deleteAPIKey(apiKey)
        return apiKey
    }

    @MainActor
    private func makeController() -> APIKeyController {
        APIKeyController(keychainServiceName: Self.serviceName, keychain: keychain)
    }
}
