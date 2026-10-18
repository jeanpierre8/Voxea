import Foundation
import CSQLite

var checks = 0
func check(_ condition: @autoclosure () throws -> Bool, _ label: String) throws {
    guard try condition() else { fatalError("FAIL " + label) }
    checks += 1; print("PASS " + label)
}
func fails(_ label: String, _ body: () throws -> Void) throws {
    do { try body() } catch { checks += 1; print("PASS " + label); return }
    fatalError("FAIL " + label)
}
let folder = FileManager.default.temporaryDirectory.appendingPathComponent("voxea-memory-\(UUID().uuidString)")
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: folder) }
let file = folder.appendingPathComponent("rules.sqlite3")
let hermes = CorrectionRule(heard: "air mess", replacement: "Hermes")
var initial = try CorrectionStore(url: file)
try initial.save(hermes)
try check(try initial.allRules().count == 1, "SQLite insert")
let reopened = try CorrectionStore(url: file)
try check(try reopened.allRules().first?.heard == "air mess", "Persistence on reopen")
let simple = CorrectionEngine(rules: try reopened.allRules())
try check(simple.apply("Ouvrir AIR MESS, puis Air Mess.", bundleID: nil).text == "Ouvrir Hermes, puis Hermes.", "Case, punctuation and repeated matches")
try check(simple.apply("air messenger et clair mess", bundleID: nil).text == "air messenger et clair mess", "No partial words")
try check(simple.apply("air\u{00a0}mess", bundleID: nil).text == "Hermes", "Nonbreaking space")
try check(simple.apply("air\nmess", bundleID: nil).text == "air\nmess", "No match across newlines")
let long = CorrectionRule(heard: "air mess studio", replacement: "Hermes Studio")
let cascade = CorrectionRule(heard: "Hermes", replacement: "Autre")
let engine = CorrectionEngine(rules: [hermes, long, cascade])
try check(engine.apply("air mess studio et air mess", bundleID: nil).text == "Hermes Studio et Hermes", "Longest phrase and no cascading")
let unicode = CorrectionRule(heard: "dicté vocale", replacement: "dictée vocale")
try check(CorrectionEngine(rules: [unicode]).apply("Une dicte\u{301} vocale.", bundleID: nil).text == "Une dictée vocale.", "Canonical Unicode normalization")
try check(CorrectionEngine(rules: [unicode]).apply("Une dicte vocale.", bundleID: nil).applied.isEmpty, "Accents remain significant")
let cpp = CorrectionRule(heard: "C++", replacement: "CPP")
try check(CorrectionEngine(rules: [cpp]).apply("C++ et C++Builder", bundleID: nil).text == "CPP et C++Builder", "Literal special characters and boundaries")
var scoped = CorrectionRule(heard: "air mess", replacement: "Hermes IDE", scopeBundleID: "test.editor")
let scopedEngine = CorrectionEngine(rules: [hermes, scoped])
try check(scopedEngine.apply("air mess", bundleID: "test.editor").text == "Hermes IDE", "Application-specific precedence")
try check(scopedEngine.apply("air mess", bundleID: "test.other").text == "Hermes", "Global rule in other application")
scoped.mode = .suggestion
let suggest = CorrectionEngine(rules: [hermes, scoped])
let proposal = suggest.apply("air mess", bundleID: "test.editor")
try check(proposal.text == "air mess" && proposal.applied.isEmpty && proposal.suggestions.count == 1, "Scoped suggestion overrides global automation")
try check(suggest.apply("air mess", bundleID: "test.editor", includeSuggestions: true).text == "Hermes IDE", "Explicit suggestion acceptance")
var disabled = hermes; disabled.enabled = false
try check(CorrectionEngine(rules: [disabled]).apply("air mess", bundleID: nil).applied.isEmpty, "Disabled rules do not apply")
try initial.save(disabled)
try check(try reopened.allRules().first?.enabled == false, "Disabled state persists")
try initial.save(hermes)
try initial.recordUsage([hermes.id: 2])
var edit = hermes; edit.replacement = "Hermes local"
try initial.save(edit)
try check(try reopened.allRules().first?.uses == 2, "Usage counter survives editing")
try check(try reopened.allRules().first?.replacement == "Hermes local", "Rule editing persists")
try fails("Duplicate rule rejected") { try initial.save(CorrectionRule(heard: " AIR   MESS ", replacement: "Duplicate")) }
try initial.save(CorrectionRule(heard: "air mess", replacement: "Scoped", scopeBundleID: "test.other"))
try check(try initial.allRules().count == 2, "Same phrase allowed in distinct scope")
try fails("Empty phrase rejected") { try initial.save(CorrectionRule(heard: " ", replacement: "x")) }
try fails("Empty replacement rejected") { try initial.save(CorrectionRule(heard: "x", replacement: " ")) }
try fails("Multiline rules rejected") { try initial.save(CorrectionRule(heard: "x\ny", replacement: "z")) }
try fails("NUL rejected") { try initial.save(CorrectionRule(heard: "x\0y", replacement: "z")) }
let injection = CorrectionRule(heard: "l'outil '; DROP TABLE corrections; --", replacement: "L’outil sûr")
try initial.save(injection)
try check(try initial.allRules().count == 3, "SQL parameters preserve quoted input")
let toUndo = try initial.allRules().first { $0.id == hermes.id }!
try initial.delete(hermes.id)
try check(try initial.allRules().allSatisfy { $0.id != hermes.id }, "Deletion persists")
try initial.save(toUndo)
try check(try initial.allRules().first { $0.id == hermes.id }?.uses == 2, "Undo can restore rule and counters")
let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
try check((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600, "Database file is private")
try fails("Unreadable database reports an error") { _ = try CorrectionStore(url: folder) }
func fixtureSQL(_ path: URL, _ sql: String) throws -> Int {
    var database: OpaquePointer?
    guard sqlite3_open(path.path, &database) == SQLITE_OK else { fatalError("Fixture database failed") }
    defer { sqlite3_close(database) }
    var query: OpaquePointer?
    guard sqlite3_prepare_v2(database, sql, -1, &query, nil) == SQLITE_OK else { fatalError("Fixture query failed") }
    defer { sqlite3_finalize(query) }
    let result = sqlite3_step(query)
    guard result == SQLITE_ROW || result == SQLITE_DONE else { fatalError("Fixture step failed") }
    return Int(sqlite3_column_int(query, 0))
}
let future = folder.appendingPathComponent("future.sqlite3")
_ = try fixtureSQL(future, "PRAGMA user_version=2")
try fails("Future schema rejected") { _ = try CorrectionStore(url: future) }
try check(try fixtureSQL(future, "PRAGMA user_version") == 2, "Future schema version preserved")
let malformed = folder.appendingPathComponent("malformed.sqlite3")
_ = try fixtureSQL(malformed, "CREATE TABLE corrections(sentinel TEXT)")
_ = try fixtureSQL(malformed, "INSERT INTO corrections VALUES('preserved')")
try fails("Incompatible schema rejected") { _ = try CorrectionStore(url: malformed) }
try check(try fixtureSQL(malformed, "PRAGMA user_version") == 0, "Failed migration rolled back")
try check(try fixtureSQL(malformed, "SELECT count(*) FROM corrections WHERE sentinel='preserved'") == 1, "Existing data preserved on failed migration")
let corrupt = folder.appendingPathComponent("corrupt.sqlite3")
let corruptBytes = Data("not a SQLite database".utf8)
try corruptBytes.write(to: corrupt)
try fails("Corrupted database fails locally") { _ = try CorrectionStore(url: corrupt) }
try check(try Data(contentsOf: corrupt) == corruptBytes, "Corrupted file not replaced")
var blocker: OpaquePointer?
precondition(sqlite3_open(file.path, &blocker) == SQLITE_OK)
precondition(sqlite3_exec(blocker, "BEGIN IMMEDIATE", nil, nil, nil) == SQLITE_OK)
try fails("Write contention fails without blocking indefinitely") { try initial.recordUsage([hermes.id: 10]) }
precondition(sqlite3_exec(blocker, "ROLLBACK", nil, nil, nil) == SQLITE_OK)
sqlite3_close(blocker)
try check(try initial.allRules().first { $0.id == hermes.id }?.uses == 2, "Failed statistics write is atomic")
var persistedSuggestion = scoped
persistedSuggestion.scopeBundleID = "test.suggestions"
try initial.save(persistedSuggestion)
try check(try reopened.allRules().first { $0.id == persistedSuggestion.id }?.mode == .suggestion, "Suggestion mode persists")
let empty = "texte e\u{301} exact"
try check(CorrectionEngine(rules: []).apply(empty, bundleID: nil).text == empty, "Empty dictionary preserves original bytes")
let many = (0..<500).map { CorrectionRule(heard: "terme\($0)", replacement: "Terme \($0)") }
let timed = CorrectionEngine(rules: many)
let start = Date(); let timedResult = timed.apply("Le terme499 puis le terme12.", bundleID: nil)
try check(timedResult.text == "Le Terme 499 puis le Terme 12.", "500-rule dictionary")
print("CORRECTION_500_RULES_MS \(Date().timeIntervalSince(start) * 1000)")
print("\(checks) memory checks passed")
