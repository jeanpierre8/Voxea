import AppKit

/// Metadata only: never record dictation, field values, audio or clipboard contents.
@MainActor enum Diagnostics {
    static let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/Voxea/insertion.log")
    private static let timestamp: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    static func elapsedMS(since start: TimeInterval) -> String {
        String(format: "%.1f", (ProcessInfo.processInfo.systemUptime - start) * 1000)
    }
    static func log(_ event: String) {
        let app = NSWorkspace.shared.frontmostApplication
        let flags = CGEventSource.flagsState(.combinedSessionState).rawValue
        let line = "\(timestamp.string(from: Date())) \(event) front=\(app?.bundleIdentifier ?? "nil") pid=\(app?.processIdentifier ?? -1) flags=\(flags)\n"
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0 > 1_000_000 { try? FileManager.default.removeItem(at: url) }
        if !FileManager.default.fileExists(atPath: url.path) { FileManager.default.createFile(atPath: url.path, contents: nil, attributes: [.posixPermissions: 0o600]) }
        if let file = try? FileHandle(forWritingTo: url) {
            defer { try? file.close() }
            _ = try? file.seekToEnd(); try? file.write(contentsOf: Data(line.utf8))
        }
    }
}
