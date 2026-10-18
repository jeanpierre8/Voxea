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
        guard let manager else { throw PrototypeError.message("Charger le modèle avant de dicter.") }
        // Independent decoder state: provisional passes must not contaminate final decoding.
        var state = try TdtDecoderState()
        return try await manager.transcribe(samples, decoderState: &state).text.trimmingCharacters(in: .whitespacesAndNewlines)
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
