import AppKit
import SwiftUI
import AVFoundation
import Carbon
import FluidAudio

@MainActor final class DictationModel: ObservableObject {
    @Published var status = "Chargement du modèle local…"
    @Published var provisional = ""
    @Published var finalText = ""
    @Published var rawText = ""
    @Published var selectedTab = 0
    @Published var formattingScope = ""
    @Published var formatting: FormattingPreferences = {
        guard let data = UserDefaults.standard.data(forKey: "formattingPreferences"),
              let saved = try? JSONDecoder().decode(FormattingPreferences.self, from: data) else { return FormattingPreferences() }
        return saved
    }() {
        didSet { if let data = try? JSONEncoder().encode(formatting) { UserDefaults.standard.set(data, forKey: "formattingPreferences") } }
    }
    private var lastFormattingOptions = FormattingOptions()
    func formatFinal(_ text: String, bundleID: String?) -> String {
        TextFormatting.apply(text, options: formatting.options(for: bundleID))
    }
    @Published var memoryRules: [CorrectionRule] = []
    @Published var memoryError = ""
    @Published var appliedCorrections: [CorrectionChange] = []
    @Published var correctionSuggestions: [CorrectionChange] = []
    @Published var lastDictationBundleID: String?
    @Published var deletedRule: CorrectionRule?
    @Published var memoryEnabled = UserDefaults.standard.object(forKey: "memoryEnabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(memoryEnabled, forKey: "memoryEnabled"); if !memoryEnabled { correctionSuggestions = [] } }
    }
    private var memoryStore: CorrectionStore?
    private var correctionEngine = CorrectionEngine(rules: [])
    private var targetBundleID: String?

    func reloadMemory() throws {
        guard let memoryStore else { throw MemoryError("Le dictionnaire local n’est pas disponible.") }
        do {
            memoryRules = try memoryStore.allRules()
            correctionEngine = CorrectionEngine(rules: memoryRules)
            correctionSuggestions = [] // Previously shown suggestions refer to the old rule snapshot.
            memoryError = ""
        } catch {
            memoryRules = []; correctionEngine = CorrectionEngine(rules: [])
            memoryError = error.localizedDescription; throw error
        }
    }
    func saveMemoryRule(_ rule: CorrectionRule) throws {
        guard let memoryStore else { throw MemoryError("Le dictionnaire local n’est pas disponible.") }
        try memoryStore.save(rule); try reloadMemory()
    }
    func removeMemoryRule(_ rule: CorrectionRule) throws {
        guard let memoryStore else { throw MemoryError("Le dictionnaire local n’est pas disponible.") }
        try memoryStore.delete(rule.id); deletedRule = rule; try reloadMemory()
    }
    func undoMemoryDeletion() throws {
        guard let deletedRule else { return }
        try saveMemoryRule(deletedRule); self.deletedRule = nil
    }
    func previewMemory(_ text: String, bundleID: String?) -> CorrectionResult {
        memoryEnabled ? correctionEngine.apply(text, bundleID: bundleID) : CorrectionResult(text: text, applied: [], suggestions: [])
    }
    private func countCorrections(_ counts: [UUID: Int]) {
        guard !counts.isEmpty else { return }
        do {
            try memoryStore?.recordUsage(counts)
            var updated = memoryRules
            for index in updated.indices {
                if let count = counts[updated[index].id] { updated[index].uses += count }
            }
            memoryRules = updated
        } catch { memoryError = "Le comptage des corrections n’a pas été enregistré. " + error.localizedDescription }
    }
    func copyAcceptingSuggestions() {
        guard !rawText.isEmpty, memoryEnabled else { return }
        let result = correctionEngine.apply(rawText, bundleID: lastDictationBundleID, includeSuggestions: true)
        let accepted = result.applied.filter(\.suggestion).reduce(into: [UUID: Int]()) { $0[$1.ruleID, default: 0] += 1 }
        countCorrections(accepted)
        finalText = TextFormatting.apply(result.text, options: lastFormattingOptions); appliedCorrections = result.applied; correctionSuggestions = []
        TextDelivery.copy(finalText)
        status = "Version avec suggestions copiée · coller pour remplacer le texte souhaité"
    }
    @Published var level: Float = 0
    @Published var recording = false
    @Published var busy = true
    @Published var ready = false
    @Published var seconds = 0.0
    @Published var latency = 0.0
    @Published var accessGranted = AXIsProcessTrusted()
    @Published var automaticInsertion = UserDefaults.standard.object(forKey: "automaticInsertion") as? Bool ?? true {
        didSet { UserDefaults.standard.set(automaticInsertion, forKey: "automaticInsertion") }
    }
    @Published var automaticCopy = UserDefaults.standard.object(forKey: "automaticCopy") as? Bool ?? false {
        didSet { UserDefaults.standard.set(automaticCopy, forKey: "automaticCopy") }
    }
    @Published var testName = ""
    private var testAudio: [Float]?
    @Published var testCountdown = 0
    private var scheduledTest: UUID?
    func scheduleFileTest() {
        guard ready, !busy, !recording, !arming, testAudio != nil, testCountdown == 0 else { return }
        let token = UUID(); scheduledTest = token
        Task {
            for count in [3, 2, 1] {
                guard scheduledTest == token, testAudio != nil else { testCountdown = 0; return }
                testCountdown = count
                status = "Essai dans \(count) s · cliquez dans le champ cible"
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            testCountdown = 0; scheduledTest = nil
            guard ready, !busy, !recording, !arming, testAudio != nil else { return }
            keyState.recording = true
            begin()
        }
    }
    func chooseTestFile() {
        let picker = NSOpenPanel(); picker.canChooseDirectories = false; picker.allowsMultipleSelection = false
        picker.message = "Choisir un fichier audio pour tester le circuit sans microphone. Le prochain raccourci lira ce fichier à vitesse réelle."
        guard picker.runModal() == .OK, let url = picker.url else { return }
        do {
            let file = try AVAudioFile(forReading: url)
            guard Double(file.length) / file.processingFormat.sampleRate <= 60 else { throw PrototypeError.message("Fichier de test limité à 60 secondes.") }
            testAudio = try AudioConverter().resampleAudioFile(url)
            testName = url.lastPathComponent
            status = "Mode fichier de test · prochain raccourci"
        } catch { status = error.localizedDescription }
    }
    func useMicrophone() { scheduledTest = nil; testCountdown = 0; testAudio = nil; testName = ""; status = "Mode microphone" }
    @Published var toggle = UserDefaults.standard.bool(forKey: "toggle")
    @Published var sound = UserDefaults.standard.object(forKey: "sound") as? Bool ?? true
    @Published var key = UserDefaults.standard.object(forKey: "key") as? Int ?? Int(kVK_Space)
    @Published var modifier = UserDefaults.standard.object(forKey: "modifier") as? Int ?? Int(controlKey | optionKey)
    let recognition = Recognition()
    let microphone = Microphone()
    let hotkey = Hotkey()
    var keyState = KeyState()
    var overlay: NSPanel?
    var target: InsertionTarget?
    private var timer: Timer?
    private var worker: Task<Void, Never>?
    private var session = UUID()
    private var arming = false
    private var partialRunning = false
    private var lastPartialCount = 0
    private var startSound: NSSound?
    private var activationObserver: NSObjectProtocol?
    init() {
        do { memoryStore = try CorrectionStore(); try reloadMemory() }
        catch { memoryError = error.localizedDescription }
        // One-time migration away from the shortcut used by Hermes capture.
        if !UserDefaults.standard.bool(forKey: "didMigrateHermesShortcut") {
            if modifier == Int(cmdKey | shiftKey), key == Int(kVK_Space) {
                modifier = Int(controlKey | optionKey)
            }
            UserDefaults.standard.set(true, forKey: "didMigrateHermesShortcut")
        }
        hotkey.callback = { [weak self] down, escape in
            guard let self else { return }
            Diagnostics.log("hotkey down=\(down) escape=\(escape) ready=\(self.ready) busy=\(self.busy) recording=\(self.recording)")
            if escape { if down { self.cancel() }; return }
            guard let action = self.keyState.event(down: down, toggle: self.toggle) else { return }
            switch action {
            case .start:
                guard self.ready, !self.busy else { self.keyState.cancel(); return }
                self.begin()
            case .stop: self.finish()
            case .cancel: self.cancel()
            }
        }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            MainActor.assumeIsolated {
                guard let self else { return }
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                Diagnostics.log("activation app=\(app?.bundleIdentifier ?? "nil")")
                if let target = self.target, app?.processIdentifier != target.pid {
                    self.target = nil
                    Diagnostics.log("destination invalidated reason=applicationSwitch")
                }
            }
        }
        applyShortcut()
    }
    func applyShortcut() {
        guard !recording, !arming else { return }
        keyState = KeyState()
        UserDefaults.standard.set(toggle, forKey: "toggle")
        UserDefaults.standard.set(sound, forKey: "sound")
        UserDefaults.standard.set(key, forKey: "key")
        UserDefaults.standard.set(modifier, forKey: "modifier")
        do { try hotkey.register(key: UInt32(key), modifiers: UInt32(modifier)) }
        catch { status = error.localizedDescription }
    }
    func load(download: Bool = false) {
        guard !recording, !arming else { return }
        busy = true
        status = download ? "Téléchargement de Parakeet V3 puis préparation…" : "Chargement du modèle local…"
        Task {
            do {
                try await recognition.prepare(download: download)
                ready = true; status = "Prêt · Parakeet V3 · langues automatiques"
            } catch { ready = false; status = "Modèle indisponible. Utiliser « Installer le modèle ». \(error.localizedDescription)" }
            busy = false
        }
    }
    func accessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
    private func cue(_ name: String) {
        guard sound else { return }
        let cue = NSSound(named: name); cue?.volume = 0.12; cue?.play()
        if name == "Tink" { startSound = cue }
    }
    func begin() {
        guard ready, !busy, !recording, !arming else { return }
        session = UUID(); let ticket = session
        Diagnostics.log("begin insert=\(automaticInsertion) copy=\(automaticCopy) file=\(testAudio != nil)")
        accessGranted = AXIsProcessTrusted()
        arming = true; target = InsertionTarget.capture()
        Diagnostics.log("captured target=\(target?.fingerprint ?? "nil") trusted=\(AXIsProcessTrusted())")
        targetBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        Task {
            let allowed: Bool
            if testAudio != nil { allowed = true }
            else {
                guard AVCaptureDevice.default(for: .audio) != nil else {
                    arming = false; keyState.cancel(); status = "Aucun microphone connecté. Brancher un microphone ou utiliser un fichier de test local."; return
                }
                allowed = await withCheckedContinuation { continuation in
                    AVCaptureDevice.requestAccess(for: .audio) { continuation.resume(returning: $0) }
                }
            }
            guard ticket == session, arming else { return }
            arming = false
            guard allowed else { status = "Microphone refusé. Autoriser Voxea dans Réglages système > Confidentialité > Microphone."; keyState.cancel(); return }
            do {
                cue("Tink")
                // Let the start cue finish before the microphone captures audio.
                try await Task.sleep(nanoseconds: 180_000_000)
                guard ticket == session, keyState.recording else { return }
                if let testAudio { microphone.startTest(testAudio) } else { try microphone.start() }
                Diagnostics.log("microphone.started file=\(testAudio != nil) targetFocused=\(target?.stillFocused() ?? false)")
                recording = true; provisional = ""; seconds = 0; lastPartialCount = 0
                status = testAudio == nil ? "Écoute · Échap pour annuler" : "Fichier test · Échap pour annuler"; hotkey.captureEscape(true); showOverlay()
                timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak model = self] _ in
                    Task { @MainActor in model?.tick() }
                }
            } catch { status = error.localizedDescription; keyState.cancel() }
        }
    }
    private func tick() {
        guard recording else { return }
        let snap = microphone.snapshot()
        level = snap.level; seconds = Double(snap.samples.count) / 16000
        if let failure = snap.failure { cancel(); status = failure; return }
        if (testAudio != nil && snap.samples.count >= testAudio!.count) || snap.samples.count >= Microphone.limit { keyState.cancel(); finish(); return }
        guard !partialRunning, snap.samples.count >= 16000, snap.samples.count - lastPartialCount >= 24000 else { return }
        // Avoid decoder reentrancy: one progressive pass at a time, final waits for it.
        partialRunning = true; lastPartialCount = snap.samples.count
        let ticket = session
        worker = Task {
            let start = Date()
            do {
                let text = try await recognition.transcribe(snap.samples)
                if ticket == session, recording { provisional = text; latency = Date().timeIntervalSince(start) }
            } catch { if ticket == session, recording { status = "Aperçu indisponible · la transcription finale sera réessayée." } }
            partialRunning = false
        }
    }
    func finish() {
        Diagnostics.log("finish arming=\(arming) recording=\(recording)")
        if arming { arming = false; session = UUID(); keyState.cancel(); return }
        guard recording else { return }
        recording = false; busy = true; timer?.invalidate(); timer = nil
        microphone.stop(); hotkey.captureEscape(false); level = 0
        cue("Pop")
        let samples = microphone.snapshot().samples
        Diagnostics.log("audio samples=\(samples.count) audible=\(samples.contains(where: { abs($0) > 0.01 }))")
        microphone.clear()
        let destination = target
        let contextBundleID = targetBundleID; targetBundleID = nil
        let ticket = session; let pending = worker
        status = "Transcription finale…"
        Task {
            await pending?.value
            guard ticket == session else { busy = false; return }
            defer { busy = false; target = nil }
            guard samples.count >= 4800, samples.contains(where: { abs($0) > 0.01 }) else {
                status = "Enregistrement trop court ou silencieux."; overlay?.orderOut(nil); return
            }
            do {
                let start = Date()
                let original = try await recognition.transcribe(samples)
                guard ticket == session else { return }
                latency = Date().timeIntervalSince(start)
                rawText = original; lastDictationBundleID = contextBundleID
                let corrected = previewMemory(original, bundleID: contextBundleID)
                appliedCorrections = corrected.applied; correctionSuggestions = corrected.suggestions
                lastFormattingOptions = formatting.options(for: contextBundleID)
                let formatted = TextFormatting.apply(corrected.text, options: lastFormattingOptions)
                finalText = formatted; provisional = formatted
                countCorrections(corrected.usage)
                Diagnostics.log("transcribed chars=\(formatted.count) destination=\(destination?.fingerprint ?? "nil") insert=\(automaticInsertion) copy=\(automaticCopy)")
                let result = await TextDelivery.deliver(formatted, to: target == nil ? nil : destination, insert: automaticInsertion, keepCopy: automaticCopy)
                Diagnostics.log("delivery method=\(result.method.rawValue)")
                accessGranted = AXIsProcessTrusted()
                status = result.message + " · " + String(format: "%.2f", latency) + " s"
                if !corrected.applied.isEmpty { status += " · \(corrected.applied.count) correction(s)" }
                if memoryEnabled && memoryStore == nil { status += " · dictionnaire indisponible" }
                // The next dictation can start immediately; only the visual dismissal is delayed.
                Task {
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                    if ticket == session { overlay?.orderOut(nil) }
                }
            } catch { status = "Échec : \(error.localizedDescription). L’aperçu reste visible." }
        }
    }
    func cancel() {
        guard recording || arming else { return }
        session = UUID(); arming = false; keyState.cancel(); recording = false
        timer?.invalidate(); timer = nil; microphone.stop(); microphone.clear()
        target = nil; targetBundleID = nil; provisional = ""; level = 0; hotkey.captureEscape(false)
        overlay?.orderOut(nil); status = "Dictée annulée."
    }
    func copyFinal() {
        TextDelivery.copy(finalText)
    }
    func showOverlay() {
        if overlay == nil {
            let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 480, height: 180), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.level = .floating; panel.isOpaque = false; panel.backgroundColor = .clear
            panel.hasShadow = true; panel.hidesOnDeactivate = false; panel.ignoresMouseEvents = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.contentView = NSHostingView(rootView: OverlayView(model: self))
            overlay = panel
        }
        let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main
        if let frame = screen?.visibleFrame { overlay?.setFrameOrigin(NSPoint(x: frame.midX - 240, y: frame.minY + 32)) }
        overlay?.orderFrontRegardless()
        Diagnostics.log("overlay shown key=\(overlay?.isKeyWindow ?? false)")
    }
}

struct OverlayView: View {
    @ObservedObject var model: DictationModel
    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 5) {
                ForEach(0..<25) { index in
                    Capsule().fill(model.recording ? Color.cyan : Color.gray)
                        .frame(width: 5, height: 5 + CGFloat(model.level) * CGFloat(16 + (index * 13 % 29)))
                }
            }.frame(height: 50).animation(.easeOut(duration: 0.08), value: model.level)
            Text(model.status).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            Text(model.provisional.isEmpty ? "Parlez naturellement · FR / EN automatiques" : model.provisional)
                .font(.system(size: 15, weight: .medium)).lineLimit(3).frame(maxWidth: .infinity)
            if model.recording { Text("\(Int(model.seconds)) / 60 s · Texte provisoire").font(.caption2).foregroundStyle(.secondary) }
        }.padding(18).frame(width: 444, height: 144)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .environment(\.colorScheme, .dark)
    }
}

struct SettingsView: View {
    @ObservedObject var model: DictationModel
    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "waveform").font(.largeTitle).foregroundStyle(.cyan)
                VStack(alignment: .leading) {
                    Text("Voxea").font(.title2.bold())
                    Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—") · build \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—")")
                        .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                    Text("Parakeet V3 · calcul local sur Apple Silicon").foregroundStyle(.secondary)
                }
            }
            Text(model.status).font(.callout).textSelection(.enabled).frame(minHeight: 40, alignment: .leading)
            HStack {
                Button("Installer le modèle") { model.load(download: true) }.disabled(model.busy || model.recording || model.ready)
                Button("Recharger hors ligne") { model.load() }.disabled(model.busy || model.recording)
                ProgressView().controlSize(.small).opacity(model.busy ? 1 : 0)
            }
            Divider()
            Picker("Mode", selection: $model.toggle) {
                Text("Maintenir pour parler").tag(false)
                Text("Appui pour démarrer / arrêter").tag(true)
            }.disabled(model.recording || model.busy)
            HStack {
                Picker("Raccourci", selection: $model.modifier) {
                    ForEach(ShortcutChoices.modifiers) { choice in Text(choice.title).tag(choice.value) }
                }
                Picker("Touche", selection: $model.key) {
                    ForEach(ShortcutChoices.keys) { choice in Text(choice.title).tag(choice.value) }
                }
            }.disabled(model.recording || model.busy)
            VStack(alignment: .leading, spacing: 8) {
                Text("Après la dictée").font(.headline)
                Toggle("Insérer automatiquement dans le champ actif", isOn: $model.automaticInsertion)
                Toggle("Copier automatiquement le texte final", isOn: $model.automaticCopy)
                Text("Le collage préserve le presse-papiers, sauf si vous activez la copie automatique. Aucun message n’est envoyé.")
                    .font(.caption).foregroundStyle(.secondary)
            }.disabled(model.recording || model.busy)
            Toggle("Sons discrets au début et à la fin", isOn: $model.sound).disabled(model.recording || model.busy)
            HStack {
                Button("Tester un fichier audio…") { model.chooseTestFile() }.disabled(model.busy || model.recording)
                if !model.testName.isEmpty {
                    Text(model.testName).font(.caption).lineLimit(1)
                    Button(model.testCountdown > 0 ? "\(model.testCountdown)…" : "Essai dans 3 s") { model.scheduleFileTest() }
                        .disabled(model.busy || model.recording || model.testCountdown > 0)
                    Button("Revenir au micro") { model.useMicrophone() }.disabled(model.busy || model.recording)
                }
            }
            HStack {
                Button("Appliquer le raccourci") { model.applyShortcut() }.disabled(model.recording || model.busy)
                Button("Autoriser l’insertion…") { model.accessibility() }
            }
            Text("Cliquez dans le champ où écrire, puis utilisez le raccourci. Échap annule. Limite : 60 secondes. L’aperçu peut changer avant la fin.")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            Text(model.accessGranted ? "Accessibilité : autorisée" : "Accessibilité : à autoriser pour l’insertion")
                .font(.caption).foregroundStyle(model.accessGranted ? Color.secondary : Color.orange)
            Text("Dernier texte final").font(.headline)
            ScrollView { Text(model.finalText.isEmpty ? "Le texte apparaîtra ici." : model.finalText).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(height: 95)
            HStack {
                Button("Copier le texte") { model.copyFinal() }.disabled(model.finalText.isEmpty)
                Spacer()
                Text("\(String(format: "%.2f", model.latency)) s · dernière passe").font(.caption).foregroundStyle(.secondary)
            }
            if !model.rawText.isEmpty {
                DisclosureGroup("Transcription brute de la dernière dictée") {
                    Text(model.rawText).font(.callout).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    Button("Copier la transcription brute") { TextDelivery.copy(model.rawText) }
                }
            }
            if !model.appliedCorrections.isEmpty {
                Text("Corrections : " + model.appliedCorrections.map { "\($0.heard) → \($0.replacement)" }.joined(separator: " ; "))
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !model.correctionSuggestions.isEmpty {
                Text("Suggestions : " + model.correctionSuggestions.map { "\($0.heard) → \($0.replacement)" }.joined(separator: " ; ")).font(.caption)
                Button("Copier en appliquant les suggestions") { model.copyAcceptingSuggestions() }.disabled(model.busy || model.recording)
            }
            Button("Ouvrir le dictionnaire personnel") { model.selectedTab = 1 }
            if !model.memoryError.isEmpty { Text(model.memoryError).font(.caption).foregroundStyle(.orange) }
            Text("Microphone uniquement pendant la dictée. Aucun audio écrit sur disque. Aucun envoi de voix ni de texte. Le téléchargement initial du modèle nécessite Internet.")
                .font(.caption2).foregroundStyle(.secondary)
        }.padding(24).frame(width: 550)
        }.frame(width: 598, height: max(480, min(820, (NSScreen.main?.visibleFrame.height ?? 920) - 100)))
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    var model: DictationModel!
    var window: NSWindow!
    var statusItem: NSStatusItem!
    func applicationDidFinishLaunching(_ notification: Notification) {
        Diagnostics.log("launch build=\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") ?? "?") trusted=\(AXIsProcessTrusted())")
        model = DictationModel()
        installMainMenu()
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 660), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Voxea"; window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: VoxeaRootView(model: model)); window.center()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Voxea")
        let menu = NSMenu()
        menu.addItem(withTitle: "Réglages et dernier texte", action: #selector(show), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Quitter Voxea", action: #selector(quit), keyEquivalent: "q").target = self
        statusItem.menu = menu
        show(); model.load()
    }
    private func installMainMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem(); main.addItem(appItem)
        let appMenu = NSMenu(title: "Voxea"); appItem.submenu = appMenu
        appMenu.addItem(withTitle: "Afficher Voxea", action: #selector(show), keyEquivalent: "").target = self
        appMenu.addItem(withTitle: "Quitter Voxea", action: #selector(quit), keyEquivalent: "q").target = self
        let editItem = NSMenuItem(); main.addItem(editItem)
        let editMenu = NSMenu(title: "Édition"); editItem.submenu = editMenu
        // Standard responder-chain actions for editing dictionary fields and copying raw text.
        editMenu.addItem(withTitle: "Annuler", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "Rétablir", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Couper", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copier", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Coller", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Tout sélectionner", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        NSApp.mainMenu = main
    }
    func applicationDidBecomeActive(_ notification: Notification) { model?.accessGranted = AXIsProcessTrusted() }
    @objc func show() { model.accessGranted = AXIsProcessTrusted(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    @objc func quit() { model.cancel(); NSApp.terminate(nil) }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

@main enum Entry {
    @MainActor static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        if args.contains("--test-output") {
            let application = NSApplication.shared
            application.setActivationPolicy(.accessory)
            Task {
                let copyOnly = args.contains("--clipboard-only")
                let keepCopy = !args.contains("--preserve-clipboard")
                let expectedPID = args.firstIndex(of: "--target-pid").flatMap { $0 + 1 < args.count ? pid_t(args[$0 + 1]) : nil }
                let text = "Voxea : essai local de collage."
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                let target = InsertionTarget.capture()
                guard copyOnly || (expectedPID != nil && target?.pid == expectedPID) else {
                    print("OUTPUT_TEST_ABORTED trusted=\(AXIsProcessTrusted()) target_matches=false")
                    exit(2)
                }
                let result = await TextDelivery.deliver(text, to: target, insert: !copyOnly, keepCopy: keepCopy)
                let clipboardMatches = NSPasteboard.general.string(forType: .string) == text
                print("OUTPUT_TEST method=\(result.method.rawValue) copied=\(clipboardMatches) web=\(target?.isWebField ?? false)")
                exit(result.method == .unavailable ? 1 : 0)
            }
            application.run()
            return
        }
        if args.contains("--benchmark") || args.contains("--prepare") {
            Task {
                do {
                    let paths = args.filter { !$0.hasPrefix("--") }
                    try await benchmark(paths, download: args.contains("--prepare"))
                    exit(0)
                } catch { fputs("ERROR: \(error.localizedDescription)\n", stderr); exit(1) }
            }
            dispatchMain()
        }
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate(); app.delegate = delegate
        // Synchronous main: never occupy a Swift concurrency MainActor job with app.run().
        withExtendedLifetime(delegate) { app.run() }
    }
}
