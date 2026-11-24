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
        installEditMenu()

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
        // Deprecated on macOS 14, but the newer cooperative NSApp.activate()
        // can be refused when triggered from the global hotkey.
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        // Focus once the popover window is actually key.
        DispatchQueue.main.async { [weak self] in
            self?.model?.requestSearchFocus()
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        // Hand focus back to the previous app so ⌘V pastes there right away.
        NSApp.hide(nil)
    }

    /// Never shown (accessory app), but AppKit routes ⌘X/⌘C/⌘V/⌘A/⌘Z in text
    /// fields through the main menu's Edit items.
    private func installEditMenu() {
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let editItem = NSMenuItem()
        editItem.submenu = edit
        let mainMenu = NSMenu()
        mainMenu.addItem(editItem)
        NSApp.mainMenu = mainMenu
    }
}
