import AppKit
import Carbon.HIToolbox
import MacVaultCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var hotKey: HotKey?
    private var model: VaultViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let model = VaultViewModel(
            store: KeychainLoginStore(),
            gate: AuthGate(authenticator: DeviceAuthenticator()),
            clipboard: ClipboardGuard(pasteboard: SystemPasteboard(), scheduler: DispatchScheduler())
        )
        model.onCopiedPassword = { [weak self] in self?.closePopover() }
        self.model = model

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 360, height: 440)
        popover.contentViewController = NSHostingController(rootView: VaultView(model: model))

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "key.fill", accessibilityDescription: "MacVault")
            button.target = self
            button.action = #selector(togglePopover(_:))
        }
        statusItem = item

        hotKey = HotKey(keyCode: UInt32(kVK_ANSI_P), modifiers: UInt32(optionKey | cmdKey)) { [weak self] in
            self?.togglePopover(nil)
        }
        if hotKey == nil {
            NSLog("MacVault: ⌥⌘P is already used by another app; the shortcut is disabled.")
        }
    }

    @objc private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem?.button else { return }
        model?.prepareForShow()
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func closePopover() {
        popover.performClose(nil)
    }
}
