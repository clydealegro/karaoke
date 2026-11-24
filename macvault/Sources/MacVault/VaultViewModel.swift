import Foundation
import MacVaultCore

@MainActor
final class VaultViewModel: ObservableObject {
    enum Screen: Equatable {
        case list
        /// `nil` means a new login.
        case edit(Login?)
    }

    @Published private(set) var logins: [Login] = []
    @Published var query = ""
    @Published var screen: Screen = .list
    @Published var banner: String?
    @Published private(set) var flash: String?
    /// Bumped each time the popover opens so the search field grabs focus.
    @Published private(set) var focusToken = 0

    /// Called shortly after a password is copied (the app closes the popover).
    var onCopiedPassword: () -> Void = {}

    private let store: LoginStore
    private let gate: AuthGate
    private let clipboard: ClipboardGuard
    private var flashTask: Task<Void, Never>?

    init(store: LoginStore, gate: AuthGate, clipboard: ClipboardGuard) {
        self.store = store
        self.gate = gate
        self.clipboard = clipboard
    }

    var filteredLogins: [Login] {
        LoginFilter.filter(logins, query: query)
    }

    /// Resets the list for a fresh search, but keeps an open editor so a
    /// popover closed by a system prompt doesn't throw away unsaved edits.
    func prepareForShow() {
        if screen == .list {
            query = ""
        }
        reload()
    }

    func requestSearchFocus() {
        focusToken += 1
    }

    private func report(_ error: Error) {
        // The user dismissed a keychain prompt themselves: nothing to say.
        if (error as? LoginStoreError) == .cancelled { return }
        banner = error.localizedDescription
    }

    func reload() {
        do {
            logins = try store.list()
        } catch {
            report(error)
        }
    }

    func copyUsername(_ login: Login) {
        clipboard.copy(login.username, clearAfter: nil)
        showFlash("Username copied")
    }

    func copyPassword(_ login: Login) async {
        guard await gate.ensureAuthenticated(reason: "copy the password for “\(login.title)”") else {
            return
        }
        do {
            let password = try store.password(for: login.id)
            clipboard.copy(password, clearAfter: ClipboardGuard.defaultClearDelay)
            showFlash("Password copied · clears in \(Int(ClipboardGuard.defaultClearDelay))s")
            try? await Task.sleep(nanoseconds: 600_000_000)
            onCopiedPassword()
        } catch {
            report(error)
        }
    }

    /// Return in the search field copies the password of the top match.
    func copyTopMatchPassword() async {
        guard let first = filteredLogins.first else { return }
        await copyPassword(first)
    }

    func revealPassword(for login: Login) async -> String? {
        guard await gate.ensureAuthenticated(reason: "show the password for “\(login.title)”") else {
            return nil
        }
        do {
            return try store.password(for: login.id)
        } catch {
            report(error)
            return nil
        }
    }

    func save(_ login: Login, password: String?) {
        do {
            try store.save(login, password: password)
            banner = nil
            reload()
            screen = .list
        } catch {
            report(error)
        }
    }

    func delete(_ login: Login) {
        do {
            try store.delete(id: login.id)
            banner = nil
            reload()
            screen = .list
        } catch {
            report(error)
        }
    }

    private func showFlash(_ text: String) {
        flash = text
        flashTask?.cancel()
        flashTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            self?.flash = nil
        }
    }
}
