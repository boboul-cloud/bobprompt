import SwiftUI
import UIKit
import AVFoundation

// Helper: prise en charge du design arrondi pour les polices UIKit
private extension UIFont {
    func withDesign(_ design: UIFontDescriptor.SystemDesign) -> UIFont? {
        guard let desc = fontDescriptor.withDesign(design) else { return nil }
        return UIFont(descriptor: desc, size: pointSize)
    }
}

// Classe de synthèse vocale améliorée avec support des voix et synchronisation
@MainActor
class SpeechSynthesizer: NSObject, ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    private var delegate: SpeechDelegate?
    @Published var isSpeaking: Bool = false
    @Published var isPaused: Bool = false
    @Published var selectedVoiceIdentifier: String = ""
    @Published var speechRate: Float = 0.52 // 0.0 à 1.0 (0.5 = normal)
    private var currentText: String?
    
    // Pour le mode synchronisé avec le prompteur
    private var isPromptMode: Bool = false
    private var lastReadPosition: Int = -1
    private var pendingText: String = ""
    private var finishCompletion: (() -> Void)?
    
    // Voix disponibles pour le français
    var availableVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().filter { 
            $0.language.hasPrefix("fr") 
        }.sorted { $0.name < $1.name }
    }
    
    // Voix sélectionnée
    var selectedVoice: AVSpeechSynthesisVoice? {
        if selectedVoiceIdentifier.isEmpty {
            return availableVoices.first
        }
        return availableVoices.first { $0.identifier == selectedVoiceIdentifier }
    }
    
    override init() {
        super.init()
        delegate = SpeechDelegate(
            onFinish: { [weak self] in
                guard let self = self else { return }
                if self.isPromptMode {
                    // Flush buffered text when utterance finishes (skip if paused)
                    if !self.isPaused { self.flushPending() }
                } else {
                    self.isSpeaking = false
                    self.isPaused = false
                    if let completion = self.finishCompletion {
                        self.finishCompletion = nil
                        completion()
                    }
                }
            },
            onPause: { [weak self] in
                guard let self = self else { return }
                if !self.isPromptMode { self.isPaused = true }
            },
            onContinue: { [weak self] in
                self?.isPaused = false
            }
        )
        synthesizer.delegate = delegate
        // Sélectionner la première voix française par défaut
        if let firstVoice = availableVoices.first {
            selectedVoiceIdentifier = firstVoice.identifier
        }
    }
    
    func speak(_ text: String) {
        if synthesizer.isSpeaking && !isPaused {
            synthesizer.pauseSpeaking(at: .word)
            return
        }
        
        if isPaused {
            synthesizer.continueSpeaking()
            return
        }
        
        isPromptMode = false
        currentText = text
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = selectedVoice ?? AVSpeechSynthesisVoice(language: "fr-FR")
        utterance.rate = speechRate
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0.1
        
        isSpeaking = true
        isPaused = false
        synthesizer.speak(utterance)
    }
    
    /// Start prompt mode (voice synced with scroll)
    func startPromptMode() {
        isPromptMode = true
        lastReadPosition = -1
        pendingText = ""
        isSpeaking = true
        isPaused = false
    }
    
    /// Resume prompt mode after pause (don't reset position tracking)
    func resumePromptMode() {
        guard isPromptMode else {
            startPromptMode()
            return
        }
        isPaused = false
        isSpeaking = true
        // Back up position so the re-emitted current line is accepted
        if lastReadPosition > 0 { lastReadPosition -= 1 }
    }
    
    /// Called when a new line enters the reading frame — buffer and speak fluidly
    func addReadingLine(_ lineText: String, at position: Int) {
        guard isPromptMode && !isPaused else { return }
        guard position > lastReadPosition else { return }
        
        let trimmed = lineText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        lastReadPosition = position
        
        // Add to buffer
        if !pendingText.isEmpty { pendingText += " " }
        pendingText += trimmed
        
        // If synthesizer is idle, flush immediately for responsiveness
        if !synthesizer.isSpeaking {
            flushPending()
        }
        // Otherwise, onFinish delegate will flush when current utterance ends
    }
    
    private func flushPending() {
        let text = pendingText.trimmingCharacters(in: .whitespacesAndNewlines)
        pendingText = ""
        guard !text.isEmpty else { return }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = selectedVoice ?? AVSpeechSynthesisVoice(language: "fr-FR")
        utterance.rate = speechRate
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0
        utterance.postUtteranceDelay = 0
        
        synthesizer.speak(utterance)
    }
    
    func pause() {
        isPaused = true
        pendingText = ""
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
    
    func resume() {
        if isPaused {
            synthesizer.continueSpeaking()
        }
    }
    
    /// Finish reading smoothly (let current utterance finish, then stop)
    func finishReading(completion: (() -> Void)? = nil) {
        self.finishCompletion = completion
        isPromptMode = false
        
        // If nothing is playing, call completion immediately
        if !synthesizer.isSpeaking {
            isSpeaking = false
            finishCompletion?()
            finishCompletion = nil
        }
        // Otherwise delegate onFinish will handle it
    }
    
    func stop() {
        finishCompletion = nil
        pendingText = ""
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        isPaused = false
        isPromptMode = false
        currentText = nil
        lastReadPosition = -1
    }
}

// Délégué séparé pour AVSpeechSynthesizer
private class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate {
    private let onFinish: @MainActor () -> Void
    private let onPause: @MainActor () -> Void
    private let onContinue: @MainActor () -> Void
    
    init(onFinish: @escaping @MainActor () -> Void, 
         onPause: @escaping @MainActor () -> Void = {},
         onContinue: @escaping @MainActor () -> Void = {}) {
        self.onFinish = onFinish
        self.onPause = onPause
        self.onContinue = onContinue
        super.init()
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            onFinish()
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            onFinish()
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        Task { @MainActor in
            onPause()
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        Task { @MainActor in
            onContinue()
        }
    }
}

// Simple one-shot speaker: speak text, no toggle behavior
@MainActor
class FrameSpeaker: NSObject, ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    private var delegate: FrameSpeakerDelegate?
    @Published var isSpeaking: Bool = false
    var voiceIdentifier: String = ""
    var rate: Float = 0.35
    
    override init() {
        super.init()
        delegate = FrameSpeakerDelegate { [weak self] in
            self?.isSpeaking = false
        }
        synthesizer.delegate = delegate
    }
    
    var selectedVoice: AVSpeechSynthesisVoice? {
        if voiceIdentifier.isEmpty {
            return AVSpeechSynthesisVoice.speechVoices().first { $0.language.hasPrefix("fr") }
        }
        return AVSpeechSynthesisVoice.speechVoices().first { $0.identifier == voiceIdentifier }
    }
    
    func speak(_ text: String) {
        guard !text.isEmpty else { return }
        // Always stop current speech first, then speak new
        synthesizer.stopSpeaking(at: .immediate)
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = selectedVoice ?? AVSpeechSynthesisVoice(language: "fr-FR")
        utterance.rate = rate
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0.05
        
        isSpeaking = true
        synthesizer.speak(utterance)
    }
    
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
}

private class FrameSpeakerDelegate: NSObject, AVSpeechSynthesizerDelegate {
    private let onDone: @MainActor () -> Void
    
    init(onDone: @escaping @MainActor () -> Void) {
        self.onDone = onDone
        super.init()
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in onDone() }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in onDone() }
    }
}

// Définition déplacée ici pour être visible avant usage dans ContentView
private enum SampleText {
    static let fr = """
Bonjour ! Je m'appelle Léo et j'adore lire avec mon prompteur magique.

Il défile tout seul et colore les sylla-bes en alternant les couleurs pour m'aider à bien pro-non-cer. C'est amusant et très pra-tique !
"""
}

struct ContentView: View {
    // MARK: - Mode simplifié (2 modes au lieu de 4)
    enum Mode: String, CaseIterable, Identifiable { 
        case edit = "Éditer", read = "Lire"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .edit: return "pencil"
            case .read: return "play.fill"
            }
        }
    }

    @State private var mode: Mode = .read
    @State private var inputText: String = SampleText.fr
    @State private var isPlaying: Bool = false
    @State private var speed: Double = 40 // pt/s - légèrement plus rapide par défaut
    @State private var colorSyllables: Bool = true
    @State private var fontSize: Double = 48
    @State private var hasStartedOnce: Bool = false
    @State private var mirror: Bool = false
    @State private var countdownEnabled: Bool = true
    @State private var countdownValue: Int? = nil
    @State private var countdownTimer: Timer? = nil
    @State private var showLibrary: Bool = false // Bibliothèque en sheet
    @State private var showOptions: Bool = false
    @State private var showAICreation: Bool = false // IA en sheet
    @StateObject private var store = TextStore()
    @State private var textTitle: String = ""

    @State private var currentTheme: AppTheme = .candy
    @State private var color1: Color = .blue
    @State private var color2: Color = .pink
    @State private var centerAlign: Bool = true
    @State private var oneWordPerLine: Bool = false
    @State private var sidePadding: Double = 28
    @State private var fullScreenRead: Bool = false
    @State private var readProgress: CGFloat = 0
    @State private var readCardFraction: Double = 0.75
    @State private var resetScrollToTop: Bool = false
    @State private var stopAndResetScroll: Bool = false
    @FocusState private var focusedField: EditField?
    @State private var showClearAlert: Bool = false
    @State private var showTranslation: Bool = false
    @State private var voiceEnabled: Bool = false
    @StateObject private var speechSynthesizer = SpeechSynthesizer()
    @StateObject private var frameSpeaker = FrameSpeaker()
    @State private var showHelp: Bool = false
    @State private var showPremium: Bool = false
    @State private var showLimitAlert: Bool = false
    @State private var requestVisibleText: Bool = false
    @State private var showSpeedControl: Bool = false // Toggle pour afficher les contrôles inline
    @EnvironmentObject private var purchaseManager: PurchaseManager

    enum EditField { case title, body }

    /// Derive voice rate from scroll speed: 15→100 pt/s maps to 0.1→0.6 AVSpeech rate
    private var speechRate: Double {
        0.1 + (speed - 15) / 85.0 * 0.5
    }

    private var attributed: NSAttributedString {
        let font = UIFont.systemFont(ofSize: CGFloat(fontSize), weight: .regular).withDesign(UIFontDescriptor.SystemDesign.rounded) ?? UIFont.systemFont(ofSize: CGFloat(fontSize))
        return Syllabifier.attributed(
            text: inputText,
            font: font,
            syllableColors: [UIColor.from(color1), UIColor.from(color2)],
            enabled: colorSyllables,
            localeIdentifier: "fr_FR",
            lineSpacing: 10,
            alignment: .natural
        )
    }
    /// Put one word per line for better voice sync
    private func wordPerLine(_ text: String) -> String {
        text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
    
    private var attributedReader: NSAttributedString {
        let font = UIFont.systemFont(ofSize: CGFloat(fontSize), weight: .regular).withDesign(UIFontDescriptor.SystemDesign.rounded) ?? UIFont.systemFont(ofSize: CGFloat(fontSize))
        let displayText = oneWordPerLine ? wordPerLine(inputText) : inputText
        return Syllabifier.attributed(
            text: displayText,
            font: font,
            syllableColors: [UIColor.from(color1), UIColor.from(color2)],
            enabled: colorSyllables,
            localeIdentifier: "fr_FR",
            lineSpacing: 12,
            alignment: centerAlign ? .center : .natural
        )
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            VStack(spacing: 16) {
                if !fullScreenRead && mode == .read {
                    compactHeader
                }
                if !fullScreenRead {
                    simplifiedModePicker
                }
                Group {
                    if mode == .edit { editorView }
                    else { readerView }
                }
                .id(mode)
            }
            .padding(.bottom, (mode == .read && !fullScreenRead) ? 140 : 0)
            if let value = countdownValue { countdownOverlay(value) }
        }
        .safeAreaInset(edge: .bottom) {
            if mode == .read && !fullScreenRead { simplifiedControlBar } else { Color.clear.frame(height: 0) }
        }
        .alert("Effacer le texte ?", isPresented: $showClearAlert) {
            Button("Annuler", role: .cancel) {}
            Button("Effacer", role: .destructive) {
                inputText = ""
                haptic(.rigid)
            }
        } message: {
            Text("Cette action supprime le contenu actuel.")
        }
        .alert("Limite atteinte", isPresented: $showLimitAlert) {
            Button("Plus tard", role: .cancel) {}
            Button("Passer Premium") { showPremium = true }
        } message: {
            Text("Vous avez atteint la limite de \(PurchaseManager.freeTextLimit) textes. Passez Premium pour en sauvegarder plus !")
        }
        .sheet(isPresented: $showPremium) { PremiumView() }
        .sheet(isPresented: $showLibrary) { librarySheet }
        .sheet(isPresented: $showAICreation) { aiCreationSheet }
        .sheet(isPresented: $showHelp) { HelpView() }
        .sheet(isPresented: $showOptions) { optionsSheet }
        .translationPresentationCompat(isPresented: $showTranslation, text: inputText)
    }
    
    // MARK: - Header compact pour mode lecture
    private var compactHeader: some View {
        HStack {
            Text("bobprompt")
                .font(Theme.roundedFont(size: 20, weight: .bold))
                .lineLimit(1)
                .fixedSize()
                .foregroundColor(currentTheme.isDark ? .white : .primary)
            
            PremiumBadge()
            
            Spacer()
            
            // Thème
            Menu {
                ForEach(AppTheme.allCases) { t in
                    Button(action: { 
                        withAnimation(.spring(response: 0.4)) { currentTheme = t }
                        haptic(.light)
                    }) {
                        Label("\(t.icon) \(t.rawValue)", systemImage: currentTheme == t ? "checkmark.circle.fill" : "circle")
                    }
                }
            } label: {
                Text(currentTheme.icon)
                    .font(.title3)
                    .padding(8)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            .foregroundColor(currentTheme.isDark ? .white : .primary)
            
            // Aide
            Button(action: { showHelp = true; haptic(.light) }) {
                Image(systemName: "questionmark.circle")
                    .font(.title3)
                    .padding(8)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            .foregroundColor(currentTheme.isDark ? .white : .primary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
    
    // MARK: - Mode Picker simplifié (2 modes)
    private var simplifiedModePicker: some View {
        HStack(spacing: 12) {
            ForEach(Mode.allCases) { m in
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { mode = m }
                    if m == .edit { isPlaying = false }
                    haptic(.light)
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: m.icon)
                            .font(.system(size: 16, weight: .semibold))
                        Text(m.rawValue)
                            .font(Theme.roundedFont(size: 16, weight: .semibold))
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .foregroundColor(mode == m ? .white : (currentTheme.isDark ? .white.opacity(0.8) : .primary))
                    .background(
                        Capsule()
                            .fill(mode == m 
                                  ? AnyShapeStyle(LinearGradient(colors: [currentTheme.primaryColor, currentTheme.accentColor], startPoint: .leading, endPoint: .trailing))
                                  : AnyShapeStyle(Color.white.opacity(currentTheme.isDark ? 0.1 : 0.8)))
                    )
                    .shadow(color: mode == m ? currentTheme.primaryColor.opacity(0.3) : .clear, radius: 8, y: 4)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 16)
    }

    private var editorView: some View {
        VStack(spacing: 0) {
            // Quick actions bar
            HStack(spacing: 10) {
                // Bibliothèque
                Button(action: { showLibrary = true; haptic(.light) }) {
                    Label("Textes", systemImage: "books.vertical.fill")
                        .font(Theme.roundedFont(size: 13, weight: .medium))
                }
                .buttonStyle(.bordered)
                .tint(currentTheme.primaryColor)
                
                // Créer avec IA
                Button(action: { showAICreation = true; haptic(.light) }) {
                    Label("IA", systemImage: "sparkles")
                        .font(Theme.roundedFont(size: 13, weight: .medium))
                }
                .buttonStyle(.bordered)
                .tint(.purple)
                
                // Exemple
                Button(action: { 
                    inputText = SampleText.fr
                    isPlaying = false
                    haptic(.light)
                }) {
                    Label("Exemple", systemImage: "text.quote")
                        .font(Theme.roundedFont(size: 13, weight: .medium))
                }
                .buttonStyle(.bordered)
                .tint(currentTheme.accentColor)
                
                Spacer()
                
                // Premium
                if !purchaseManager.isPremium {
                    Button(action: { showPremium = true; haptic(.light) }) {
                        HStack(spacing: 4) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.yellow)
                            Text("Premium")
                                .font(Theme.roundedFont(size: 12, weight: .medium))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple.opacity(0.8))
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 12)
            
            // Title field
            ZStack(alignment: .leading) {
                if textTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Titre (optionnel)")
                        .foregroundColor(.secondary)
                        .padding(.leading, 18)
                }
                TextField("", text: $textTitle)
                    .font(Theme.roundedFont(size: 20, weight: .semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .focused($focusedField, equals: .title)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .body }
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.95))
            )
            .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
            .padding(.horizontal)
            .padding(.bottom, 10)

            // Main editor
            ZStack(alignment: .topLeading) {
                TextEditor(text: $inputText)
                    .font(Theme.roundedFont(size: CGFloat(fontSize) * 0.65)) // Slightly smaller in edit
                    .scrollContentBackgroundHiddenCompat()
                    .padding(14)
                    .focused($focusedField, equals: .body)
                if inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Écrivez ou collez votre texte ici…")
                        .foregroundColor(.secondary)
                        .padding(.top, 22)
                        .padding(.leading, 22)
                        .allowsHitTesting(false)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.98))
            )
            .shadow(color: .black.opacity(0.06), radius: 10, y: 5)
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Button("OK") { focusedField = nil }
                Spacer()
                Button(role: .destructive) { showClearAlert = true } label: {
                    Image(systemName: "trash")
                }
                Button { saveCurrentText() } label: {
                    Image(systemName: "square.and.arrow.down")
                }
            }
        }
    }
    
    // MARK: - Library Sheet
    private var librarySheet: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Save current text section
                if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Texte actuel")
                            .font(Theme.roundedFont(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        HStack {
                            TextField("Titre", text: $textTitle)
                                .textFieldStyle(.roundedBorder)
                                .font(Theme.roundedFont(size: 15))
                            
                            Button(action: { saveCurrentText(); haptic(.rigid) }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                            }
                            .tint(Theme.friendlyGreen)
                        }
                        
                        Text(inputText.prefix(80) + (inputText.count > 80 ? "…" : ""))
                            .font(Theme.roundedFont(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                }
                
                // Saved texts list
                List {
                    if store.items.isEmpty {
                        Text("Aucun texte sauvegardé")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .listRowBackground(Color.clear)
                    } else {
                        ForEach(store.items) { item in
                            Button {
                                inputText = item.content
                                textTitle = item.title
                                showLibrary = false
                                haptic(.light)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .font(Theme.roundedFont(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)
                                    Text(DateFormatter.shortDate.string(from: item.date))
                                        .font(Theme.roundedFont(size: 11))
                                        .foregroundColor(.secondary)
                                    Text(item.content.prefix(60) + (item.content.count > 60 ? "…" : ""))
                                        .font(Theme.roundedFont(size: 12))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete { store.remove(at: $0) }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Bibliothèque")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { EditButton() }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("OK") { showLibrary = false }
                }
            }
        }
    }
    
    // MARK: - AI Creation Sheet
    private var aiCreationSheet: some View {
        AICreationInlineView(onInsert: { newText in
            inputText = newText
            showAICreation = false
            haptic(.rigid)
        }, onClose: {
            showAICreation = false
            haptic(.light)
        })
    }

    private var readerView: some View {
        GeometryReader { proxy in
            let isIPad = UIDevice.current.userInterfaceIdiom == .pad
            let maxWidth: CGFloat = isIPad ? 600 : .infinity
            let effectiveFraction = isIPad ? min(readCardFraction, 0.4) : readCardFraction
            let h = proxy.size.height * effectiveFraction
            
            VStack(spacing: 10) {
                // Inline controls (speed + size) - toggle visibility
                if showSpeedControl && !isPlaying {
                    inlineControls
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                ZStack {
                    TeleprompterTextView(attributedText: .constant(attributedReader),
                                         isPlaying: $isPlaying,
                                         speed: CGFloat(speed),
                                         mirror: mirror,
                                         sidePadding: CGFloat(sidePadding),
                                         onFinished: {
                        DispatchQueue.main.async {
                            isPlaying = false
                            hasStartedOnce = false
                            if voiceEnabled {
                                speechSynthesizer.finishReading {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        self.resetScrollToTop = true
                                    }
                                }
                            } else {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    resetScrollToTop = true
                                }
                            }
                        }
                    }, onProgress: { p in
                        DispatchQueue.main.async { readProgress = p }
                    }, onReadingLineChanged: { lineText, position in
                        DispatchQueue.main.async {
                            if voiceEnabled {
                                speechSynthesizer.addReadingLine(lineText, at: position)
                            }
                        }
                    }, resetToTop: $resetScrollToTop,
                                         stopAndReset: $stopAndResetScroll,
                                         requestVisibleText: $requestVisibleText,
                                         onVisibleTextExtracted: { text in
                        // Direct call — no async bounce needed
                        speakFrameText(text)
                    })
                    
                    // Fades
                    VStack {
                        let fadeH = max(8.0, min(h * 0.12, 20.0))
                        LinearGradient(colors: [backgroundTopFade, .clear], startPoint: .top, endPoint: .bottom)
                            .frame(height: fadeH)
                            .allowsHitTesting(false)
                        Spacer()
                        LinearGradient(colors: [.clear, backgroundBottomFade], startPoint: .top, endPoint: .bottom)
                            .frame(height: fadeH)
                            .allowsHitTesting(false)
                    }
                }
                .frame(maxWidth: maxWidth)
                .frame(height: h)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .shadow(color: .black.opacity(0.1), radius: 14, y: 6)
                .padding(.horizontal)
                .frame(maxWidth: .infinity)
                
                // Progress bar
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.25))
                    GeometryReader { gp in
                        Capsule().fill(Theme.friendlyGreen.opacity(0.9))
                            .frame(width: max(4, gp.size.width * readProgress))
                    }
                }
                .frame(height: 4)
                .padding(.horizontal, 24)
                
                // Full-screen button
                HStack {
                    Spacer()
                    Button(action: { fullScreenRead.toggle(); haptic(.light) }) {
                        Image(systemName: fullScreenRead ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Theme.accent)
                            .padding(8)
                            .background(Circle().fill(Color.white.opacity(0.9)))
                            .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 24)
            }
            .padding(.top, 50)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
    
    // MARK: - Inline Controls (Speed + Size)
    private var inlineControls: some View {
        VStack(spacing: 12) {
            // Speed slider
            HStack(spacing: 10) {
                Image(systemName: "tortoise.fill")
                    .foregroundColor(speed < 30 ? currentTheme.primaryColor : .secondary)
                    .font(.system(size: 14))
                
                Slider(value: $speed, in: 15...100, step: 5)
                    .tint(currentTheme.primaryColor)
                    .onChange(of: speed) { _ in
                        speechSynthesizer.speechRate = Float(speechRate)
                    }
                
                Image(systemName: "hare.fill")
                    .foregroundColor(speed > 70 ? currentTheme.primaryColor : .secondary)
                    .font(.system(size: 14))
                
                Text("\(Int(speed))")
                    .font(Theme.roundedFont(size: 12, weight: .medium))
                    .monospacedDigit()
                    .frame(width: 28)
            }
            
            // Font size slider
            HStack(spacing: 10) {
                Image(systemName: "textformat.size.smaller")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                
                Slider(value: $fontSize, in: 28...60, step: 2)
                    .tint(currentTheme.accentColor)
                
                Image(systemName: "textformat.size.larger")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
                
                Text("\(Int(fontSize))")
                    .font(Theme.roundedFont(size: 12, weight: .medium))
                    .monospacedDigit()
                    .frame(width: 28)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 16)
    }
    // MARK: - Simplified Control Bar
    private var simplifiedControlBar: some View {
        VStack(spacing: 14) {
            // Main controls row
            HStack(spacing: 16) {
                // Stop button
                Button(action: { 
                    cancelCountdown()
                    isPlaying = false
                    stopAndResetScroll = true
                    speechSynthesizer.stop()
                    frameSpeaker.stop()
                    hasStartedOnce = false
                    haptic(.light) 
                }) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Theme.accent.opacity(0.85)))
                        .shadow(color: Theme.accent.opacity(0.2), radius: 6, y: 3)
                }
                .buttonStyle(PlainButtonStyle())

                // Play/Pause (main button)
                Button(action: { handlePlayPause(); haptic(.medium) }) {
                    ZStack {
                        Circle()
                            .stroke(
                                LinearGradient(colors: [currentTheme.primaryColor, currentTheme.accentColor], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 3
                            )
                            .frame(width: 72, height: 72)
                            .scaleEffect(isPlaying ? 1.08 : 1.0)
                            .opacity(isPlaying ? 0.5 : 1.0)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPlaying)
                        
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 64, height: 64)
                            .background(
                                Circle().fill(
                                    LinearGradient(colors: [currentTheme.primaryColor, currentTheme.accentColor.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                            )
                            .shadow(color: currentTheme.primaryColor.opacity(0.35), radius: 10, y: 5)
                    }
                }
                .buttonStyle(PlainButtonStyle())

                // Speak visible text (disabled during playback to avoid audio conflict)
                Button(action: { requestSpeakVisibleText(); haptic(.light) }) {
                    Image(systemName: frameSpeaker.isSpeaking ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(frameSpeaker.isSpeaking ? .white : (currentTheme.isDark ? .white : .primary))
                        .frame(width: 44, height: 44)
                        .background(
                            ZStack {
                                Circle().fill(.ultraThinMaterial)
                                if frameSpeaker.isSpeaking {
                                    Circle().fill(Theme.primary.opacity(0.85))
                                }
                            }
                        )
                        .shadow(color: .black.opacity(0.08), radius: 5, y: 2)
                        .opacity(isPlaying ? 0.4 : 1.0)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isPlaying)
                
                // Settings toggle (speed/size)
                Button(action: { 
                    withAnimation(.spring(response: 0.3)) { showSpeedControl.toggle() }
                    haptic(.light)
                }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(showSpeedControl ? .white : (currentTheme.isDark ? .white : .primary))
                        .frame(width: 44, height: 44)
                        .background(
                            ZStack {
                                Circle().fill(.ultraThinMaterial)
                                if showSpeedControl {
                                    Circle().fill(currentTheme.primaryColor)
                                }
                            }
                        )
                        .shadow(color: .black.opacity(0.08), radius: 5, y: 2)
                }
                .buttonStyle(PlainButtonStyle())
                
                // More options
                Button(action: { showOptions = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(currentTheme.isDark ? .white : .primary)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(.ultraThinMaterial))
                        .shadow(color: .black.opacity(0.08), radius: 5, y: 2)
                }
                .buttonStyle(PlainButtonStyle())
            }

            // Quick toggles row
            HStack(spacing: 10) {
                QuickToggle(icon: "textformat.abc", label: "Syllabes", isOn: $colorSyllables, tint: currentTheme.primaryColor)
                QuickToggle(icon: "speaker.wave.2.fill", label: "Voix", isOn: $voiceEnabled, tint: currentTheme.primaryColor)
                QuickToggle(icon: "arrow.left.and.right.righttriangle.left.righttriangle.right", label: "Miroir", isOn: $mirror, tint: currentTheme.primaryColor)
                QuickToggle(icon: "text.aligncenter", label: "Centrer", isOn: $centerAlign, tint: currentTheme.primaryColor)
                QuickToggle(icon: "text.word.spacing", label: "1 mot", isOn: $oneWordPerLine, tint: currentTheme.primaryColor)
            }
            .padding(.horizontal, 8)
            

        }
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.12), radius: 16, y: -4)
        )
        .padding(.horizontal, 8)
    }
}

// MARK: - Quick Toggle Component
private struct QuickToggle: View {
    let icon: String
    let label: String
    @Binding var isOn: Bool
    let tint: Color
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.25)) { isOn.toggle() }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(label)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
            }
            .foregroundColor(isOn ? .white : .primary.opacity(0.7))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isOn ? tint : Color(.systemBackground).opacity(0.7))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Critères IA (déplacés ici pour résolution avant usage)
private struct LocalAICriteria: Equatable {
    var sujet: String = ""
    var objectif: Objectif = .informer
    var ton: Ton = .amical
    var publicCible: PublicCible = .grandPublic
    var style: Style = .storytelling
    var contraintes: String = ""

    enum Objectif: String, CaseIterable, Identifiable { case informer = "Informer", convaincre = "Convaincre", divertir = "Divertir", inspirer = "Inspirer"; var id: String { rawValue } }
    enum Ton: String, CaseIterable, Identifiable { case amical = "Amical", professionnel = "Professionnel", inspirant = "Inspirant", humoristique = "Humoristique", neutre = "Neutre"; var id: String { rawValue } }
    enum PublicCible: String, CaseIterable, Identifiable { case enfants = "Enfants", ados = "Adolescents", adultes = "Adultes", pros = "Professionnels", grandPublic = "Grand public"; var id: String { rawValue } }
    enum Style: String, CaseIterable, Identifiable { case storytelling = "Storytelling", tutoriel = "Tutoriel", liste = "Liste", discours = "Discours", annonce = "Annonce"; var id: String { rawValue } }
}

// Vue imbriquée pour la création IA (6 critères + nombre de mots)
private struct AICreationInlineView: View {
    // Retrait de dismiss (inline, pas présenté en sheet)
    @State private var criteria = LocalAICriteria()
    @State private var wordCount: Double = 120
    @State private var generated: String = ""
    @State private var keywords: [String] = []
    @State private var newKeyword: String = ""
    @State private var useOnlineAI: Bool = true
    @State private var apiKey: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var temperature: Double = 0.9
    private let apiKeyStorageKey = "OPENAI_API_KEY"
    var onInsert: (String) -> Void
    var onClose: () -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Service IA"), footer: Text(useOnlineAI ? "Utilise OpenAI (chat completions). Clé requise." : "Mode hors‑ligne local.")) {
                    Toggle("Utiliser IA en ligne", isOn: $useOnlineAI)
                    if useOnlineAI {
                        SecureField("Clé API OpenAI", text: $apiKey)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                        HStack {
                            Text("Température")
                            Slider(value: $temperature, in: 0.1...1.2, step: 0.05)
                            Text(String(format: "%.2f", temperature)).monospacedDigit()
                        }
                    }
                }
                Section(header: Text("Sujet")) {
                    TextField("De quoi voulez-vous parler ?", text: $criteria.sujet)
                }
                Section(header: Text("Objectif")) {
                    Picker("Objectif", selection: $criteria.objectif) {
                        ForEach(LocalAICriteria.Objectif.allCases) { v in Text(v.rawValue).tag(v) }
                    }.pickerStyle(.segmented)
                }
                Section(header: Text("Ton")) {
                    Picker("Ton", selection: $criteria.ton) {
                        ForEach(LocalAICriteria.Ton.allCases) { v in Text(v.rawValue).tag(v) }
                    }.pickerStyle(.segmented)
                }
                Section(header: Text("Public cible")) {
                    Picker("Public", selection: $criteria.publicCible) {
                        ForEach(LocalAICriteria.PublicCible.allCases) { v in Text(v.rawValue).tag(v) }
                    }.pickerStyle(.menu)
                }
                Section(header: Text("Style")) {
                    Picker("Style", selection: $criteria.style) {
                        ForEach(LocalAICriteria.Style.allCases) { v in Text(v.rawValue).tag(v) }
                    }.pickerStyle(.menu)
                }

                // Mots-clés (chips + ajout)
                Section(header: Text("Mots-clés"), footer: Text("Ajoutez un mot-clé puis appuyez sur “+” ou Entrée. Glissez pour supprimer dans la liste.")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(keywords, id: \.self) { kw in
                                HStack(spacing: 6) {
                                    Text(kw)
                                        .font(.caption)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 10)
                                        .background(Capsule().fill(Color.secondary.opacity(0.15)))
                                    Button(action: { removeKeyword(kw) }) {
                                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    HStack {
                        TextField("Ajouter un mot-clé", text: $newKeyword, onCommit: addKeyword)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                        Button(action: addKeyword) { Image(systemName: "plus.circle.fill") }
                            .disabled(newKeyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                // Ancienne zone contraintes (optionnelle)
                Section(header: Text("Contraintes (facultatif)"), footer: Text("Vous pouvez aussi saisir des mots-clés séparés par des virgules; ils seront fusionnés avec la liste ci-dessus.")) {
                    TextField("Ex: durable, chiffres 2024, citation courte", text: $criteria.contraintes)
                        .onChange(of: criteria.contraintes) { _ in syncKeywordsFromConstraints() }
                }

                Section(header: Text("Nombre de mots")) {
                    HStack {
                        Slider(value: $wordCount, in: 30...600, step: 10)
                        Text("\(Int(wordCount))").monospacedDigit()
                    }
                }
                if !generated.isEmpty {
                    Section(header: Text("Aperçu")) {
                        TextEditor(text: $generated)
                            .frame(minHeight: 180)
                    }
                }
                if let err = errorMessage {
                    Section(header: Text("Erreur")) { Text(err).foregroundColor(.red) }
                }
                if isLoading {
                    Section { HStack { ProgressView(); Text("Génération…") } }
                }
            }
            .navigationTitle("Création IA")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { onClose() } }
                ToolbarItemGroup(placement: .confirmationAction) {
                    Button("Générer") { generate() }.disabled(isLoading)
                    Button("Insérer") { onInsert(generated); onClose() }
                        .disabled(generated.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { syncKeywordsFromConstraints(); loadStoredKeyIfAny() }
        }
    }

    private func addKeyword() {
        let clean = newKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        if !keywords.contains(where: { $0.caseInsensitiveCompare(clean) == .orderedSame }) {
            keywords.append(clean)
            syncConstraintsFromKeywords()
        }
        newKeyword = ""
    }
    private func removeKeyword(_ kw: String) {
        keywords.removeAll { $0.caseInsensitiveCompare(kw) == .orderedSame }
        syncConstraintsFromKeywords()
    }
    private func syncConstraintsFromKeywords() {
        let separators: Set<Character> = [",", ";", "\n"]
        let lowerKeywordSet = Set(keywords.map { $0.lowercased() })
        let rawParts = criteria.contraintes.split { ch in separators.contains(ch) }
        let trimmed = rawParts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let others = trimmed.filter { part in
            guard !part.isEmpty else { return false }
            return !lowerKeywordSet.contains(part.lowercased())
        }
        let combined = keywords + others
        let unique = combined.uniqued(caseInsensitive: true)
        criteria.contraintes = unique.joined(separator: ", ")
    }
    private func syncKeywordsFromConstraints() {
        let separators: Set<Character> = [",", ";", "\n"]
        let rawParts = criteria.contraintes.split { ch in separators.contains(ch) }
        let parts = rawParts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        keywords = parts.uniqued(caseInsensitive: true)
    }

    private func generate() {
        errorMessage = nil
        generated = ""
        syncConstraintsFromKeywords()
        let targetWords = Int(wordCount)
        if useOnlineAI {
            guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                errorMessage = "Clé API requise."
                return
            }
            isLoading = true
            Task {
                do {
                    let gen = OpenAITextGenerator(apiKey: apiKey, model: "gpt-4o-mini", temperature: temperature)
                    let text = try await gen.generate(criteria: convert(criteria), wordCount: targetWords)
                    await MainActor.run {
                        generated = text
                        isLoading = false
                        // Sauvegarder la clé API
                        try? SecureStore.save(key: apiKeyStorageKey, data: Data(apiKey.utf8))
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                        isLoading = false
                    }
                }
            }
        } else {
            let text = LocalAIGenerator.generate(criteria: criteria, wordCount: targetWords)
            generated = text
        }
    }

    private func loadStoredKeyIfAny() {
        if let data = SecureStore.load(key: apiKeyStorageKey), let stored = String(data: data, encoding: .utf8) {
            apiKey = stored
        }
    }

    private func convert(_ local: LocalAICriteria) -> AIGeneratorCriteria {
        var c = AIGeneratorCriteria()
        c.sujet = local.sujet
        c.objectif = AIGeneratorCriteria.Objectif(rawValue: local.objectif.rawValue) ?? .informer
        c.ton = AIGeneratorCriteria.Ton(rawValue: local.ton.rawValue) ?? .amical
        c.publicCible = AIGeneratorCriteria.PublicCible(rawValue: local.publicCible.rawValue) ?? .grandPublic
        c.style = AIGeneratorCriteria.Style(rawValue: local.style.rawValue) ?? .storytelling
        c.contraintes = local.contraintes
        return c
    }
}

private extension Array where Element == String {
    func uniqued(caseInsensitive: Bool) -> [String] {
        if !caseInsensitive { return Array(Set(self)) }
        var seen = Set<String>()
        var out: [String] = []
        for s in self {
            let key = s.lowercased()
            if !seen.contains(key) { seen.insert(key); out.append(s) }
        }
        return out
    }
}

private enum LocalAIGenerator {
    static func generate(criteria: LocalAICriteria, wordCount: Int) -> String {
        let wc = max(10, min(1200, wordCount))
        var lines: [String] = []

        let sujet = criteria.sujet.isEmpty ? "votre sujet" : criteria.sujet
        let motsContraintes = criteria.contraintes
            .split{ $0 == "," || $0 == ";" || $0 == "\n" }
            .map{ $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter{ !$0.isEmpty }

        // Accroches
        let accroches = accrochesPour(criteria: criteria, sujet: sujet)
        lines.append(contentsOf: accroches)
        // Corps
        lines.append(contentsOf: paragraphesPour(criteria: criteria, sujet: sujet, contraintes: motsContraintes))
        // Insérer naturellement les mots-clés
        var rng = SystemRandomNumberGenerator()
        lines = weaveKeywords(motsContraintes, into: lines, using: &rng)
        // Conclusion
        lines.append(contentsOf: conclusionsPour(criteria: criteria, sujet: sujet))

        // Nettoyage: supprimer doublons exacts et espaces superflus
        var seen = Set<String>()
        let unique = lines.compactMap { s -> String? in
            let t = s.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty || seen.contains(t.lowercased()) { return nil }
            seen.insert(t.lowercased()); return t
        }

        let text = unique.joined(separator: " ")
        // Contrainte de mots
        let words = text.components(separatedBy: CharacterSet.whitespacesAndNewlines).filter{ !$0.isEmpty }
        if words.count <= wc { return text }
        var count = 0
        var builder: [String] = []
        for w in words { builder.append(w); count += 1; if count >= wc { break } }
        var truncated = builder.joined(separator: " ")
        if let lastDot = truncated.lastIndex(of: ".") ?? truncated.lastIndex(of: "!") ?? truncated.lastIndex(of: "?") {
            truncated = String(truncated[...lastDot])
        } else {
            truncated.append("…")
        }
        return truncated
    }

    // Insère des mots-clés de façon naturelle avec des variantes
    private static func weaveKeywords(_ keywords: [String], into lines: [String], using rng: inout SystemRandomNumberGenerator) -> [String] {
        guard !keywords.isEmpty else { return lines }
        var result = lines
        let variants = [
            { (kw: String) in "Par exemple : \(kw)." },
            { (kw: String) in "Notamment \(kw), qui tombe à pic." },
            { (kw: String) in "Comme \(kw), à garder en tête." },
            { (kw: String) in "Incluant \(kw), pour faire simple." },
            { (kw: String) in "Un mot-clé utile : \(kw)." }
        ]
        // Positions d'insertion: après l'accroche et au milieu des paragraphes
        let insertPositions = [min(1, result.count), max(2, result.count/2), max(3, result.count-2)]
        var posIdx = 0
        for kw in keywords.uniqued(caseInsensitive: true) {
            // Évite le doublon si déjà présent dans le texte
            if result.joined(separator: " ").localizedCaseInsensitiveContains(kw) { continue }
            let builder = variants.randomElement(using: &rng)?(kw) ?? kw
            let idx = min(max(0, insertPositions[min(posIdx, insertPositions.count-1)]), max(0, result.count))
            result.insert(builder, at: idx)
            posIdx += 1
        }
        return result
    }

    // Conclusion adaptée à l'objectif
    private static func conclusionsPour(criteria: LocalAICriteria, sujet: String) -> [String] {
        switch criteria.objectif {
        case .informer:
            return ["Envie d'en savoir plus ? Passons à la suite."]
        case .convaincre:
            return ["On essaie maintenant ? Un premier pas suffit."]
        case .divertir:
            return ["On continue ? La meilleure partie arrive."]
        case .inspirer:
            return ["Prêt·e ? On se lance."]
        }
    }

    private static func accrochesPour(criteria: LocalAICriteria, sujet: String) -> [String] {
        var rng = SystemRandomNumberGenerator()
        let referent = randomReferent(for: sujet, using: &rng)
        let prefaces: [String] = [
            "Imaginez ceci :",
            "Fermez les yeux un instant :",
            "Et si on partait à l'aventure ?",
            "On se raconte une histoire ?",
            "Voici le décor :"
        ]
        let invites: [String] = [
            "Suivez-moi.",
            "Vous êtes prêt·e ?",
            "Prenez une grande inspiration.",
            "Allons-y, pas à pas.",
            "C'est parti !"
        ]
        let templatesStory = [
            "\(prefaces.randomElement(using: &rng)!) \(capitalized(referent)) entre en scène.",
            "Un jour, \(referent) a frappé à notre porte — curieux et un peu mystérieux.",
            "Tout commence simplement : \(referent) et une question, la nôtre : pourquoi pas ?",
            "— « Et si on parlait de \(sujet) ? », chuchote une petite voix."
        ]
        let templatesOther = [
            "\(prefaces.randomElement(using: &rng)!) Parlons de \(referent). \(invites.randomElement(using: &rng)!)",
            "Aujourd'hui, cap sur \(referent). Ni jargon, ni détour.",
            "Petit détour par \(referent) pour poser le cadre."
        ]
        let base = criteria.style == .storytelling ? templatesStory : templatesOther
        return sampleUnique(from: base, count: 1, using: &rng)
    }

    private static func paragraphesPour(criteria: LocalAICriteria, sujet: String, contraintes: [String]) -> [String] {
        var rng = SystemRandomNumberGenerator()
        let referent = randomReferent(for: sujet, using: &rng)
        let connectors = ["D'abord", "Ensuite", "Puis", "Enfin", "Par la suite", "En pratique", "Concrètement"]
        let sensory = [
            "On entend le léger bourdonnement des idées qui s'assemblent.",
            "Une odeur de nouveauté flotte dans l'air.",
            "Au toucher, tout paraît plus simple qu'il n'y paraît.",
            "La scène prend des couleurs : vives, nettes, joyeuses.",
            "Le rythme s'installe, calme et régulier."
        ]
        let dialogues = [
            "— « Je crois qu'on tient quelque chose », souffle quelqu'un.",
            "— « Et si on essayait autrement ? », propose une voix malicieuse.",
            "— « Ça marche ! », s'écrie-t-on au fond de la salle."
        ]

        var lines: [String] = []
        switch criteria.style {
        case .storytelling:
            let pool = [
                "Au départ, \(referent) semblait loin de nous. Puis un détail a tout changé.",
                "\(connectors.randomElement(using: &rng)!), on donne une forme simple à l'idée — juste assez pour l'apprivoiser.",
                "Par petites touches, on teste, on ajuste, on sourit : ça avance.",
                sampleUnique(from: dialogues, count: 1, using: &rng).first!,
                sampleUnique(from: sensory, count: 1, using: &rng).first!
            ]
            lines.append(contentsOf: sampleUnique(from: pool, count: 3, using: &rng))
        case .tutoriel:
            let steps = [
                "\(connectors[0]) : clarifier l'objectif — savoir ce que l'on attend de \(referent).",
                "\(connectors[1]) : découper en mini‑étapes mesurables.",
                "\(connectors[2]) : essayer, observer, corriger.",
                "\(connectors[3]) : partager le résultat et la méthode."
            ]
            lines.append(contentsOf: steps)
        case .liste:
            let bullets = [
                "• Pourquoi c'est utile : \(referent) améliore le quotidien.",
                "• Le point clé : simple, clair, duplicable.",
                "• À retenir : commencer petit, progresser vite."
            ]
            lines.append(contentsOf: bullets)
        case .discours:
            let speech = [
                "Nous avons une opportunité : faire de \(referent) un levier d'impact positif.",
                "En unissant nos forces, nous irons plus loin, plus sereinement.",
                "Chaque action, si petite soit‑elle, compte vraiment."
            ]
            lines.append(contentsOf: speech)
        case .annonce:
            let announce = [
                "La nouvelle du jour : \(referent) arrive avec des bénéfices concrets.",
                "Démonstrations à venir, exemples à l'appui.",
                "Restez à l'écoute : d'autres détails suivront."
            ]
            lines.append(contentsOf: announce)
        }

        // Tonalité finale
        let closersAmicaux = [
            "En bref, on avance ensemble, pas à pas.",
            "Promis, rien de sorcier : on s'y met et ça prend." ]
        let closersPro = [
            "Conclusion provisoire : objectifs, risques et prochaines étapes sont cadrés.",
            "Cap sur l'essentiel : mesurer, ajuster, partager." ]
        let closersInspirants = [
            "Souvenez‑vous : chaque petit pas ouvre une grande porte.",
            "On y est presque — encore un effort et ça décolle." ]
        let closersHumor = [
            "Morale : le café aide… mais pas autant qu'une bonne idée.",
            "Note pour plus tard : penser simple, agir joyeux." ]
        let closersNeutres = [
            "Synthèse : points clés recensés et pistes d'action prêtes.",
            "Bilan : avancées notées, prochaines étapes planifiées." ]

        switch criteria.ton {
        case .amical: lines.append(closersAmicaux.randomElement(using: &rng)!)
        case .professionnel: lines.append(closersPro.randomElement(using: &rng)!)
        case .inspirant: lines.append(closersInspirants.randomElement(using: &rng)!)
        case .humoristique: lines.append(closersHumor.randomElement(using: &rng)!)
        case .neutre: lines.append(closersNeutres.randomElement(using: &rng)!)
        }

        // Ne plus ajouter la liste brute des mots-clés pour éviter les répétitions
        return lines
    }

    // MARK: - Helpers variété
    private static func sampleUnique<T>(from array: [T], count: Int, using rng: inout SystemRandomNumberGenerator) -> [T] {
        if array.isEmpty { return [] }
        var idxs = Array(array.indices)
        idxs.shuffle(using: &rng)
        return idxs.prefix(max(0, min(count, array.count))).map { array[$0] }
    }
    private static func randomReferent(for sujet: String, using rng: inout SystemRandomNumberGenerator) -> String {
        let options = [sujet, "ce sujet", "cette idée", "le projet", "le thème"]
        return options.randomElement(using: &rng) ?? sujet
    }
    private static func capitalized(_ s: String) -> String { s.prefix(1).uppercased() + s.dropFirst() }
}

private extension ContentView {
    var background: LinearGradient {
        currentTheme.gradient
    }
    var primaryAccent: Color {
        currentTheme.primaryColor
    }
    var backgroundTopFade: Color { 
        currentTheme.isDark ? Color.black.opacity(0.4) : Color.black.opacity(0.25) 
    }
    var backgroundBottomFade: Color { 
        currentTheme.isDark ? Color.black.opacity(0.4) : Color.black.opacity(0.25) 
    }

    func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    func handlePlayPause() {
        // If countdown is running, cancel it
        if countdownTimer != nil {
            cancelCountdown()
            return
        }
        if isPlaying {
            isPlaying = false
            if voiceEnabled { speechSynthesizer.pause() }
            return
        }
        // Stop frameSpeaker before starting playback (avoid audio conflict)
        frameSpeaker.stop()
        if countdownEnabled && !hasStartedOnce {
            startCountdown()
        } else if hasStartedOnce {
            // Resume from pause — don't reset voice tracking
            resumePlayback()
        } else {
            startPlayback()
        }
    }
    
    func startPlayback() {
        isPlaying = true
        hasStartedOnce = true
        showSpeedControl = false
        if voiceEnabled {
            speechSynthesizer.speechRate = Float(speechRate)
            speechSynthesizer.startPromptMode()
        }
    }
    
    func resumePlayback() {
        isPlaying = true
        showSpeedControl = false
        if voiceEnabled {
            speechSynthesizer.speechRate = Float(speechRate)
            speechSynthesizer.resumePromptMode()
        }
    }
    
    func speakFrameText(_ text: String) {
        frameSpeaker.voiceIdentifier = speechSynthesizer.selectedVoiceIdentifier
        frameSpeaker.rate = Float(speechRate)
        frameSpeaker.speak(text)
    }
    
    func requestSpeakVisibleText() {
        // Don't allow if prompter is playing
        guard !isPlaying else { return }
        if frameSpeaker.isSpeaking {
            frameSpeaker.stop()
            return
        }
        // Stop speech synthesizer if it was still finishing
        speechSynthesizer.stop()
        // Request text extraction — the callback will call speakFrameText directly
        requestVisibleText = true
    }

    func startCountdown() {
        guard countdownValue == nil else { return }
        countdownValue = 3
        isPlaying = false
        var remaining = 3
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            remaining -= 1
            if remaining <= 0 {
                timer.invalidate()
                DispatchQueue.main.async {
                    self.countdownTimer = nil
                    self.countdownValue = nil
                    self.startPlayback()
                }
            } else {
                DispatchQueue.main.async { self.countdownValue = remaining }
            }
        }
        countdownTimer = timer
    }
    
    func cancelCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        countdownValue = nil
    }

    func saveCurrentText() {
        let finalTitle = textTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty 
            ? "Texte du \(DateFormatter.shortDate.string(from: Date()))" 
            : textTitle
        let result = store.add(title: finalTitle, content: inputText)
        
        switch result {
        case .success: haptic(.rigid)
        case .limitReached:
            showLimitAlert = true
            haptic(.heavy)
        }
    }
    
    func voiceDisplayName(_ voice: AVSpeechSynthesisVoice) -> String {
        var name = voice.name
        if voice.quality == .enhanced { name += " ✨" }
        let locale = Locale(identifier: voice.language)
        let regionCode: String?
        if #available(iOS 16, *) {
            regionCode = locale.region?.identifier
        } else {
            regionCode = locale.regionCode
        }
        if let code = regionCode,
           let regionName = Locale.current.localizedString(forRegionCode: code) {
            name += " (\(regionName))"
        }
        return name
    }

    @ViewBuilder
    func countdownOverlay(_ value: Int) -> some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            Text("\(value)")
                .font(Theme.roundedFont(size: 80, weight: .bold))
                .foregroundColor(.white)
                .transition(.scale)
        }
        .animation(.easeOut(duration: 0.2), value: value)
    }
    
    // MARK: - Options Sheet (simplified - no duplicates)
    @ViewBuilder
    var optionsSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("Lecture vocale")) {
                    if voiceEnabled {
                        Picker("Voix", selection: $speechSynthesizer.selectedVoiceIdentifier) {
                            ForEach(speechSynthesizer.availableVoices, id: \.identifier) { voice in
                                Text(voiceDisplayName(voice)).tag(voice.identifier)
                            }
                        }
                        
                        Button(action: {
                            if speechSynthesizer.isSpeaking {
                                speechSynthesizer.stop()
                            } else {
                                speechSynthesizer.speechRate = Float(speechRate)
                                speechSynthesizer.speak("Bonjour, je suis votre lecteur.")
                                // speechRate is derived from scroll speed automatically
                            }
                        }) {
                            Label(
                                speechSynthesizer.isSpeaking ? "Arrêter" : "Tester la voix",
                                systemImage: speechSynthesizer.isSpeaking ? "stop.fill" : "play.fill"
                            )
                        }
                    } else {
                        Text("Activez la voix avec le bouton dans les contrôles")
                            .foregroundColor(.secondary)
                            .font(.footnote)
                    }
                }
                
                Section(header: Text("Affichage")) {
                    ColorPicker("Couleur syllabe 1", selection: $color1)
                    ColorPicker("Couleur syllabe 2", selection: $color2)
                    
                    HStack {
                        Text("Marges")
                        Slider(value: $sidePadding, in: 10...50)
                        Text("\(Int(sidePadding))")
                            .monospacedDigit()
                            .frame(width: 30)
                    }
                    
                    HStack {
                        Text("Taille du cadre")
                        Slider(value: $readCardFraction, in: 0.25...0.80)
                        Text("\(Int(readCardFraction * 100))%")
                            .monospacedDigit()
                            .frame(width: 40)
                    }
                    
                    Toggle("Compte à rebours", isOn: $countdownEnabled)
                }
                
                Section(header: Text("Bibliothèque")) {
                    Button { 
                        showOptions = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showLibrary = true
                        }
                    } label: { 
                        Label("Ouvrir la bibliothèque", systemImage: "books.vertical") 
                    }
                }
            }
            .navigationTitle("Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("OK") { showOptions = false }
                }
            }
        }
    }
}

extension DateFormatter {
    static let shortDate: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .none
        df.locale = Locale(identifier: "fr_FR")
        return df
    }()
    static let longDateTime: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        df.locale = Locale(identifier: "fr_FR")
        return df
    }()
}

#if canImport(UIKit)
// Compatibility wrapper: safely applies iOS 16's scrollDismissesKeyboard when available
extension View {
    @ViewBuilder
    func scrollDismissesKeyboardCompatInteractively() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollDismissesKeyboard(.interactively)
        } else {
            self
        }
    }
    
    // Compatibility wrapper: safely applies iOS 16's scrollContentBackground when available
    @ViewBuilder
    func scrollContentBackgroundHiddenCompat() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}
#endif

import Translation

// Extension pour la traduction système iOS 17.4+
extension View {
    @ViewBuilder
    func translationPresentationCompat(isPresented: Binding<Bool>, text: String) -> some View {
        if #available(iOS 17.4, *) {
            self.translationPresentation(isPresented: isPresented, text: text)
        } else {
            self.sheet(isPresented: isPresented) {
                VStack(spacing: 20) {
                    Image(systemName: "character.book.closed")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("Traduction")
                        .font(.title2.bold())
                    Text("La traduction système nécessite iOS 17.4 ou ultérieur.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Afficher le texte à traduire
                    ScrollView {
                        Text(text)
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                    }
                    .frame(maxHeight: 200)
                    .padding(.horizontal)
                    
                    Button("Fermer") {
                        isPresented.wrappedValue = false
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .modifier(PresentationDetentsModifier())
            }
        }
    }
}

// Modificateur de compatibilité pour presentationDetents
private struct PresentationDetentsModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.presentationDetents([.medium])
        } else {
            content
        }
    }
}

#if DEBUG
extension ContentView {
    init(previewMode: Mode? = nil) {
        self.init()
        if let m = previewMode { _mode = State(initialValue: m) }
        _inputText = State(initialValue: SampleText.fr)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView(previewMode: .edit)
                .previewDisplayName("Éditer")
                .previewDevice("iPhone 15 Pro")
            ContentView(previewMode: .read)
                .previewDisplayName("Lire")
                .previewDevice("iPhone 15 Pro")
            ContentView(previewMode: .read)
                .previewDisplayName("iPad")
                .previewDevice("iPad Pro (12.9-inch) (6th generation)")
        }
    }
}
#endif
