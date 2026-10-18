import Foundation
var checks = 0
func expect(_ actual: String, _ expected: String, _ label: String) {
    guard actual == expected else { fatalError("\(label): \(actual.debugDescription) != \(expected.debugDescription)") }
    checks += 1
}
let defaults = FormattingOptions()
let off = FormattingOptions(removeFinalPeriod: false, capitalize: false, voiceCommands: false, removeHesitations: false)
func format(_ text: String) -> String { TextFormatting.apply(text, options: defaults) }
expect(format("bonjour."), "Bonjour", "point final")
expect(format("bonjour ?"), "Bonjour ?", "question")
expect(format("bonjour !"), "Bonjour !", "exclamation")
expect(format("bonjour..."), "Bonjour...", "suspension")
expect(format("bonjour…"), "Bonjour…", "ellipse")
expect(format("pain, etc."), "Pain, etc.", "abréviation")
expect(TextFormatting.apply("  euh à la ligne bonjour.  ", options: off), "  euh à la ligne bonjour.  ", "désactivé sans altération")
expect(format("bonjour à la ligne salut."), "Bonjour\nSalut", "ligne")
expect(format("bonjour nouveau paragraphe salut."), "Bonjour\n\nSalut", "paragraphe")
expect(format("Bonjour. À la ligne, salut."), "Bonjour.\nSalut", "ponctuation moteur")
expect(format("faire une liste du pain élément suivant du lait fin de liste merci."), "• Du pain\n• Du lait\nMerci", "liste")
expect(format("faire une liste : pain. Élément suivant : lait. Fin de liste. merci."), "• Pain.\n• Lait.\nMerci", "liste ponctuée")
expect(format("un élément suivant existe."), "Un élément suivant existe", "hors liste")
expect(format("bonjour à la ligne"), "Bonjour\n", "retour final")
expect(format("bonjour nouveau paragraphe"), "Bonjour\n\n", "paragraphe final")
expect(format("euh bonjour, heu merci."), "Bonjour, merci", "hésitations")
expect(format("Euh. bonjour."), "Bonjour", "hésitation ponctuée")
expect(format("euh..."), "", "hésitation seule")
expect(format("the umbrella is here."), "The umbrella is here", "pas de sous-mot anglais")
expect(format("humain heureux euhologie."), "Humain heureux euhologie", "pas de sous-mot français")
expect(format("hello. how are you? fine!"), "Hello. How are you? Fine!", "phrases FR EN")
expect(format("faire une liste un à la ligne deux nouveau paragraphe suite."), "• Un\n• Deux\n\nSuite", "liste et paragraphes")
expect(format(""), "", "vide")
expect(format("😀 bonjour."), "😀 Bonjour", "unicode")
var preferences = FormattingPreferences()
preferences.applications["documents"] = off
expect(TextFormatting.apply("bonjour.", options: preferences.options(for: "documents")), "bonjour.", "profil application")
expect(TextFormatting.apply("bonjour.", options: preferences.options(for: "chat")), "Bonjour", "profil général")
let data = try JSONEncoder().encode(preferences)
let restored = try JSONDecoder().decode(FormattingPreferences.self, from: data)
expect(TextFormatting.apply("bonjour.", options: restored.options(for: "documents")), "bonjour.", "persistance profils")
print("\(checks) vérifications de mise en forme réussies")
