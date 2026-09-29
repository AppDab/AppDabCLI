import ConnectKeychain
import Foundation
import Security

/// Stores standalone CLI credentials in the macOS login Keychain. The shared
/// ConnectKeychain implementation opts into the data protection Keychain and
/// iCloud synchronization, which require an app identity unavailable to an
/// executable launched with `swift run`.
struct StandaloneKeychain: KeychainProtocol, Sendable {
    typealias CopyMatching = @Sendable (CFDictionary, UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus
    typealias Add = @Sendable (CFDictionary, UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus
    typealias Update = @Sendable (CFDictionary, CFDictionary) -> OSStatus
    typealias Delete = @Sendable (CFDictionary) -> OSStatus

    private let otherItems = Keychain()
    private let copyMatching: CopyMatching
    private let add: Add
    private let update: Update
    private let delete: Delete

    init(
        copyMatching: @escaping CopyMatching = SecItemCopyMatching,
        add: @escaping Add = SecItemAdd,
        update: @escaping Update = SecItemUpdate,
        delete: @escaping Delete = SecItemDelete
    ) {
        self.copyMatching = copyMatching
        self.add = add
        self.update = update
        self.delete = delete
    }

    func addCertificate(certificate: SecCertificate, named name: String) throws {
        try otherItems.addCertificate(certificate: certificate, named: name)
    }

    func hasCertificate(serialNumber: String) async throws -> Bool {
        try await otherItems.hasCertificate(serialNumber: serialNumber)
    }

    func hasCertificates(serialNumbers: [String]) throws -> [String: Bool] {
        try otherItems.hasCertificates(serialNumbers: serialNumbers)
    }

    func createPrivateKey(labeled label: String) throws -> SecKey {
        try otherItems.createPrivateKey(labeled: label)
    }

    func createPublicKey(from privateKey: SecKey) throws -> (key: SecKey, data: Data) {
        try otherItems.createPublicKey(from: privateKey)
    }

    func getGenericPassword(forService service: String, account: String) throws -> GenericPassword? {
        try listGenericPasswords(forService: service, account: account).first
    }

    func listGenericPasswords(forService service: String) throws -> [GenericPassword] {
        try listGenericPasswords(forService: service, account: nil)
    }

    private func listGenericPasswords(forService service: String, account: String?) throws -> [GenericPassword] {
        let query: NSMutableDictionary = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecMatchLimit: kSecMatchLimitAll,
            kSecReturnAttributes: true,
            kSecReturnData: true,
        ]
        if let account {
            query[kSecAttrAccount] = account
        }
        var result: CFTypeRef?
        let status = copyMatching(query, &result)
        guard status != errSecItemNotFound else { return [] }
        guard status == errSecSuccess, let items = result as? [Any] else {
            throw KeychainError.errorReadingFromKeychain(status)
        }
        return try items.map { item in
            guard let attributes = item as? [String: Any],
                  let account = attributes[kSecAttrAccount as String] as? String,
                  let label = attributes[kSecAttrLabel as String] as? String,
                  let generic = attributes[kSecAttrGeneric as String] as? Data,
                  let value = attributes[kSecValueData as String] as? Data else {
                throw KeychainError.malformedPasswordData
            }
            return GenericPassword(account: account, label: label, generic: generic, value: value)
        }
    }

    func addGenericPassword(forService service: String, password: GenericPassword) throws {
        let query: NSDictionary = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: password.account,
            kSecAttrLabel: password.label,
            kSecAttrGeneric: password.generic,
            kSecValueData: password.value,
        ]
        let status = add(query, nil)
        if status == errSecDuplicateItem { throw KeychainError.duplicatePassword }
        guard status == errSecSuccess else { throw KeychainError.failedAddingPassword(status) }
    }

    func updateGenericPassword(forService service: String, password: GenericPassword) throws {
        let query: NSDictionary = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: password.account,
        ]
        let changes: NSDictionary = [
            kSecAttrLabel: password.label,
            kSecAttrGeneric: password.generic,
            kSecValueData: password.value,
        ]
        guard update(query, changes) == errSecSuccess else {
            throw KeychainError.failedUpdatingPassword
        }
    }

    func deleteGenericPassword(forService service: String, password: GenericPassword) throws {
        let query: NSDictionary = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: password.account,
        ]
        guard delete(query) == errSecSuccess else {
            throw KeychainError.failedDeletingPassword
        }
    }
}
