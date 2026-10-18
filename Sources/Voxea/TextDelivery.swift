import AppKit
import Carbon

@MainActor struct InsertionTarget {
    let pid: pid_t
    let element: AXUIElement
    // Stable fingerprint of the captured field. Chromium/Electron AX element
    // identity is not stable across tree walks, so stillFocused() compares a
    // (pid, role, approx-position) signature instead of element identity.
    let fingerprint: String

    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }
    private static func isProtected(_ element: AXUIElement) -> Bool {
        var current = element
        for _ in 0..<16 {
            if attribute(current, kAXSubroleAttribute) as? String == kAXSecureTextFieldSubrole
                || attribute(current, "AXProtectedContent") as? Bool == true { return true }
            guard let parent = attribute(current, kAXParentAttribute), CFGetTypeID(parent) == AXUIElementGetTypeID() else { break }
            current = parent as! AXUIElement
        }
        return false
    }
    // An element we can actually write text into.
    private static func qualifies(_ element: AXUIElement) -> Bool {
        if isProtected(element) { return false }
        if attribute(element, kAXEnabledAttribute) as? Bool == false { return false }
        if attribute(element, "AXReadOnly") as? Bool == true { return false }
        let role = attribute(element, kAXRoleAttribute) as? String ?? ""
        var settable = DarwinBoolean(false)
        AXUIElementIsAttributeSettable(element, kAXSelectedTextAttribute as CFString, &settable)
        return [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole].contains(role)
            || attribute(element, "AXEditable") as? Bool == true || settable.boolValue
    }
    private static func position(of element: AXUIElement) -> CGPoint? {
        guard let raw = attribute(element, "AXPosition"), CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(raw as! AXValue, .cgPoint, &point) else { return nil }
        return point
    }
    private static func computeFingerprint(of element: AXUIElement, pid: pid_t) -> String {
        let role = attribute(element, kAXRoleAttribute) as? String ?? "?"
        // 8-px bucket: a re-walk that lands on the *same* field still matches.
        if let p = position(of: element) {
            return "\(pid)|\(role)|\(Int(p.x / 8))|\(Int(p.y / 8))"
        }
        return "\(pid)|\(role)|?|?"
    }

    // Chromium/Electron gate their entire accessibility tree behind this flag.
    // Without it, AXFocusedUIElement / AXWindows expose no editable node, so we
    // cannot even find the composer (e.g. ChatGPT Desktop). Safe for native apps.
    private static func enableAccessibility(on application: AXUIElement) {
        AXUIElementSetAttributeValue(application, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
    }

    // Deepest editable text node in the window tree. Used when the OS focused
    // element is a wrapper/AXButton (typical of web apps) instead of the composer.
    private static func deepestEditor(in application: AXUIElement) -> AXUIElement? {
        guard let windows = attribute(application, kAXWindowsAttribute) as? [AXUIElement] else { return nil }
        var best: AXUIElement?
        var bestDepth = 0
        func walk(_ node: AXUIElement, depth: Int) {
            let role = attribute(node, kAXRoleAttribute) as? String ?? ""
            var settable = DarwinBoolean(false)
            AXUIElementIsAttributeSettable(node, kAXSelectedTextAttribute as CFString, &settable)
            let editable = attribute(node, "AXEditable") as? Bool == true
            if [kAXTextAreaRole, kAXTextFieldRole, kAXComboBoxRole].contains(role)
                && (settable.boolValue || editable) && !isProtected(node) && depth >= bestDepth {
                bestDepth = depth
                best = node
            }
            if let children = attribute(node, "AXChildren") as? [AXUIElement] {
                for child in children { walk(child, depth: depth + 1) }
            }
        }
        for window in windows { walk(window, depth: 0) }
        return best
    }

    static func capture() -> Self? {
        guard AXIsProcessTrusted(), let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let application = AXUIElementCreateApplication(app.processIdentifier)
        // Web apps expose their tree only after this flag.
        enableAccessibility(on: application)

        // 1) Fast path: the OS focused element is already editable (native apps
        //    like TextEdit). This is the original behavior and stays unchanged.
        if let focused = attribute(application, kAXFocusedUIElementAttribute),
           CFGetTypeID(focused) == AXUIElementGetTypeID() {
            let element = focused as! AXUIElement
            if qualifies(element) {
                return Self(pid: app.processIdentifier, element: element,
                           fingerprint: computeFingerprint(of: element, pid: app.processIdentifier))
            }
        }
        // 2) Fallback: the focused element is a wrapper/AXButton (Chromium/Electron,
        //    e.g. ChatGPT Desktop). Recover the composer from the window tree.
        if let element = deepestEditor(in: application), qualifies(element) {
            return Self(pid: app.processIdentifier, element: element,
                       fingerprint: computeFingerprint(of: element, pid: app.processIdentifier))
        }
        return nil
    }

    func stillFocused() -> Bool {
        guard let current = Self.capture() else { return false }
        return Self.computeFingerprint(of: current.element, pid: current.pid) == fingerprint
    }

    var isWebField: Bool {
        // 1) Tolerant climb: a web field sits under an AXWebArea (some Chromium
        //    builds rebuild the tree when the flag is set, so be generous).
        var current = element
        for _ in 0..<28 {
            if Self.attribute(current, kAXRoleAttribute) as? String == "AXWebArea" { return true }
            guard let parent = Self.attribute(current, kAXParentAttribute), CFGetTypeID(parent) == AXUIElementGetTypeID() else { break }
            current = parent as! AXUIElement
        }
        // 2) Chromium/Electron gate their whole tree behind a web area that
        //    isn't always walkable right after the flag is set, so also detect
        //    the owning app by its bundle id (deterministic for ChatGPT).
        if let bid = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier {
            if bid == "com.openai.codex" || bid == "com.openai.chatgpt"
                || bid.hasSuffix(".web") || bid.contains("chromium")
                || bid.hasPrefix("com.electron.") {
                return true
            }
        }
        return false
    }
    // Left for native-app direct writes; NOT used by the deliver path (⌘V is used
    // instead because web editors report success without applying the change).
    func insertDirectly(_ text: String) -> Bool {
        guard stillFocused() else { return false }
        return AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFString) == .success
    }
    func sendPaste() -> Bool {
        guard stillFocused(), let source = CGEventSource(stateID: .privateState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false) else { return false }
        down.flags = .maskCommand; up.flags = .maskCommand
        // Use the normal session event route so native and web editors process Cmd+V.
        // The exact focused field was validated above; never activate another app.
        down.post(tap: .cgSessionEventTap); up.post(tap: .cgSessionEventTap)
        return true
    }
    // Read back the composer content for post-paste confirmation.
    func currentValue() -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value) == .success else { return nil }
        return value as? String
    }
}

@MainActor enum TextDelivery {
    enum Method: String { case direct, paste, clipboard, unavailable, empty, confirmed }
    struct Result {
        let method: Method
        let copied: Bool
        let message: String
    }
    static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
    private static func clipboardSnapshot() -> [NSPasteboardItem] {
        (NSPasteboard.general.pasteboardItems ?? []).map { item in
            let clone = NSPasteboardItem()
            for type in item.types { if let data = item.data(forType: type) { clone.setData(data, forType: type) } }
            return clone
        }
    }
    // Last 40 chars of delivered text, used to confirm the paste actually landed.
    private static func suffixProbe(_ text: String) -> String {
        let chars = Array(text)
        return String(chars.suffix(40))
    }
    static func deliver(_ text: String, to target: InsertionTarget?, insert: Bool, keepCopy: Bool) async -> Result {
        guard !text.isEmpty else { return Result(method: .empty, copied: false, message: "Aucune parole reconnue.") }
        // Copy even when the target is gone, unsupported, or access has been revoked.
        if keepCopy { copy(text) }
        guard insert else { return Result(method: .clipboard, copied: keepCopy, message: keepCopy ? "Texte copié · coller avec ⌘V" : "Texte conservé dans Voxea.") }
        guard let target, target.stillFocused() else {
            let reason = AXIsProcessTrusted() ? "Champ changé, protégé ou non éditable." : "Activer l’autorisation Accessibilité de Voxea."
            return Result(method: .unavailable, copied: keepCopy, message: keepCopy ? "Texte copié · coller avec ⌘V. \(reason)" : "Texte conservé. \(reason)")
        }
        // Always paste: some editors report AXSelectedText success without updating
        // the visible text or their internal state. Never treat that as confirmed insertion.
        // Let shortcut modifiers settle, then recheck the exact field before pasting.
        try? await Task.sleep(nanoseconds: 100_000_000)
        guard target.stillFocused() else {
            return Result(method: .unavailable, copied: keepCopy, message: keepCopy ? "Texte copié · champ changé, coller avec ⌘V." : "Champ changé · texte conservé dans Voxea.")
        }
        let saved = keepCopy ? [] : clipboardSnapshot()
        copy(text)
        let pasteChange = NSPasteboard.general.changeCount
        let sent = target.sendPaste()
        // Confirm by reading back the composer. A Cmd+V that did not change the
        // value did not land; we never claim confirmation on that, but we also
        // never downgrade a sent paste to failure just because the read-back
        // (best-effort on some web fields) could not confirm it.
        var method: Method = .paste
        if sent {
            try? await Task.sleep(nanoseconds: 350_000_000)
            if let after = target.currentValue(), !after.isEmpty, after.contains(suffixProbe(text)) {
                method = .confirmed
            }
        } else {
            method = .unavailable
        }
        if !keepCopy {
            try? await Task.sleep(nanoseconds: 900_000_000)
            // Never overwrite something the user copied after the dictation.
            if NSPasteboard.general.changeCount == pasteChange {
                NSPasteboard.general.clearContents()
                if !saved.isEmpty { NSPasteboard.general.writeObjects(saved) }
            }
        }
        let message: String
        switch method {
        case .confirmed:
            message = keepCopy ? "Collage confirmé · texte copié" : "Collage confirmé"
        case .paste:
            message = keepCopy ? "Collage envoyé · texte copié" : "Collage envoyé"
        case .unavailable:
            message = keepCopy ? "Texte copié · coller avec ⌘V." : "Insertion impossible · texte conservé dans Voxea."
        default:
            message = "Texte conservé dans Voxea."
        }
        return Result(method: method, copied: keepCopy, message: message)
    }
}
