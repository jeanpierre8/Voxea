import AppKit
import Carbon

@MainActor final class Hotkey {
    private var reference: EventHotKeyRef?
    private var escape: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var callback: ((Bool, Bool) -> Void)?
    init() {
        var types = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)), EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))]
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            let object = Unmanaged<Hotkey>.fromOpaque(context).takeUnretainedValue()
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            guard id.signature == 0x44494354 else { return OSStatus(eventNotHandledErr) }
            object.callback?(GetEventKind(event) == UInt32(kEventHotKeyPressed), id.id == 2)
            return noErr
        }, types.count, &types, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }
    func register(key: UInt32, modifiers: UInt32) throws {
        if let reference { UnregisterEventHotKey(reference); self.reference = nil }
        let result = RegisterEventHotKey(key, modifiers, EventHotKeyID(signature: 0x44494354, id: 1), GetApplicationEventTarget(), 0, &reference)
        guard result == noErr else { throw PrototypeError.message("Raccourci indisponible (\(result)). Choisir une autre combinaison.") }
    }
    func captureEscape(_ enabled: Bool) {
        if let escape { UnregisterEventHotKey(escape); self.escape = nil }
        if enabled { RegisterEventHotKey(UInt32(kVK_Escape), 0, EventHotKeyID(signature: 0x44494354, id: 2), GetApplicationEventTarget(), 0, &escape) }
    }
}

