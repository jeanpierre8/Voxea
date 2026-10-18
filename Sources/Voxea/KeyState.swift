struct KeyState {
    enum Action: Equatable { case start, stop, cancel }
    var pressed = false
    var recording = false
    mutating func event(down: Bool, toggle: Bool) -> Action? {
        if down {
            guard !pressed else { return nil }
            pressed = true
            if toggle && recording { recording = false; return .stop }
            recording = true; return .start
        }
        guard pressed else { return nil }
        pressed = false
        if !toggle && recording { recording = false; return .stop }
        return nil
    }
    mutating func cancel() { recording = false }
}

