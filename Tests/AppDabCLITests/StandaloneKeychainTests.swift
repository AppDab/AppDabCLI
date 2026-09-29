@testable import AppDabCLI
import ConnectAccounts
import ConnectKeychain
import Foundation
import Security
import Testing

struct StandaloneKeychainTests {
    @Test func unsignedCLIStoresAndRemovesAnAccountWithoutDataProtectionEntitlements() async throws {
        let security = EntitlementGatedSecurity()
        let keychain = StandaloneKeychain(
            copyMatching: { query, result in security.copyMatching(query, result) },
            add: { query, result in security.add(query, result) },
            update: { query, changes in security.update(query, changes) },
            delete: { query in security.delete(query) }
        )
        let store = CLIAccountStore(keychain: keychain)
        let apiKey = try APIKey(
            name: "Example Team",
            keyId: "P9M252746H",
            issuerId: "82067982-6b3b-4a48-be4f-5b10b373c5f2",
            privateKey: """
            -----BEGIN PRIVATE KEY-----
            MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgevZzL1gdAFr88hb2
            OF/2NxApJCzGCEDdfSp6VQO30hyhRANCAAQRWz+jn65BtOMvdyHKcvjBeBSDZH2r
            1RTwjmYSi9R/zpBnuQ4EiMnCqfMPWiZqB4QdbAd0E7oH50VpuZ1P087G
            -----END PRIVATE KEY-----
            """
        )

        try await store.saveAPIKey(apiKey)
        #expect(try await store.loadAPIKeys() == [apiKey])
        #expect(try await store.removeAPIKey(accountID: apiKey.id) == apiKey)
        #expect(try await store.loadAPIKeys().isEmpty)
    }
}

/// Models the failure of an unsigned CLI when a query opts into the data
/// protection Keychain or iCloud synchronization.
private final class EntitlementGatedSecurity: @unchecked Sendable {
    private let lock = NSLock()
    private var password: GenericPassword?

    func copyMatching(_ query: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
        lock.withLock {
            let attributes = query as NSDictionary
            if requiresEntitlement(attributes) { return errSecMissingEntitlement }
            guard let password else { return errSecItemNotFound }
            let item: NSDictionary = [
                kSecAttrAccount: password.account,
                kSecAttrLabel: password.label,
                kSecAttrGeneric: password.generic,
                kSecValueData: password.value,
            ]
            result?.pointee = [item] as CFArray
            return errSecSuccess
        }
    }

    func add(_ query: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
        lock.withLock {
            let attributes = query as NSDictionary
            if requiresEntitlement(attributes) { return errSecMissingEntitlement }
            if password != nil { return errSecDuplicateItem }
            guard let account = attributes[kSecAttrAccount] as? String,
                  let label = attributes[kSecAttrLabel] as? String,
                  let generic = attributes[kSecAttrGeneric] as? Data,
                  let value = attributes[kSecValueData] as? Data else {
                return errSecParam
            }
            password = .init(account: account, label: label, generic: generic, value: value)
            return errSecSuccess
        }
    }

    func update(_ query: CFDictionary, _ changes: CFDictionary) -> OSStatus {
        errSecUnimplemented
    }

    func delete(_ query: CFDictionary) -> OSStatus {
        lock.withLock {
            let attributes = query as NSDictionary
            if requiresEntitlement(attributes) { return errSecMissingEntitlement }
            guard password != nil else { return errSecItemNotFound }
            password = nil
            return errSecSuccess
        }
    }

    private func requiresEntitlement(_ attributes: NSDictionary) -> Bool {
        attributes[kSecUseDataProtectionKeychain] != nil || attributes[kSecAttrSynchronizable] != nil
    }
}
