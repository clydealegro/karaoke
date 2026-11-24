import AppKit
import LocalAuthentication
import MacVaultCore

/// `NSPasteboard.general` behind the core `Pasteboard` protocol.
final class SystemPasteboard: Pasteboard {
    private let pasteboard = NSPasteboard.general
    // Conventions from nspasteboard.org honoured by clipboard managers.
    private let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    private let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")

    var changeCount: Int { pasteboard.changeCount }

    func write(_ string: String, concealed: Bool) -> Int {
        pasteboard.clearContents()
        let item = NSPasteboardItem()
        item.setString(string, forType: .string)
        if concealed {
            item.setString("", forType: concealedType)
            item.setString("", forType: transientType)
        }
        pasteboard.writeObjects([item])
        return pasteboard.changeCount
    }

    func clear() {
        pasteboard.clearContents()
    }
}

/// Touch ID when available, otherwise the Mac login password.
@MainActor
final class DeviceAuthenticator: Authenticator {
    func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // A Mac account with no login password has nothing to check against.
            return error?.code == LAError.Code.passcodeNotSet.rawValue
        }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }
}
