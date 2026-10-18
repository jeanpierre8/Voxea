import Foundation
import CSQLite

enum CorrectionMode: String, CaseIterable, Hashable { case automatic, suggestion }
struct CorrectionRule: Identifiable, Equatable {
    var id = UUID()
    var heard: String
    var replacement: String
    var scopeBundleID = ""
    var mode: CorrectionMode = .automatic
    var enabled = true
    var uses = 0
    var createdAt = Date().timeIntervalSince1970
    var updatedAt = Date().timeIntervalSince1970
    static func key(_ text: String) -> String {
        text.precomposedStringWithCanonicalMapping
            .split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
            .folding(options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }
    func validated() throws -> Self {
        var rule = self
        rule.heard = heard.trimmingCharacters(in: .whitespacesAndNewlines).precomposedStringWithCanonicalMapping
        rule.replacement = replacement.trimmingCharacters(in: .whitespacesAndNewlines).precomposedStringWithCanonicalMapping
        rule.scopeBundleID = scopeBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rule.heard.isEmpty, !rule.replacement.isEmpty else { throw MemoryError("Renseigner le texte entendu et le texte à écrire.") }
        guard rule.heard.count <= 200, rule.replacement.count <= 500 else { throw MemoryError("Une règle est limitée à 200 caractères entendus et 500 caractères de remplacement.") }
        guard !rule.heard.contains("\0"), !rule.replacement.contains("\0"), !rule.scopeBundleID.contains("\0") else { throw MemoryError("Caractère non pris en charge dans cette règle.") }
        guard rule.heard != rule.replacement else { throw MemoryError("Le remplacement doit être différent du texte entendu.") }
        guard !rule.heard.contains(where: { $0.isNewline }), !rule.replacement.contains(where: { $0.isNewline }) else { throw MemoryError("Utiliser une seule ligne par règle.") }
        rule.updatedAt = Date().timeIntervalSince1970
        return rule
    }
}
struct MemoryError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class CorrectionStore {
    let url: URL
    private var db: OpaquePointer?
    static var defaultURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Voxea", isDirectory: true).appendingPathComponent("corrections.sqlite3")
    }
    init(url: URL = CorrectionStore.defaultURL) throws {
        self.url = url
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let result = sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil)
        guard result == SQLITE_OK else {
            if let db { sqlite3_close(db); self.db = nil }
            throw MemoryError("Impossible d’ouvrir le dictionnaire local. La dictée brute reste disponible.")
        }
        do {
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            sqlite3_busy_timeout(db, 150)
            let version = try integer("PRAGMA user_version")
            guard version <= 1 else { throw MemoryError("Ce dictionnaire nécessite une version plus récente de Voxea.") }
            try execute("PRAGMA journal_mode=WAL")
            try execute("PRAGMA synchronous=FULL")
            if version == 0 {
                try transaction {
                    try execute("""
                    CREATE TABLE IF NOT EXISTS corrections (
                        id TEXT PRIMARY KEY NOT NULL,
                        heard TEXT NOT NULL, heard_key TEXT NOT NULL,
                        replacement TEXT NOT NULL, scope TEXT NOT NULL DEFAULT '',
                        mode TEXT NOT NULL CHECK(mode IN ('automatic','suggestion')),
                        enabled INTEGER NOT NULL CHECK(enabled IN (0,1)),
                        uses INTEGER NOT NULL DEFAULT 0 CHECK(uses >= 0),
                        created_at REAL NOT NULL, updated_at REAL NOT NULL,
                        UNIQUE(heard_key, scope)
                    )
                    """)
                    _ = try allRules()
                    try execute("PRAGMA user_version=1")
                }
            }
            _ = try allRules() // Fail locally on an incompatible schema; never replace it.
        } catch {
            sqlite3_close(db); db = nil; throw error
        }
    }
    deinit { if let db { sqlite3_close(db) } }
    private func failure() -> MemoryError {
        if sqlite3_errcode(db) == SQLITE_CONSTRAINT { return MemoryError("Une règle existe déjà pour ce texte et cette application. Modifier la règle existante.") }
        if sqlite3_errcode(db) == SQLITE_BUSY || sqlite3_errcode(db) == SQLITE_LOCKED { return MemoryError("Le dictionnaire est occupé. Réessayer dans un instant.") }
        return MemoryError("Le dictionnaire local n’a pas pu être lu ou enregistré. Aucun fichier n’a été remplacé.")
    }
    private func statement(_ sql: String) throws -> OpaquePointer {
        var query: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &query, nil) == SQLITE_OK, let query else { throw failure() }
        return query
    }
    private func bind(_ text: String, at index: Int32, in query: OpaquePointer) throws {
        guard sqlite3_bind_text(query, index, text, -1, sqliteTransient) == SQLITE_OK else { throw failure() }
    }
    private func execute(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw failure() }
    }
    private func integer(_ sql: String) throws -> Int {
        let query = try statement(sql); defer { sqlite3_finalize(query) }
        guard sqlite3_step(query) == SQLITE_ROW else { throw failure() }
        return Int(sqlite3_column_int(query, 0))
    }
    private func transaction(_ body: () throws -> Void) throws {
        try execute("BEGIN IMMEDIATE")
        do { try body(); try execute("COMMIT") }
        catch { try? execute("ROLLBACK"); throw error }
    }
    func allRules() throws -> [CorrectionRule] {
        let query = try statement("SELECT id,heard,replacement,scope,mode,enabled,uses,created_at,updated_at FROM corrections ORDER BY heard_key,scope,id")
        defer { sqlite3_finalize(query) }
        func string(_ index: Int32) throws -> String {
            guard let bytes = sqlite3_column_text(query, index) else { throw MemoryError("Le format du dictionnaire n’est pas compatible.") }
            return String(cString: bytes)
        }
        var rows: [CorrectionRule] = []
        while true {
            let result = sqlite3_step(query)
            if result == SQLITE_DONE { return rows }
            guard result == SQLITE_ROW else { throw failure() }
            let values = try (0...4).map { try string(Int32($0)) }
            guard let id = UUID(uuidString: values[0]), let mode = CorrectionMode(rawValue: values[4]) else { throw failure() }
            rows.append(CorrectionRule(id: id, heard: values[1], replacement: values[2], scopeBundleID: values[3], mode: mode, enabled: sqlite3_column_int(query, 5) != 0, uses: Int(sqlite3_column_int64(query, 6)), createdAt: sqlite3_column_double(query, 7), updatedAt: sqlite3_column_double(query, 8)))
        }
    }
    func save(_ value: CorrectionRule) throws {
        let rule = try value.validated()
        let query = try statement("""
        INSERT INTO corrections(id,heard,heard_key,replacement,scope,mode,enabled,uses,created_at,updated_at)
        VALUES(?,?,?,?,?,?,?,?,?,?)
        ON CONFLICT(id) DO UPDATE SET heard=excluded.heard,heard_key=excluded.heard_key,
        replacement=excluded.replacement,scope=excluded.scope,mode=excluded.mode,
        enabled=excluded.enabled,updated_at=excluded.updated_at
        """)
        defer { sqlite3_finalize(query) }
        for (index, text) in [rule.id.uuidString, rule.heard, CorrectionRule.key(rule.heard), rule.replacement, rule.scopeBundleID, rule.mode.rawValue].enumerated() {
            try bind(text, at: Int32(index + 1), in: query)
        }
        sqlite3_bind_int(query, 7, rule.enabled ? 1 : 0)
        sqlite3_bind_int64(query, 8, sqlite3_int64(rule.uses))
        sqlite3_bind_double(query, 9, rule.createdAt); sqlite3_bind_double(query, 10, rule.updatedAt)
        guard sqlite3_step(query) == SQLITE_DONE else { throw failure() }
    }
    func delete(_ id: UUID) throws {
        let query = try statement("DELETE FROM corrections WHERE id=?"); defer { sqlite3_finalize(query) }
        try bind(id.uuidString, at: 1, in: query)
        guard sqlite3_step(query) == SQLITE_DONE else { throw failure() }
    }
    func recordUsage(_ counts: [UUID: Int]) throws {
        guard !counts.isEmpty else { return }
        try transaction {
            let query = try statement("UPDATE corrections SET uses=uses+? WHERE id=?")
            defer { sqlite3_finalize(query) }
            for (id, count) in counts where count > 0 {
                sqlite3_reset(query); sqlite3_clear_bindings(query)
                sqlite3_bind_int64(query, 1, sqlite3_int64(count)); try bind(id.uuidString, at: 2, in: query)
                guard sqlite3_step(query) == SQLITE_DONE else { throw failure() }
            }
        }
    }
}
