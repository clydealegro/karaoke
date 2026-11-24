import Foundation

/// Asks the person at the Mac to prove they're the owner (Touch ID or password).
@MainActor
public protocol Authenticator: AnyObject {
    /// `reason` completes the sentence "MacVault is trying to …".
    func authenticate(reason: String) async -> Bool
}

/// Remembers a successful authentication for `gracePeriod` seconds so the
/// user isn't prompted on every copy.
@MainActor
public final class AuthGate {
    private let authenticator: Authenticator
    private let gracePeriod: TimeInterval
    private let now: () -> Date
    private var lastSuccess: Date?

    public init(
        authenticator: Authenticator,
        gracePeriod: TimeInterval = 300, // 5 minutes
        now: @escaping () -> Date = { Date() }
    ) {
        self.authenticator = authenticator
        self.gracePeriod = gracePeriod
        self.now = now
    }

    public func needsAuthentication() -> Bool {
        guard let lastSuccess else { return true }
        return now().timeIntervalSince(lastSuccess) > gracePeriod
    }

    public func ensureAuthenticated(reason: String) async -> Bool {
        if !needsAuthentication() { return true }
        let allowed = await authenticator.authenticate(reason: reason)
        if allowed { lastSuccess = now() }
        return allowed
    }

    public func lock() {
        lastSuccess = nil
    }
}
