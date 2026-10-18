import AVFoundation
import Foundation

// The audio callback owns the converter; the UI reads bounded snapshots under a lock.
final class Microphone: @unchecked Sendable {
    private let engine = AVAudioEngine()
    // Engine teardown can wait on Core Audio. Serialize hardware operations away
    // from the main thread so recognition/delivery need not wait for teardown.
    private let engineQueue = DispatchQueue(label: "local.jp.voxea.audio-engine", qos: .userInitiated)
    private var gate = AudioSessionGate()
    private let lock = NSLock()
    private var samples: [Float] = []
    private var level: Float = 0
    private var failure: String?
    private var tapped = false
    private var testAudio: [Float]?
    private var testStart: Date?
    func startTest(_ audio: [Float]) {
        clear()
        lock.lock(); testAudio = Array(audio.prefix(Self.limit)); testStart = Date(); lock.unlock()
    }
    static let limit = 60 * 16000
    func snapshot() -> (samples: [Float], level: Float, failure: String?) {
        lock.lock(); defer { lock.unlock() }
        if let testAudio, let testStart {
            let count = min(testAudio.count, Int(Date().timeIntervalSince(testStart) * 16000))
            let prefix = Array(testAudio.prefix(count))
            let tail = prefix.suffix(800)
            let rms = sqrt(tail.reduce(Float(0)) { $0 + $1 * $1 } / Float(max(1, tail.count)))
            return (prefix, min(1, max(0, (20 * log10(max(rms, 0.00001)) + 60) / 60)), nil)
        }
        return (samples, level, failure)
    }
    private func prepareStart() -> UInt64 {
        clear()
        lock.lock(); defer { lock.unlock() }
        return gate.begin()
    }
    func start() async throws -> UInt64 {
        let ticket = prepareStart()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            engineQueue.async { [self] in
                do { try startEngine(ticket: ticket); continuation.resume() }
                catch { continuation.resume(throwing: error) }
            }
        }
        return ticket
    }
    private func startEngine(ticket: UInt64) throws {
        lock.lock(); let valid = gate.generation == ticket; lock.unlock()
        guard valid else { throw CancellationError() }
        stopEngine()
        let input = engine.inputNode
        let source = input.outputFormat(forBus: 0)
        guard source.sampleRate > 0, source.channelCount > 0,
              let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: source, to: target)
        else { throw PrototypeError.message("Aucune entrée microphone disponible.") }
        input.installTap(onBus: 0, bufferSize: 2048, format: source) { [weak self] buffer, _ in
            guard let self else { return }
            // Finish an in-flight conversion before key release freezes the
            // buffer; avoid dropping the tail of a frame already being captured.
            self.lock.lock(); defer { self.lock.unlock() }
            guard self.gate.acceptingAudio else { return }
            let capacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * 16000 / source.sampleRate) + 64)
            guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }
            var supplied = false
            var error: NSError?
            let status = converter.convert(to: output, error: &error) { _, state in
                if supplied { state.pointee = .noDataNow; return nil }
                supplied = true; state.pointee = .haveData; return buffer
            }
            if status == .error { self.failure = error?.localizedDescription ?? "Conversion audio impossible."; return }
            guard let channel = output.floatChannelData?[0] else { return }
            let data = Array(UnsafeBufferPointer(start: channel, count: Int(output.frameLength)))
            self.samples.append(contentsOf: data.prefix(max(0, Self.limit - self.samples.count)))
            let rms = sqrt(data.reduce(Float(0)) { $0 + $1 * $1 } / Float(max(1, data.count)))
            self.level = min(1, max(0, (20 * log10(max(rms, 0.00001)) + 60) / 60))
        }
        tapped = true
        lock.lock()
        let stillValid = gate.activate(ticket)
        lock.unlock()
        guard stillValid else { stopEngine(); throw CancellationError() }
        do { engine.prepare(); try engine.start() }
        catch {
            lock.lock(); gate.stop(expectedGeneration: ticket); lock.unlock()
            stopEngine(); throw error
        }
    }
    func stop(expectedGeneration: UInt64? = nil) {
        // Freeze the audio at key release before returning. Late tap callbacks
        // cannot extend this recording or contaminate the following one.
        lock.lock(); let shouldStop = gate.stop(expectedGeneration: expectedGeneration); lock.unlock()
        guard shouldStop else { return }
        let requestedAt = ProcessInfo.processInfo.systemUptime
        engineQueue.async { [self] in
            stopEngine()
            let elapsed = (ProcessInfo.processInfo.systemUptime - requestedAt) * 1000
            Task { @MainActor in Diagnostics.log("audio engineStopped elapsedMs=\(String(format: "%.1f", elapsed))") }
        }
    }
    private func stopEngine() {
        engine.stop()
        if tapped { engine.inputNode.removeTap(onBus: 0); tapped = false }
    }
    func clear() { lock.lock(); samples.removeAll(keepingCapacity: false); testAudio = nil; testStart = nil; level = 0; failure = nil; lock.unlock() }
}
