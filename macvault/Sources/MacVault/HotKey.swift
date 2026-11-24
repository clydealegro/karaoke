import Carbon.HIToolbox

/// A system-wide keyboard shortcut via Carbon's RegisterEventHotKey.
/// Unlike an NSEvent global monitor, it needs no Accessibility permission.
final class HotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let action: () -> Void

    /// Returns nil if the shortcut is already taken by another app.
    init?(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        self.action = action

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = Unmanaged.passUnretained(self).toOpaque()
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue().action()
                return OSStatus(noErr)
            },
            1,
            &eventType,
            userData,
            &handlerRef
        )
        guard installStatus == OSStatus(noErr) else { return nil }

        let hotKeyID = EventHotKeyID(signature: OSType(0x4D56_4C54), id: 1) // "MVLT"
        let registerStatus = RegisterEventHotKey(
            keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef
        )
        guard registerStatus == OSStatus(noErr) else { return nil }
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
