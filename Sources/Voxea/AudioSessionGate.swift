// Accessed under Microphone's lock. A cancelled startup must never stop a newer
// recording after its asynchronous engine startup returns.
struct AudioSessionGate {
    private(set) var generation: UInt64 = 0
    private(set) var acceptingAudio = false
    mutating func begin() -> UInt64 {
        generation &+= 1
        acceptingAudio = false
        return generation
    }
    mutating func activate(_ ticket: UInt64) -> Bool {
        guard ticket == generation else { return false }
        acceptingAudio = true
        return true
    }
    @discardableResult mutating func stop(expectedGeneration: UInt64? = nil) -> Bool {
        if let expectedGeneration, expectedGeneration != generation { return false }
        generation &+= 1
        acceptingAudio = false
        return true
    }
}
