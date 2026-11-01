@testable import AppDabCLI
import ConnectAccounts
import ConnectKeychain
import Foundation
import Security
import Testing

struct CLIAccountStoreTests {
    @Test func signedDistributionUsesAppDabAccountsWithoutMixingStandaloneCredentials() async throws {
        let keychain = InMemoryKeychain()
        let appStore = CLIAccountStore(keychain: keychain, configuration: .sharedAppDab)
        let sourceStore = CLIAccountStore(keychain: keychain, configuration: .standalone)
        let apiKey = try makeAPIKey()
        try await appStore.saveAPIKey(apiKey)
        #expect(try await sourceStore.loadAPIKeys().isEmpty)
        let anotherInvocation = CLIAccountStore(keychain: keychain, configuration: .sharedAppDab)
        #expect(try await anotherInvocation.loadAPIKeys() == [apiKey])
        #expect(keychain.servicesWritten == ["AppDab"])
        _ = try await anotherInvocation.removeAPIKey(accountID: apiKey.id)
        #expect(try await CLIAccountStore(keychain: keychain, configuration: .sharedAppDab).loadAPIKeys().isEmpty)
    }

    @Test func savesListsAndRemovesStandaloneAccounts() async throws {
        let keychain = InMemoryKeychain()
        let store = CLIAccountStore(keychain: keychain)
        let apiKey = try makeAPIKey()

        try await store.saveAPIKey(apiKey)

        #expect(try await store.loadAPIKeys() == [apiKey])
        #expect(try await store.removeAPIKey(accountID: apiKey.id) == apiKey)
        let remainingAccounts = try await store.loadAPIKeys()
        #expect(remainingAccounts.isEmpty)
    }

    @Test func removingAnUnknownAccountExplainsWhichAccountWasMissing() async {
        let store = CLIAccountStore(keychain: InMemoryKeychain())

        await #expect(throws: CLIAccountStoreError.accountNotFound("missing")) {
            try await store.removeAPIKey(accountID: "missing")
        }
    }

    @Test func concurrentCredentialLookupsShareOneKeychainRead() async throws {
        let keychain = InMemoryKeychain()
        let seedStore = CLIAccountStore(keychain: keychain)
        let apiKey = try makeAPIKey()
        try await seedStore.saveAPIKey(apiKey)
        let initialReadCount = keychain.listReadCount
        let store = CLIAccountStore(keychain: keychain)
        try await withThrowingTaskGroup(of: [APIKey].self) { group in
            for _ in 0 ..< 20 {
                group.addTask { try await store.loadAPIKeys() }
            }
            for try await keys in group {
                #expect(keys == [apiKey])
            }
        }
        #expect(keychain.listReadCount == initialReadCount + 1)
        _ = try await store.removeAPIKey(accountID: apiKey.id)
        #expect(try await store.loadAPIKeys().isEmpty)
        try await store.saveAPIKey(apiKey)
        #expect(try await store.loadAPIKeys() == [apiKey])
        #expect(keychain.listReadCount == initialReadCount + 1)

        let nextInvocation = CLIAccountStore(keychain: keychain)
        #expect(try await nextInvocation.loadAPIKeys() == [apiKey])
        #expect(keychain.listReadCount == initialReadCount + 2)
    }

    private func makeAPIKey() throws -> APIKey {
        try APIKey(
            name: "Example Team",
            keyId: "P9M252746H",
            issuerId: "82067982-6b3b-4a48-be4f-5b10b373c5f2",
            privateKey: """
            -----BEGIN PRIVATE KEY-----
            MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgevZzL1gdAFr88hb2
            OF/2NxApJCzGCEDdfSp6VQO30hyhRANCAAQRWz+jn65BtOMvdyHKcvjBeBSDZH2r
            1RTwjmYSi9R/zpBnuQ4EiMnCqfMPWiZqB4QdbAd0E7oH50VpuZ1P087G
            -----END PRIVATE KEY-----
            """,
        )
    }
}

private final class InMemoryKeychain: KeychainProtocol, @unchecked Sendable {
    private var passwords = [String: [GenericPassword]]()
    private(set) var servicesWritten = [String]()
    private(set) var listReadCount = 0

    func addCertificate(certificate _: SecCertificate, named _: String) throws {
        fatalError("Certificates are not used by CLI account storage.")
    }

    func hasCertificate(serialNumber _: String) async throws -> Bool {
        false
    }

    func hasCertificates(serialNumbers _: [String]) throws -> [String: Bool] {
        [:]
    }

    func createPrivateKey(labeled _: String) throws -> SecKey {
        fatalError("Keys are not used by CLI account storage.")
    }

    func createPublicKey(from _: SecKey) throws -> (key: SecKey, data: Data) {
        fatalError("Keys are not used by CLI account storage.")
    }

    func getGenericPassword(forService service: String, account: String) throws -> GenericPassword? {
        passwords[service, default: []].first(where: { $0.account == account })
    }

    func listGenericPasswords(forService service: String) throws -> [GenericPassword] {
        listReadCount += 1
        return passwords[service, default: []]
    }

    func addGenericPassword(forService service: String, password: GenericPassword) throws {
        servicesWritten.append(service)
        passwords[service, default: []].append(password)
    }

    func updateGenericPassword(forService service: String, password: GenericPassword) throws {
        guard let index = passwords[service, default: []].firstIndex(where: { $0.account == password.account }) else {
            fatalError("Account must exist before it is updated.")
        }
        passwords[service, default: []][index] = password
    }

    func deleteGenericPassword(forService service: String, password: GenericPassword) throws {
        passwords[service, default: []].removeAll(where: { $0.account == password.account })
    }
}
