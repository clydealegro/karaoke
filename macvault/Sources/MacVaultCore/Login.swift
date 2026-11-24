import Foundation

/// A saved login. The password is never held here; stores fetch it on demand.
public struct Login: Identifiable, Equatable, Codable {
    public var id: UUID
    public var title: String
    public var username: String
    public var website: String
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        username: String = "",
        website: String = "",
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.username = username
        self.website = website
        self.updatedAt = updatedAt
    }
}

extension Array where Element == Login {
    /// Alphabetical by title, ignoring case; ties broken by id so order is stable.
    public func sortedByTitle() -> [Login] {
        sorted { lhs, rhs in
            switch lhs.title.localizedCaseInsensitiveCompare(rhs.title) {
            case .orderedAscending: return true
            case .orderedDescending: return false
            case .orderedSame: return lhs.id.uuidString < rhs.id.uuidString
            }
        }
    }
}
