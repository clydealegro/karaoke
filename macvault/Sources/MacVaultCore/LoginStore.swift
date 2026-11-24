import Foundation

public enum LoginStoreError: Error, Equatable, LocalizedError {
    case notFound
    /// The user dismissed a keychain access prompt.
    case cancelled
    case invalidInput(String)
    case keychain(status: Int32, message: String)

    public var errorDescription: String? {
        switch self {
        case .notFound: return "That login no longer exists."
        case .cancelled: return "Cancelled."
        case .invalidInput(let message): return message
        case .keychain(_, let message): return "Keychain error: \(message)"
        }
    }
}

public protocol LoginStore: AnyObject {
    /// All logins, sorted by title. Never touches passwords.
    func list() throws -> [Login]
    func password(for id: UUID) throws -> String
    /// Inserts or updates. `password == nil` keeps the existing password.
    func save(_ login: Login, password: String?) throws
    func delete(id: UUID) throws
}

enum LoginValidation {
    static let emptyPassword = LoginStoreError.invalidInput("Password can't be empty.")

    static func check(_ login: Login, password: String?) throws {
        if login.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw LoginStoreError.invalidInput("Name can't be empty.")
        }
        if let password, password.isEmpty {
            throw emptyPassword
        }
    }
}

/// Store for tests and SwiftUI previews.
public final class InMemoryLoginStore: LoginStore {
    private var entries: [UUID: (login: Login, password: String)] = [:]

    public init() {}

    public func list() throws -> [Login] {
        entries.values.map(\.login).sortedByTitle()
    }

    public func password(for id: UUID) throws -> String {
        guard let entry = entries[id] else { throw LoginStoreError.notFound }
        return entry.password
    }

    public func save(_ login: Login, password: String?) throws {
        try LoginValidation.check(login, password: password)
        if let password {
            entries[login.id] = (login, password)
        } else if let existing = entries[login.id] {
            entries[login.id] = (login, existing.password)
        } else {
            throw LoginValidation.emptyPassword
        }
    }

    public func delete(id: UUID) throws {
        guard entries.removeValue(forKey: id) != nil else { throw LoginStoreError.notFound }
    }
}
