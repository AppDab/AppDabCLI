@testable import AppDabCLI
import ConnectAccounts
import ConnectKeychain
import Foundation
import Security
import Testing

struct CLIAccountStoreTests {
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
    private var passwords = [GenericPassword]()

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

    func getGenericPassword(forService _: String, account: String) throws -> GenericPassword? {
        passwords.first(where: { $0.account == account })
    }

    func listGenericPasswords(forService _: String) throws -> [GenericPassword] {
        passwords
    }

    func addGenericPassword(forService _: String, password: GenericPassword) throws {
        passwords.append(password)
    }

    func updateGenericPassword(forService _: String, password: GenericPassword) throws {
        guard let index = passwords.firstIndex(where: { $0.account == password.account }) else {
            fatalError("Account must exist before it is updated.")
        }
        passwords[index] = password
    }

    func deleteGenericPassword(forService _: String, password: GenericPassword) throws {
        passwords.removeAll(where: { $0.account == password.account })
    }
}
