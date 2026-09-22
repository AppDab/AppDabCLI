import AppDabAutomation
import ConnectAccounts
import ConnectKeychain
import Foundation

public enum CLIAccountStoreError: LocalizedError, Equatable {
    case accountNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .accountNotFound(let accountID):
            "Could not find the account \(accountID)."
        }
    }
}

public final class CLIAccountStore: AutomationAccountStoring, Sendable {
    public let serviceName = "AppDabCLI"
    public let keychain: any KeychainProtocol

    public init(keychain: KeychainProtocol = Keychain()) {
        self.keychain = keychain
    }

    public func loadAPIKeys() async throws -> [APIKey] {
        let controller = await APIKeyController(
            keychainServiceName: serviceName,
            keychain: keychain
        )
        try await controller.loadAPIKeys()
        return await controller.apiKeys ?? []
    }

    public func saveAPIKey(_ apiKey: APIKey) async throws {
        let controller = await APIKeyController(
            keychainServiceName: serviceName,
            keychain: keychain
        )
        try await controller.addAPIKey(apiKey)
    }

    public func removeAPIKey(accountID: String) async throws -> APIKey {
        let controller = await APIKeyController(
            keychainServiceName: serviceName,
            keychain: keychain
        )
        try await controller.loadAPIKeys()
        guard let apiKey = await controller.apiKeys?.first(where: { $0.id == accountID }) else {
            throw CLIAccountStoreError.accountNotFound(accountID)
        }
        try await controller.deleteAPIKey(apiKey)
        return apiKey
    }
}
