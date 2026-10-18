import Carbon

struct ShortcutChoice: Identifiable {
    let title: String
    let value: Int
    var id: Int { value }
}

enum ShortcutChoices {
    // Carbon registers physical key codes. Resolve letter labels using the actual
    // layout: for example W is code 6 on this French keyboard, not ANSI code 13.
    private static let letterCodes: [String: Int] = {
        guard let input = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let property = TISGetInputSourceProperty(input, kTISPropertyUnicodeKeyLayoutData) else { return [:] }
        let data = unsafeBitCast(property, to: CFData.self)
        defer { withExtendedLifetime(data) {} }
        guard let bytes = CFDataGetBytePtr(data) else { return [:] }
        let layout = UnsafeRawPointer(bytes).assumingMemoryBound(to: UCKeyboardLayout.self)
        var result: [String: Int] = [:]
        for code in 0..<128 {
            var deadState: UInt32 = 0
            var count = 0
            var characters = [UniChar](repeating: 0, count: 8)
            let status = UCKeyTranslate(layout, UInt16(code), UInt16(kUCKeyActionDisplay), 0,
                                        UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysMask),
                                        &deadState, 8, &count, &characters)
            guard status == noErr, count == 1 else { continue }
            let title = String(utf16CodeUnits: characters, count: Int(count)).uppercased()
            if title.range(of: "^[A-Z]$", options: .regularExpression) != nil, result[title] == nil { result[title] = code }
        }
        return result
    }()

    static let modifiers: [ShortcutChoice] = (1..<16).map { mask in
        let flags = [("⌃", Int(controlKey)), ("⌥", Int(optionKey)), ("⇧", Int(shiftKey)), ("⌘", Int(cmdKey))]
        let selected = flags.enumerated().filter { mask & (1 << $0.offset) != 0 }.map { $0.element }
        return ShortcutChoice(title: selected.map { $0.0 }.joined(separator: " "), value: selected.reduce(0) { $0 | $1.1 })
    }
    static let keys: [ShortcutChoice] = [
        ("Espace", kVK_Space),
        ("A", kVK_ANSI_A), ("B", kVK_ANSI_B), ("C", kVK_ANSI_C), ("D", kVK_ANSI_D),
        ("E", kVK_ANSI_E), ("F", kVK_ANSI_F), ("G", kVK_ANSI_G), ("H", kVK_ANSI_H),
        ("I", kVK_ANSI_I), ("J", kVK_ANSI_J), ("K", kVK_ANSI_K), ("L", kVK_ANSI_L),
        ("M", kVK_ANSI_M), ("N", kVK_ANSI_N), ("O", kVK_ANSI_O), ("P", kVK_ANSI_P),
        ("Q", kVK_ANSI_Q), ("R", kVK_ANSI_R), ("S", kVK_ANSI_S), ("T", kVK_ANSI_T),
        ("U", kVK_ANSI_U), ("V", kVK_ANSI_V), ("W", kVK_ANSI_W), ("X", kVK_ANSI_X),
        ("Y", kVK_ANSI_Y), ("Z", kVK_ANSI_Z),
        ("0", kVK_ANSI_0), ("1", kVK_ANSI_1), ("2", kVK_ANSI_2), ("3", kVK_ANSI_3),
        ("4", kVK_ANSI_4), ("5", kVK_ANSI_5), ("6", kVK_ANSI_6), ("7", kVK_ANSI_7),
        ("8", kVK_ANSI_8), ("9", kVK_ANSI_9)
    ].map { ShortcutChoice(title: $0.0, value: letterCodes[$0.0] ?? Int($0.1)) } +
    [kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
     kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20]
        .enumerated().map { ShortcutChoice(title: "F\($0.offset + 1)", value: Int($0.element)) }
}
