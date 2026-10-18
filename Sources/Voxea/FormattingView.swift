import AppKit
import SwiftUI

private typealias ViewState<Value> = SwiftUI.State<Value>

struct FormattingView: View {
    @ObservedObject var model: DictationModel
    @ViewState private var sample = "bonjour à la ligne faire une liste du pain élément suivant du lait fin de liste merci."
    private var options: FormattingOptions { model.formatting.options(for: model.formattingScope) }
    private var hasOverride: Bool { model.formatting.applications[model.formattingScope] != nil }
    private var applications: [(id: String, name: String)] {
        var names: [String: String] = [:]
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            if let id = app.bundleIdentifier { names[id] = app.localizedName ?? id }
        }
        for id in Set(model.formatting.applications.keys).union([model.formattingScope]) where !id.isEmpty && names[id] == nil { names[id] = id }
        return names.map { (id: $0.key, name: $0.value) }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    private func binding(_ key: WritableKeyPath<FormattingOptions, Bool>) -> Binding<Bool> {
        Binding(get: { options[keyPath: key] }, set: { value in
            var updated = options; updated[keyPath: key] = value
            if model.formattingScope.isEmpty { model.formatting.global = updated }
            else { model.formatting.applications[model.formattingScope] = updated }
        })
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Mise en forme").font(.title2.bold())
                Text("Règles locales appliquées au texte final, après le dictionnaire et avant la copie et l’insertion.").foregroundStyle(.secondary)
                Picker("Application", selection: $model.formattingScope) {
                    Text("Toutes les applications").tag("")
                    ForEach(applications, id: \.id) { app in Text(app.name).tag(app.id) }
                }
                if !model.formattingScope.isEmpty {
                    Text(hasOverride ? "Réglages propres à cette application." : "Cette application suit les réglages généraux. Modifier une option crée ses propres réglages.")
                        .font(.caption).foregroundStyle(.secondary)
                    if hasOverride {
                        Button("Reprendre les réglages généraux") { model.formatting.applications.removeValue(forKey: model.formattingScope) }
                    }
                }
                Toggle("Retirer le point final", isOn: binding(\.removeFinalPeriod))
                Text("Conserve les points d’interrogation, d’exclamation, les points de suspension et les abréviations courantes.").font(.caption).foregroundStyle(.secondary)
                Toggle("Commencer les phrases et les lignes par une majuscule", isOn: binding(\.capitalize))
                Toggle("Retirer les hésitations : euh, heu, uh, um", isOn: binding(\.removeHesitations))
                Toggle("Reconnaître les commandes vocales", isOn: binding(\.voiceCommands))
                Text("Commandes disponibles").font(.headline)
                ForEach(TextFormatting.commands, id: \.phrase) { command in
                    HStack(alignment: .top) {
                        Text("« \(command.phrase) »").frame(width: 180, alignment: .leading)
                        Text(command.effect).foregroundStyle(.secondary)
                    }.font(.callout)
                }
                Text("Les commandes doivent être prononcées en français. « Élément suivant » agit seulement après « faire une liste ». Désactivez les commandes pour dicter ces expressions littéralement. Les puces sont du texte, sans action dans l’application cible.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Noms et expressions : ajoutez vos remplacements dans l’onglet Dictionnaire, par exemple « voxéa » → « Voxea ».")
                    .font(.caption).foregroundStyle(.secondary)
                Divider()
                Text("Essayer sans microphone").font(.headline)
                TextEditor(text: $sample).font(.body).frame(height: 85).border(Color.secondary.opacity(0.3))
                Text("Résultat pour l’application sélectionnée").font(.caption).foregroundStyle(.secondary)
                Text(model.formatFinal(sample, bundleID: model.formattingScope)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, minHeight: 75, alignment: .topLeading)
                Text("Cet aperçu teste la mise en forme seule et n’insère rien. Les préférences sont enregistrées automatiquement sur ce Mac.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(16)
        }
    }
}
