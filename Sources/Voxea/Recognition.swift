import Foundation
import FluidAudio

actor Recognition {
    private var manager: AsrManager?
    func prepare(download: Bool = false) async throws {
        guard manager == nil else { return }
        let models: AsrModels
        if download { models = try await AsrModels.downloadAndLoad(version: .v3) }
        else { models = try AsrModels.loadLocal(from: AsrModels.defaultCacheDirectory(for: .v3), version: .v3) }
        let engine = AsrManager(config: .default)
        try await engine.loadModels(models)
        manager = engine
    }
    func transcribe(_ samples: [Float]) async throws -> String {
        try Task.checkCancellation()
        guard let manager else { throw PrototypeError.message("Charger le modèle avant de dicter.") }
        // Independent decoder state: provisional passes must not contaminate final decoding.
        var state = try TdtDecoderState()
        let result = try await manager.transcribe(samples, decoderState: &state)
        try Task.checkCancellation()
        return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
enum PrototypeError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}


func benchmark(_ paths: [String], download: Bool) async throws {
    let engine = Recognition()
    let start = Date()
    try await engine.prepare(download: download)
    print("MODEL_READY_SECONDS \(Date().timeIntervalSince(start))")
    for path in paths {
        let samples = try AudioConverter().resampleAudioFile(URL(fileURLWithPath: path))
        var rows: [[String: Any]] = []
        for seconds in stride(from: 2.0, to: Double(samples.count) / 16000, by: 2.0) {
            let time = Date()
            let text = try await engine.transcribe(Array(samples.prefix(Int(seconds * 16000))))
            rows.append(["audio_seconds": seconds, "inference_seconds": Date().timeIntervalSince(time), "text": text, "final": false])
        }
        let time = Date()
        let text = try await engine.transcribe(samples)
        rows.append(["audio_seconds": Double(samples.count) / 16000, "inference_seconds": Date().timeIntervalSince(time), "text": text, "final": true])
        let data = try JSONSerialization.data(withJSONObject: ["file": URL(fileURLWithPath: path).lastPathComponent, "passes": rows], options: [.sortedKeys])
        print(String(decoding: data, as: UTF8.self))
    }
}


// Exercises the actual decoder after interrupting previews. This is an audio-file
// regression check, not a microphone/insertion test.
func benchmarkCancellation(_ path: String) async throws {
    let engine = Recognition()
    try await engine.prepare()
    let samples = try AudioConverter().resampleAudioFile(URL(fileURLWithPath: path))
    let reference = try await engine.transcribe(samples)
    var cancelled = 0
    for index in 0..<5 {
        let preview = Task { try await engine.transcribe(Array(samples.prefix(samples.count / 2))) }
        try await Task.sleep(nanoseconds: 5_000_000)
        preview.cancel()
        do { _ = try await preview.value }
        catch is CancellationError { cancelled += 1 }
        let result = try await engine.transcribe(samples)
        guard result == reference else { throw PrototypeError.message("Transcription différente après annulation d’aperçu.") }
        print("CANCELLATION_PASS iteration=\(index + 1) final_matches=true")
    }
    guard cancelled > 0 else { throw PrototypeError.message("Aucune annulation observée ; essai non probant.") }
    print("CANCELLATION_SUMMARY cancelled=\(cancelled) final_matches=5")
}
