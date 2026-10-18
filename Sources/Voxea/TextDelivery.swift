import AppKit
import Carbon

@MainActor struct InsertionTarget {
    let pid: pid_t
    let element: AXUIElement
    let window: AXUIElement
    let fingerprint: String // Diagnostic only; geometry is never proof of focus.
    let initialValue: String?
    let initialSelection: NSRange?

    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, name as CFString, &value)
        return result == .success ? value : nil
    }
    private static func node(_ element: AXUIElement, _ name: String) -> AXUIElement? {
        guard let value = attribute(element, name), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }
    private static func isProtected(_ element: AXUIElement) -> Bool {
        var current = element
        for _ in 0..<64 {
            if attribute(current, kAXSubroleAttribute) as? String == kAXSecureTextFieldSubrole
                || attribute(current, "AXProtectedContent") as? Bool == true { return true }
            guard let parent = node(current, kAXParentAttribute) else { return false }
            current = parent
        }
        return true // An unbounded/cyclic ancestry is not safe to write into.
    }
    private static func qualifies(_ element: AXUIElement) -> Bool {
        guard !isProtected(element), attribute(element, kAXEnabledAttribute) as? Bool != false,
              attribute(element, "AXReadOnly") as? Bool != true else { return false }
        let role = attribute(element, kAXRoleAttribute) as? String ?? ""
        var settable = DarwinBoolean(false)
        AXUIElementIsAttributeSettable(element, kAXSelectedTextAttribute as CFString, &settable)
        return [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole].contains(role)
            || attribute(element, "AXEditable") as? Bool == true || settable.boolValue
    }
    private static func selection(_ element: AXUIElement) -> NSRange? {
        guard let raw = attribute(element, kAXSelectedTextRangeAttribute), CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        var range = CFRange()
        guard AXValueGetValue(raw as! AXValue, .cfRange, &range), range.location >= 0, range.length >= 0 else { return nil }
        return NSRange(location: range.location, length: range.length)
    }
    // Only recover an explicitly focused editor, in the active window. Never
    // choose the deepest editor, or infer focus from a matching screen position.
    private static func focusedEditor(in window: AXUIElement) -> AXUIElement? {
        var stack: [(AXUIElement, Int)] = [(window, 0)]
        var candidates: [AXUIElement] = []
        var visited = 0
        let deadline = Date().addingTimeInterval(0.7)
        while let (item, depth) = stack.popLast() {
            visited += 1
            guard visited <= 600, depth <= 40, Date() < deadline else {
                Diagnostics.log("capture search exhausted nodes=\(visited)"); return nil
            }
            if isProtected(item) { continue }
            if attribute(item, kAXFocusedAttribute) as? Bool == true, qualifies(item) { candidates.append(item) }
            if let children = attribute(item, kAXChildrenAttribute) as? [AXUIElement] {
                stack.append(contentsOf: children.map { ($0, depth + 1) })
            }
        }
        Diagnostics.log("capture focusedCandidates=\(candidates.count) nodes=\(visited)")
        return candidates.count == 1 ? candidates[0] : nil
    }
    static func capture() -> Self? {
        guard AXIsProcessTrusted() else { Diagnostics.log("capture denied reason=accessibility"); return nil }
        guard let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != getpid() else {
            Diagnostics.log("capture denied reason=noExternalApp"); return nil
        }
        let application = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(application, 0.2)
        // Enable once at capture; repeatedly enabling during validation can
        // rebuild Chromium's tree and invalidate the captured editor.
        let enhanced = AXUIElementSetAttributeValue(application, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
        guard let window = node(application, kAXFocusedWindowAttribute) else {
            Diagnostics.log("capture denied reason=noFocusedWindow enhanced=\(enhanced.rawValue)"); return nil
        }
        let focused = node(application, kAXFocusedUIElementAttribute)
        Diagnostics.log("capture role=\(focused.flatMap { attribute($0, kAXRoleAttribute) as? String } ?? "nil") enhanced=\(enhanced.rawValue)")
        if let focused, isProtected(focused) { Diagnostics.log("capture denied reason=protected"); return nil }
        let editor = focused.flatMap { qualifies($0) ? $0 : nil } ?? focusedEditor(in: window)
        guard let editor else { Diagnostics.log("capture denied reason=noUnambiguousFocusedEditor"); return nil }
        let role = attribute(editor, kAXRoleAttribute) as? String ?? "?"
        return Self(pid: app.processIdentifier, element: editor, window: window,
                    fingerprint: "\(app.processIdentifier)|\(role)",
                    initialValue: attribute(editor, kAXValueAttribute) as? String,
                    initialSelection: selection(editor))
    }
    func stillFocused() -> Bool {
        guard AXIsProcessTrusted() else { Diagnostics.log("focus denied reason=accessibility"); return false }
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else {
            Diagnostics.log("focus denied reason=applicationChanged expected=\(pid)"); return false
        }
        let application = AXUIElementCreateApplication(pid)
        guard let activeWindow = Self.node(application, kAXFocusedWindowAttribute), CFEqual(activeWindow, window) else {
            Diagnostics.log("focus denied reason=windowChanged"); return false
        }
        guard Self.qualifies(element) else { Diagnostics.log("focus denied reason=protectedOrUnavailable"); return false }
        let focused = Self.node(application, kAXFocusedUIElementAttribute)
        if let focused, Self.isProtected(focused) { Diagnostics.log("focus denied reason=protectedFocus"); return false }
        // AX identity is required. PID/role/position can collide between fields.
        if let focused, CFEqual(focused, element) { return true }
        guard let recovered = Self.focusedEditor(in: activeWindow), CFEqual(recovered, element) else {
            Diagnostics.log("focus denied reason=editorChangedOrAmbiguous"); return false
        }
        return true
    }
    func unchanged() -> Bool {
        let matches = (initialValue == nil || currentValue() == initialValue)
            && (initialSelection == nil || Self.selection(element) == initialSelection)
        if !matches { Diagnostics.log("focus denied reason=valueOrSelectionChanged") }
        return matches
    }
    var isWebField: Bool {
        var current = element
        for _ in 0..<64 {
            if Self.attribute(current, kAXRoleAttribute) as? String == "AXWebArea" { return true }
            guard let parent = Self.node(current, kAXParentAttribute) else { break }
            current = parent
        }
        let bundle = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier ?? ""
        return bundle == "com.openai.codex" || bundle == "com.openai.chatgpt"
    }
    func sendPaste() -> Bool {
        guard stillFocused(), unchanged(), TextDelivery.modifiersReleased,
              let source = CGEventSource(stateID: .privateState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false) else {
            Diagnostics.log("paste notSent reason=focusOrModifiers"); return false
        }
        down.flags = .maskCommand; up.flags = .maskCommand
        down.post(tap: .cgSessionEventTap); up.post(tap: .cgSessionEventTap)
        Diagnostics.log("paste posted")
        return true
    }
    func currentValue() -> String? { Self.attribute(element, kAXValueAttribute) as? String }
    func confirms(_ text: String, before: String?, after: String?) -> Bool {
        guard let before, let after, after != before else { return false }
        if let range = initialSelection, NSMaxRange(range) <= (before as NSString).length {
            return after == (before as NSString).replacingCharacters(in: range, with: text)
        }
        // Some editors cannot expose the selection. Require a changed value and
        // the complete dictated text, never just an already-present suffix.
        return after.contains(text) && after.utf16.count >= text.utf16.count
    }
}

@MainActor enum TextDelivery {
    enum Method: String { case direct, paste, clipboard, unavailable, empty, confirmed }
    struct Result { let method: Method; let copied: Bool; let message: String }
    static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
    static var modifiersReleased: Bool {
        let modifiers: CGEventFlags = [.maskControl, .maskShift, .maskAlternate, .maskCommand]
        return CGEventSource.flagsState(.combinedSessionState).intersection(modifiers).isEmpty
    }
    private static func clipboardSnapshot() -> [NSPasteboardItem]? {
        var result: [NSPasteboardItem] = []
        let start = NSPasteboard.general.changeCount
        for item in NSPasteboard.general.pasteboardItems ?? [] {
            let clone = NSPasteboardItem()
            for type in item.types {
                guard let data = item.data(forType: type), clone.setData(data, forType: type) else { return nil }
            }
            result.append(clone)
        }
        return NSPasteboard.general.changeCount == start ? result : nil
    }
    // Confirmation proves that the editor has already consumed the clipboard.
    // Otherwise preserve the original 900 ms read window, counted from posting,
    // rather than adding it after the polling window has already elapsed.
    static func clipboardGrace(confirmed: Bool, elapsed: TimeInterval) -> TimeInterval {
        confirmed ? 0 : max(0, 0.9 - max(0, elapsed))
    }
    static func deliver(_ text: String, to target: InsertionTarget?, insert: Bool, keepCopy: Bool,
                        onPasteSent: (() -> Void)? = nil) async -> Result {
        Diagnostics.log("deliver insert=\(insert) keepCopy=\(keepCopy) target=\(target?.fingerprint ?? "nil") chars=\(text.count)")
        guard !text.isEmpty else { return Result(method: .empty, copied: false, message: "Aucune parole reconnue.") }
        // Copying permanently is an explicit setting, disabled by default.
        if keepCopy { copy(text) }
        func unavailable(_ reason: String) -> Result {
            Diagnostics.log("deliver unavailable reason=\(reason)")
            return Result(method: .unavailable, copied: keepCopy,
                          message: (keepCopy ? "Texte copié. " : "Texte conservé dans Voxea. ") + reason)
        }
        guard insert else { return Result(method: .clipboard, copied: keepCopy, message: keepCopy ? "Texte copié · coller avec ⌘V" : "Texte conservé dans Voxea.") }
        guard AXIsProcessTrusted() else { return unavailable("Autoriser Voxea dans Réglages système > Confidentialité et sécurité > Accessibilité.") }
        guard let target else { return unavailable("Aucun champ capturé au début de la dictée. Cliquez dans le champ puis recommencez.") }
        // Key-up for W can arrive while Ctrl/Shift are still physically held.
        // Wait for actual release, rather than assuming 100 ms is sufficient.
        let deadline = Date().addingTimeInterval(3)
        repeat {
            guard target.stillFocused(), target.unchanged() else { return unavailable("Champ ou sélection modifié pendant la dictée.") }
            if modifiersReleased {
                try? await Task.sleep(nanoseconds: 60_000_000)
                if modifiersReleased { break }
            } else { try? await Task.sleep(nanoseconds: 40_000_000) }
        } while Date() < deadline
        guard modifiersReleased else { return unavailable("Relâchez les touches du raccourci avant le collage.") }
        guard target.stillFocused(), target.unchanged() else { return unavailable("Champ modifié avant le collage.") }
        guard let saved = keepCopy ? [] : clipboardSnapshot() else { return unavailable("Presse-papiers indisponible ; il a été préservé.") }
        let before = target.currentValue()
        copy(text)
        let pasteChange = NSPasteboard.general.changeCount
        let sent = target.sendPaste()
        let postedAt = ProcessInfo.processInfo.systemUptime
        if sent { onPasteSent?() }
        var confirmed = false
        if sent {
            for _ in 0..<12 {
                try? await Task.sleep(nanoseconds: 100_000_000)
                guard target.stillFocused() else { break }
                if target.confirms(text, before: before, after: target.currentValue()) { confirmed = true; break }
            }
        }
        if !keepCopy {
            // Give consumers time to read a posted paste, including editors whose
            // AXValue is unavailable. Do not retry paste and risk duplicating it.
            if sent {
                let remaining = clipboardGrace(confirmed: confirmed, elapsed: ProcessInfo.processInfo.systemUptime - postedAt)
                if remaining > 0 { try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000)) }
            }
            if NSPasteboard.general.changeCount == pasteChange {
                NSPasteboard.general.clearContents()
                if !saved.isEmpty { NSPasteboard.general.writeObjects(saved) }
                Diagnostics.log("clipboard restored items=\(saved.count)")
            } else { Diagnostics.log("clipboard restore skipped reason=newCopy") }
        }
        Diagnostics.log("paste sent=\(sent) confirmed=\(confirmed) beforeChars=\(before?.count ?? -1) afterChars=\(target.currentValue()?.count ?? -1)")
        return Result(method: confirmed ? .confirmed : (sent ? .paste : .unavailable), copied: keepCopy,
                      message: confirmed ? "Insertion vérifiée dans le champ." : (sent ? "Collage envoyé, insertion non confirmée · texte disponible dans Voxea." : "Collage annulé · texte disponible dans Voxea."))
    }
}
