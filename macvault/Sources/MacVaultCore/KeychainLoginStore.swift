#if canImport(Security)
import Foundation
import Security

/// Stores each login as one generic-password item in the login keychain.
/// Metadata lives in item attributes so `list()` never reads a password.
public final class KeychainLoginStore: LoginStore {
    public let service: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(service: String = "MacVault") {
        self.service = service
    }

    public func list() throws -> [Login] {
        var query = baseQuery()
        query[kSecMatchLimit as String] = kSecMatchLimitAll
        query[kSecReturnAttributes as String] = true

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return [] }
        try check(status)

        let items = result as? [[String: Any]] ?? []
        return items.compactMap(login(from:)).sortedByTitle()
    }

    public func password(for id: UUID) throws -> String {
        var query = itemQuery(id)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { throw LoginStoreError.notFound }
        try check(status)

        guard let data = result as? Data, let password = String(data: data, encoding: .utf8) else {
            throw LoginStoreError.keychain(status: errSecDecode, message: "The saved password can't be read.")
        }
        return password
    }

    public func save(_ login: Login, password: String?) throws {
        try LoginValidation.check(login, password: password)

        var attributes: [String: Any] = [
            kSecAttrLabel as String: "MacVault: \(login.title)",
            kSecAttrDescription as String: "MacVault login",
            kSecAttrGeneric as String: try encoder.encode(login),
        ]
        if let password {
            attributes[kSecValueData as String] = Data(password.utf8)
        }

        let query = itemQuery(login.id)
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            guard password != nil else { throw LoginValidation.emptyPassword }
            let add = query.merging(attributes) { _, new in new }
            try check(SecItemAdd(add as CFDictionary, nil))
        } else {
            try check(status)
        }
    }

    public func delete(id: UUID) throws {
        let status = SecItemDelete(itemQuery(id) as CFDictionary)
        if status == errSecItemNotFound { throw LoginStoreError.notFound }
        try check(status)
    }

    // MARK: - Helpers

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
    }

    private func itemQuery(_ id: UUID) -> [String: Any] {
        var query = baseQuery()
        query[kSecAttrAccount as String] = id.uuidString
        return query
    }

    /// Items whose metadata can't be decoded are still listed (titled with
    /// their id) so the user can open and delete them.
    private func login(from attributes: [String: Any]) -> Login? {
        guard let account = attributes[kSecAttrAccount as String] as? String,
              let id = UUID(uuidString: account) else { return nil }
        if let data = attributes[kSecAttrGeneric as String] as? Data,
           var login = try? decoder.decode(Login.self, from: data) {
            login.id = id
            return login
        }
        return Login(id: id, title: account)
    }

    private func check(_ status: OSStatus) throws {
        guard status != errSecSuccess else { return }
        if status == errSecUserCanceled { throw LoginStoreError.cancelled }
        let message = SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
        throw LoginStoreError.keychain(status: status, message: message)
    }
}
#endif
