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

    func prepareForShow() {
        query = ""
        screen = .list
        reload()
        focusToken += 1
    }

    func reload() {
        do {
            logins = try store.list()
        } catch {
            banner = error.localizedDescription
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
            banner = error.localizedDescription
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
            banner = error.localizedDescription
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
            banner = error.localizedDescription
        }
    }

    func delete(_ login: Login) {
        do {
            try store.delete(id: login.id)
            banner = nil
            reload()
            screen = .list
        } catch {
            banner = error.localizedDescription
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
