# MacVault — Design Spec

Date: 2026-11-24
Status: Approved

## 1. Summary

MacVault is a personal password manager for macOS, inspired by the core of
1Password. It lives in the menu bar. The user saves logins and copies a
username or password from the menu bar popover in one or two clicks. All data
is stored in the user's macOS login Keychain; there is no master password.

Target machine: the user's Mac Mini (Apple silicon), current macOS.

## 2. Goals and non-goals

### Goals (version one)

- Save, edit and delete logins: name, username, password, website.
- Menu bar icon that opens a popover with search and a list of logins.
- Copy password / copy username buttons on each row; Return copies the
  password of the top match.
- Global shortcut ⌥⌘P opens the popover from any app.
- Touch ID or Mac password confirmation before a password is copied or
  revealed, with a 5-minute grace period.
- Password generator (length 8–64, default 20; symbols on/off; digits on/off).
- Copied passwords are cleared from the clipboard after 30 seconds unless the
  clipboard changed in the meantime.

### Non-goals

- Master password or a separately encrypted vault file.
- Sync, iPhone/iPad, browser extension, autofill.
- Notes, credit cards, secure notes, attachments, multiple vaults.
- Import/export.
- Notarized distribution or App Store release.

## 3. Constraints

- Built as a Swift package (Swift 5.9+, macOS 13+) so it builds from Terminal
  with `./build.sh`; Xcode (or its Command Line Tools) must be installed.
- No paid Apple developer account: the app is ad-hoc signed. Because of this
  it uses the file-based login keychain (not the data-protection keychain,
  which needs a team-signed entitlement). After a rebuild macOS may ask once
  for keychain access; the user clicks **Always Allow**.
- The development container is Linux, so the app is compiled and tested on
  the user's Mac.

## 4. Architecture

Two targets in one Swift package at `macvault/`:

### 4.1 `MacVaultCore` (library, unit tested)

| Unit | Purpose |
| --- | --- |
| `Login` | Value type: `id: UUID`, `title`, `username`, `website`, `updatedAt`. No password field; the password is fetched on demand. |
| `LoginStore` protocol | `list() -> [Login]`, `password(for:) -> String`, `save(_:password:)`, `delete(id:)`. |
| `KeychainLoginStore` | `LoginStore` on the login keychain. One `kSecClassGenericPassword` item per login: service `MacVault`, account = UUID string, label = `MacVault: <title>`, `kSecAttrGeneric` = JSON of the `Login` metadata, value data = UTF-8 password. `list()` asks for attributes only, never data. |
| `InMemoryLoginStore` | `LoginStore` for tests and previews. |
| `PasswordGenerator` | Uses `SecRandomCopyBytes` via an injectable random source. Guarantees at least one character from each enabled class; excludes look-alikes `0 O l 1 I`. |
| `LoginFilter` | Case-insensitive search over title, username and website; ranks title-prefix matches first, then other matches, alphabetical within each group. |
| `ClipboardGuard` | Writes a string to a `Pasteboard` protocol, remembers the change count, and after a delay clears it only if the change count is unchanged. Marks the item with `org.nspasteboard.ConcealedType` and `org.nspasteboard.TransientType`. Clock/scheduler is injectable for tests. |
| `AuthGate` | Tracks "last successful authentication" time; `needsAuthentication(now:)` is true when more than 5 minutes have passed. The actual prompt is supplied by the app via a closure. |

### 4.2 `MacVault` (executable app)

| Unit | Purpose |
| --- | --- |
| `AppDelegate` | Creates the `NSStatusItem` (SF Symbol `key.fill`) and an `NSPopover` hosting `VaultView`; toggles the popover on click; sets the app to accessory activation policy. |
| `HotKey` | Registers ⌥⌘P with Carbon `RegisterEventHotKey` (no Accessibility permission needed) and calls back to toggle the popover. |
| `VaultViewModel` | `ObservableObject` holding the logins, the search text and the selected screen; calls `LoginStore`, `AuthGate`, `ClipboardGuard`. Shows errors as a banner message. |
| `VaultView` | Search field (focused on open), list of rows, "+ New" button, footer with "Quit". |
| `LoginRow` | Title, username, buttons: copy username, copy password, edit. |
| `LoginEditor` | Form: name, username, password (hidden by default, reveal requires auth), Generate button with length slider and symbol/digit toggles, website. Save / Cancel / Delete (with confirmation). |
| `DeviceAuthenticator` | Wraps `LAContext.evaluatePolicy(.deviceOwnerAuthentication)` — Touch ID if available, otherwise the Mac password. |

`build.sh` runs `swift build -c release`, assembles `MacVault.app` with an
`Info.plist` (`LSUIElement = true`, bundle id `local.macvault.app`),
ad-hoc signs it with `codesign --sign -`, and prints where it is.

## 5. Data flow

- **Open popover:** `list()` → filter → render. No auth.
- **Copy username:** `ClipboardGuard.copy(username, clearAfter: nil)`.
- **Copy password:** if `AuthGate` needs auth → `DeviceAuthenticator`; on
  success → `password(for:)` → `ClipboardGuard.copy(password, clearAfter: 30s)`
  → popover closes and a short "Copied" confirmation flashes first.
- **Save:** validate (title and password non-empty) → `save` → reload list.
- **Delete:** confirm → `delete` → reload list.

## 6. Error handling

- Keychain errors map to a `LoginStoreError` with a readable message
  (`SecCopyErrorMessageString`), shown in a banner at the top of the popover.
- Cancelled Touch ID/password prompt: nothing happens, no banner.
- Corrupt metadata on a keychain item: the item is listed with its account
  UUID as the title so it can still be opened and deleted.

## 7. Testing

- XCTest unit tests in `MacVaultCoreTests` for `PasswordGenerator`,
  `LoginFilter`, `ClipboardGuard`, `AuthGate`, `InMemoryLoginStore`, and
  `KeychainLoginStore` (the latter against the real keychain with a
  test-only service name, cleaned up after each test).
- Manual checklist in `macvault/README.md` for the UI: menu bar icon,
  hotkey, add/edit/delete, copy with Touch ID, clipboard clearing.
