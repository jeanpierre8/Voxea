import AVFoundation
import Foundation

// The audio callback owns the converter; the UI reads bounded snapshots under a lock.
final class Microphone: @unchecked Sendable {
    private let engine = AVAudioEngine()
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
    func start() throws {
        clear()
        let input = engine.inputNode
        let source = input.outputFormat(forBus: 0)
        guard source.sampleRate > 0, source.channelCount > 0,
              let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: source, to: target)
        else { throw PrototypeError.message("Aucune entrée microphone disponible.") }
        input.installTap(onBus: 0, bufferSize: 2048, format: source) { [weak self] buffer, _ in
            guard let self else { return }
            let capacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * 16000 / source.sampleRate) + 64)
            guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }
            var supplied = false
            var error: NSError?
            let status = converter.convert(to: output, error: &error) { _, state in
                if supplied { state.pointee = .noDataNow; return nil }
                supplied = true; state.pointee = .haveData; return buffer
            }
            self.lock.lock(); defer { self.lock.unlock() }
            if status == .error { self.failure = error?.localizedDescription ?? "Conversion audio impossible."; return }
            guard let channel = output.floatChannelData?[0] else { return }
            let data = Array(UnsafeBufferPointer(start: channel, count: Int(output.frameLength)))
            self.samples.append(contentsOf: data.prefix(max(0, Self.limit - self.samples.count)))
            let rms = sqrt(data.reduce(Float(0)) { $0 + $1 * $1 } / Float(max(1, data.count)))
            self.level = min(1, max(0, (20 * log10(max(rms, 0.00001)) + 60) / 60))
        }
        tapped = true
        do { engine.prepare(); try engine.start() } catch { stop(); throw error }
    }
    func stop() {
        engine.stop()
        if tapped { engine.inputNode.removeTap(onBus: 0); tapped = false }
    }
    func clear() { lock.lock(); samples.removeAll(keepingCapacity: false); testAudio = nil; testStart = nil; level = 0; failure = nil; lock.unlock() }
}
