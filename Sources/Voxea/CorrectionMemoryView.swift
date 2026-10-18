import AppKit
import SwiftUI

// Select the property-wrapper type explicitly: Command Line Tools omit the SDK 27 State macro plugin.
private typealias ViewState<Value> = SwiftUI.State<Value>

struct VoxeaRootView: View {
    @ObservedObject var model: DictationModel
    var body: some View {
        TabView(selection: $model.selectedTab) {
            SettingsView(model: model).tabItem { Text("Dictée") }.tag(0)
            CorrectionMemoryView(model: model).tabItem { Text("Dictionnaire") }.tag(1)
            FormattingView(model: model).tabItem { Text("Mise en forme") }.tag(2)
        }.padding(8).frame(width: 620, height: max(520, min(870, (NSScreen.main?.visibleFrame.height ?? 970) - 80)))
    }
}
struct CorrectionMemoryView: View {
    @ObservedObject var model: DictationModel
    @ViewState private var search = ""
    @ViewState private var heard = ""
    @ViewState private var replacement = ""
    @ViewState private var scope = ""
    @ViewState private var mode: CorrectionMode = .automatic
    @ViewState private var editingID: UUID?
    @ViewState private var feedback = ""
    @ViewState private var sample = ""
    private struct ApplicationChoice: Identifiable { let id: String; let name: String }
    private var applications: [ApplicationChoice] {
        var names: [String: String] = [:]
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            if let id = app.bundleIdentifier { names[id] = app.localizedName ?? id }
        }
        let stored = Set(model.memoryRules.map(\.scopeBundleID) + [scope, model.lastDictationBundleID ?? ""])
        for id in stored where !id.isEmpty && names[id] == nil {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id), let bundle = Bundle(url: url) {
                names[id] = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? id
            } else { names[id] = id }
        }
        return [ApplicationChoice(id: "", name: "Toutes les applications")] + names.map { ApplicationChoice(id: $0.key, name: $0.value) }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    private var visibleRules: [CorrectionRule] {
        let query = CorrectionRule.key(search)
        return model.memoryRules.filter { query.isEmpty || CorrectionRule.key($0.heard + " " + $0.replacement).contains(query) }
    }
    private func scopeName(_ id: String) -> String { applications.first { $0.id == id }?.name ?? id }
    private func resetForm() {
        heard = ""; replacement = ""; scope = ""; mode = .automatic; editingID = nil
    }
    private func edit(_ rule: CorrectionRule) {
        editingID = rule.id; heard = rule.heard; replacement = rule.replacement
        scope = rule.scopeBundleID; mode = rule.mode; feedback = "Modification de la règle sélectionnée"
    }
    private func save() {
        var rule = model.memoryRules.first { $0.id == editingID } ?? CorrectionRule(heard: heard, replacement: replacement)
        rule.heard = heard; rule.replacement = replacement; rule.scopeBundleID = scope; rule.mode = mode
        do { try model.saveMemoryRule(rule); resetForm(); feedback = "Règle enregistrée localement." }
        catch { feedback = error.localizedDescription }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Dictionnaire personnel").font(.title2.bold())
                Toggle("Activer la mémoire des corrections", isOn: $model.memoryEnabled).disabled(model.busy || model.recording)
                Text("Ajoutez les remplacements que vous souhaitez utiliser. Voxea ne surveille pas vos corrections dans les autres applications et ne réentraîne pas le modèle vocal.")
                    .font(.caption).foregroundStyle(.secondary)
                if !model.memoryError.isEmpty { Text(model.memoryError).foregroundStyle(.orange).font(.caption) }
                TextField("Rechercher une règle", text: $search)
                Text("\(model.memoryRules.filter(\.enabled).count) règle(s) active(s) · \(model.memoryRules.count) au total").font(.caption).foregroundStyle(.secondary)
                if visibleRules.isEmpty {
                    Text(model.memoryRules.isEmpty ? "Aucune règle pour le moment." : "Aucune règle ne correspond à la recherche.")
                        .font(.callout).foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 45)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(visibleRules) { rule in
                                HStack(alignment: .top, spacing: 10) {
                                    Toggle("Activer la règle \(rule.heard)", isOn: Binding(get: { rule.enabled }, set: { enabled in
                                        var value = rule; value.enabled = enabled
                                        do { try model.saveMemoryRule(value); feedback = enabled ? "Règle activée." : "Règle désactivée." }
                                        catch { feedback = error.localizedDescription }
                                    })).labelsHidden()
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(rule.heard) → \(rule.replacement)").font(.callout).lineLimit(3).textSelection(.enabled)
                                        Text("\(rule.mode == .automatic ? "Automatique" : "Suggestion") · \(scopeName(rule.scopeBundleID)) · \(rule.uses) utilisation(s)").font(.caption2).foregroundStyle(.secondary)
                                    }.frame(maxWidth: .infinity, alignment: .leading)
                                    Button("Modifier") { edit(rule) }.controlSize(.small)
                                    Button("Supprimer") {
                                        do {
                                            try model.removeMemoryRule(rule)
                                            if editingID == rule.id { resetForm() }
                                            feedback = "Règle supprimée. Vous pouvez annuler ci-dessous."
                                        } catch { feedback = error.localizedDescription }
                                    }.controlSize(.small)
                                }.padding(.vertical, 5)
                                Divider()
                            }
                        }
                    }.frame(height: 180).disabled(model.busy || model.recording)
                }
                if model.deletedRule != nil {
                    Button("Annuler la dernière suppression") {
                        do { try model.undoMemoryDeletion(); feedback = "Règle restaurée." }
                        catch { feedback = error.localizedDescription }
                    }.disabled(model.busy || model.recording)
                }
                Divider()
                Text(editingID == nil ? "Ajouter une règle" : "Modifier la règle").font(.headline)
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Texte entendu — ex. Air Mess", text: $heard)
                    TextField("Texte à écrire — ex. Hermes", text: $replacement)
                    Picker("Application", selection: $scope) {
                        ForEach(applications) { app in Text(app.name).tag(app.id) }
                    }
                    Picker("Utilisation", selection: $mode) {
                        Text("Automatique").tag(CorrectionMode.automatic)
                        Text("Suggestion seulement").tag(CorrectionMode.suggestion)
                    }
                    Text(mode == .automatic ? "Le remplacement s’applique au texte final, sur des mots entiers. Les règles propres à une application priment pour une même expression." : "La dictée reste inchangée. Voxea présente la suggestion et vous pourrez copier la version proposée.")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button(editingID == nil ? "Ajouter la règle" : "Enregistrer la modification") { save() }
                            .disabled(heard.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || replacement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        if editingID != nil { Button("Annuler la modification") { resetForm(); feedback = "" } }
                    }
                }.disabled(model.busy || model.recording)
                if !feedback.isEmpty { Text(feedback).font(.caption).textSelection(.enabled) }
                Divider()
                Text("Essayer les règles sans dicter").font(.headline)
                TextField("Phrase à tester", text: $sample)
                if !sample.isEmpty {
                    let preview = model.previewMemory(sample, bundleID: scope.isEmpty ? nil : scope)
                    Text(preview.text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(preview.applied.count) correction(s) · \(preview.suggestions.count) suggestion(s)").font(.caption).foregroundStyle(.secondary)
                    ForEach(preview.suggestions) { change in Text("Suggestion : \(change.heard) → \(change.replacement)").font(.caption) }
                }
                Text("Seules les règles et leurs compteurs sont conservés sur ce Mac. Les dernières transcriptions brute et corrigée restent en mémoire jusqu’à la fermeture.")
                    .font(.caption2).foregroundStyle(.secondary)
            }.padding(22)
        }
    }
}
