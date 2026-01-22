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
    @Published var speechRate: Float = 0.5 // 0.0 à 1.0 (0.5 = normal)
    
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
                self?.isSpeaking = false
                self?.isPaused = false
            },
            onPause: { [weak self] in
                self?.isPaused = true
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
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = selectedVoice ?? AVSpeechSynthesisVoice(language: "fr-FR")
        utterance.rate = speechRate
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0.2
        
        isSpeaking = true
        isPaused = false
        synthesizer.speak(utterance)
    }
    
    func pause() {
        if synthesizer.isSpeaking && !isPaused {
            synthesizer.pauseSpeaking(at: .word)
        }
    }
    
    func resume() {
        if isPaused {
            synthesizer.continueSpeaking()
        }
    }
    
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        isPaused = false
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

// Définition déplacée ici pour être visible avant usage dans ContentView
private enum SampleText {
    static let fr = """
Bonjour ! Je m'appelle Léo et j'adore lire avec mon prompteur magique.

Il défile tout seul et colore les sylla-bes en alternant les couleurs pour m'aider à bien pro-non-cer. C'est amusant et très pra-tique !
"""
}

struct ContentView: View {
    enum Mode: String, CaseIterable, Identifiable { 
        case edit = "Éditer", read = "Lire", ai = "Créer", library = "Bibliothèque"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .edit: return "pencil"
            case .read: return "play.fill"
            case .ai: return "sparkles"
            case .library: return "books.vertical"
            }
        }
    }

    @State private var mode: Mode = .read
    @State private var inputText: String = SampleText.fr
    @State private var isPlaying: Bool = false
    @State private var speed: Double = 80 // points per second
    @State private var colorSyllables: Bool = true
    @State private var fontSize: Double = 36
    @State private var mirror: Bool = false
    @State private var countdownEnabled: Bool = true
    @State private var countdownValue: Int? = nil
    @State private var showSavedSheet: Bool = false
    @State private var showOptions: Bool = false
    @StateObject private var store = TextStore()
    @State private var kidMode: Bool = true
    @State private var textTitle: String = ""

    @State private var currentTheme: AppTheme = .candy
    @State private var color1: Color = .blue
    @State private var color2: Color = .pink
    @State private var centerAlign: Bool = true
    @State private var sidePadding: Double = 28
    @State private var fullScreenRead: Bool = false
    @State private var readProgress: CGFloat = 0
    @State private var readCardFraction: Double = 0.40 // fraction of screen height for reader card
    @FocusState private var focusedField: EditField?
    @State private var showClearAlert: Bool = false
    @State private var isSpeaking: Bool = false
    @State private var showTranslation: Bool = false
    @State private var voiceEnabled: Bool = false // Activer la lecture vocale
    @State private var speechRate: Double = 0.5 // Vitesse de lecture vocale (0.0-1.0)
    @StateObject private var speechSynthesizer = SpeechSynthesizer()
    @State private var showHelp: Bool = false // Mode d'emploi
    @State private var showPremium: Bool = false // Page Premium
    @State private var showLimitAlert: Bool = false // Alerte limite atteinte
    @EnvironmentObject private var purchaseManager: PurchaseManager

    enum EditField { case title, body }

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
    private var attributedReader: NSAttributedString {
        let font = UIFont.systemFont(ofSize: CGFloat(fontSize), weight: .regular).withDesign(UIFontDescriptor.SystemDesign.rounded) ?? UIFont.systemFont(ofSize: CGFloat(fontSize))
        return Syllabifier.attributed(
            text: inputText,
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
                if !fullScreenRead && mode != .edit && mode != .library {
                    header
                }
                if !fullScreenRead {
                    modernModePicker
                }
                Group {
                    if mode == .edit { editorView }
                    else if mode == .read { readerView }
                    else if mode == .ai { aiView }
                    else { libraryView }
                }
                .id(mode)
            }
            .padding(.bottom, (mode == .read && !fullScreenRead) ? controlBarPadding : 0)
            if let value = countdownValue { countdownOverlay(value) }
        }
        .safeAreaInset(edge: .bottom) {
            if mode == .read && !fullScreenRead { controlBar } else { Color.clear.frame(height: 0) }
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
            Button("Passer Premium") {
                showPremium = true
            }
        } message: {
            Text("Vous avez atteint la limite de \(PurchaseManager.freeTextLimit) textes en mode gratuit. Passez Premium pour sauvegarder des textes illimités !")
        }
        .sheet(isPresented: $showPremium) {
            PremiumView()
        }
        .translationPresentationCompat(isPresented: $showTranslation, text: inputText)
    }

    private var header: some View {
        VStack(spacing: 16) {
            // Ligne 1: Titre + Thème
            HStack {
                HStack(spacing: 8) {
                    Text("Prompteur")
                        .font(Theme.roundedFont(size: 28, weight: .bold))
                        .foregroundColor(currentTheme.isDark ? .white : .primary)
                    
                    // Badge Premium (si premium)
                    PremiumBadge()
                }
                
                Spacer()
                
                // Bouton thème
                Menu {
                    ForEach(AppTheme.allCases) { t in
                        Button(action: { 
                            withAnimation(.spring(response: 0.4)) {
                                currentTheme = t 
                            }
                            haptic(.light)
                        }) {
                            Label("\(t.icon) \(t.rawValue)", systemImage: currentTheme == t ? "checkmark.circle.fill" : "circle")
                        }
                    }
                } label: {
                    Text(currentTheme.icon)
                        .font(.title2)
                        .padding(10)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                        )
                }
                .foregroundColor(currentTheme.isDark ? .white : .primary)
            }
            
            // Bannière Premium (si non premium) - bien visible
            if !purchaseManager.isPremium {
                Button(action: { showPremium = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.yellow)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Passez Premium")
                                .font(Theme.roundedFont(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            Text("Textes illimités • Achat unique")
                                .font(Theme.roundedFont(size: 12))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [.purple, .pink, .orange],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: .purple.opacity(0.3), radius: 8, y: 4)
                }
                .buttonStyle(PlainButtonStyle())
            }

            // Ligne 2: Boutons d'action
            HStack(spacing: 12) {
                Button(action: { 
                    inputText = SampleText.fr
                    isPlaying = false
                    haptic(.light)
                }) {
                    Label("Exemple", systemImage: "text.quote")
                        .font(Theme.roundedFont(size: 14, weight: .medium))
                }
                .buttonStyle(.bordered)
                .tint(currentTheme.primaryColor)
                
                Spacer()
                
                // Bouton Mode d'emploi
                Button(action: { 
                    showHelp = true
                    haptic(.light)
                }) {
                    Label("Aide", systemImage: "questionmark.circle")
                        .font(Theme.roundedFont(size: 14, weight: .medium))
                }
                .buttonStyle(.bordered)
                .tint(currentTheme.accentColor)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .sheet(isPresented: $showHelp) {
            HelpView()
        }
    }
    
    // MARK: - Mode Picker moderne
    private var modernModePicker: some View {
        HStack(spacing: 8) {
            ForEach(Mode.allCases) { m in
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        mode = m
                    }
                    haptic(.light)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: m.icon)
                            .font(.system(size: 14, weight: .semibold))
                        if mode == m {
                            Text(m.rawValue)
                                .font(Theme.roundedFont(size: 14, weight: .semibold))
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, mode == m ? 16 : 12)
                    .padding(.vertical, 12)
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
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                // Barre d'outils d'édition
                editorToolbar
                
                // Title field card (placeholder + focus)
                ZStack(alignment: .leading) {
                    if textTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Titre")
                            .foregroundColor(.secondary)
                            .padding(.leading, 18)
                    }
                    TextField("", text: $textTitle)
                        .font(Theme.roundedFont(size: 22, weight: .semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .focused($focusedField, equals: .title)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .body }
                        .accessibilityLabel("Titre")
                }
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.95))
                )
                .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
                .padding(.horizontal)

                // Main editor card (no preview, clean and spacious)
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $inputText)
                        .font(Theme.roundedFont(size: CGFloat(fontSize)))
                        .padding(16)
                        .frame(minHeight: 320)
                        .focused($focusedField, equals: .body)
                    if inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Écrivez ou collez votre texte ici…")
                            .foregroundColor(.secondary)
                            .padding(.top, 24)
                            .padding(.leading, 24)
                            .allowsHitTesting(false)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(0.98))
                )
                .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .padding(.top, 10)
            .padding(.bottom, 30)
        }
        .scrollDismissesKeyboardCompatInteractively()
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Button("Terminer") { focusedField = nil }
                Spacer()
                Button(role: .destructive) { showClearAlert = true } label: {
                    Label("Effacer", systemImage: "trash")
                }
                Button {
                    saveCurrentText()
                } label: { Label("Enregistrer", systemImage: "square.and.arrow.down") }
            }
        }
    }

    private var readerView: some View {
        GeometryReader { proxy in
            // Reader card height based on readCardFraction of screen height
            let h = proxy.size.height * readCardFraction
            VStack {
                ZStack {
                    TeleprompterTextView(attributedText: .constant(attributedReader),
                                         isPlaying: $isPlaying,
                                         speed: CGFloat(speed),
                                         mirror: mirror,
                                         sidePadding: CGFloat(sidePadding)) {
                        DispatchQueue.main.async { [self] in
                            isPlaying = false
                            // Arrêter la lecture vocale si elle est active
                            if voiceEnabled {
                                speechSynthesizer.stop()
                            }
                        }
                    } onProgress: { p in
                        DispatchQueue.main.async {
                            readProgress = p
                        }
                    }
                // Fades
                VStack {
                    let fadeH = max(8.0, min(CGFloat(h) * 0.15, 24.0))
                    LinearGradient(colors: [backgroundTopFade, .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: fadeH)
                        .allowsHitTesting(false)
                    Spacer()
                    LinearGradient(colors: [.clear, backgroundBottomFade], startPoint: .top, endPoint: .bottom)
                        .frame(height: fadeH)
                        .allowsHitTesting(false)
                }
                // Full-screen toggle
                HStack {
                    Spacer()
                    Button(action: { fullScreenRead.toggle(); haptic(.light) }) {
                        Image(systemName: fullScreenRead ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Circle().fill(Color.black.opacity(0.25)))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
                .frame(maxWidth: .infinity, maxHeight: h)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
            .padding(.horizontal)
            .padding(.top, 60)
            // Progress bar under the card
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.25))
                GeometryReader { gp in
                    Capsule().fill(Theme.friendlyGreen.opacity(0.9))
                        .frame(width: max(6, gp.size.width * readProgress))
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    // Nouvelle vue IA
    private var aiView: some View {
        AICreationInlineView(onInsert: { newText in
            inputText = newText
            mode = .edit
            haptic(.rigid)
        }, onClose: {
            mode = .edit
            haptic(.light)
        })
    }
    // Vue Bibliothèque (mode .library)
    private var libraryView: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Bibliothèque")
                    .font(Theme.roundedFont(size: 30, weight: .bold))
                Spacer()
                Button { mode = .edit } label: {
                    Label("Retour", systemImage: "chevron.left")
                }
                .buttonStyle(DefaultButtonStyle())
            }
            .padding(.horizontal)

            // Bloc ajout du texte courant
            VStack(alignment: .leading, spacing: 14) {
                Text("Ajouter le texte courant")
                    .font(Theme.roundedFont(size: 18, weight: .semibold))
                TextField("Titre", text: $textTitle)
                    .textFieldStyle(.roundedBorder)
                    .font(Theme.roundedFont(size: 16))
                HStack {
                    Button(action: { saveCurrentText() }) {
                        Label("Ajouter à la bibliothèque", systemImage: "plus.circle.fill")
                            .font(Theme.roundedFont(size: 16, weight: .semibold))
                    }
                    .buttonStyle(DefaultButtonStyle())
                    .tint(Theme.friendlyGreen)
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Spacer()
                    Button(action: {
                        inputText = ""
                        haptic(.light)
                    }) {
                        Label("Vider", systemImage: "trash")
                            .font(Theme.roundedFont(size: 14, weight: .semibold))
                    }
                    .buttonStyle(DefaultButtonStyle())
                    .tint(Theme.accent)
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ScrollView {
                    Text(inputText.isEmpty ? "(Texte vide)" : inputText)
                        .font(Theme.roundedFont(size: 14))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 140)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.95)))
            .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
            .padding(.horizontal)

            // Liste des entrées
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Mes entrées (") + Text("\(store.items.count)").monospacedDigit() + Text(")")
                        .font(Theme.roundedFont(size: 18, weight: .bold))
                    Spacer()
                    
                    // Indicateur de limite pour utilisateurs gratuits
                    if !purchaseManager.isPremium {
                        Text("\(store.items.count)/\(PurchaseManager.freeTextLimit)")
                            .font(Theme.roundedFont(size: 14, weight: .semibold))
                            .foregroundColor(store.items.count >= PurchaseManager.freeTextLimit ? .red : .secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(store.items.count >= PurchaseManager.freeTextLimit ? Color.red.opacity(0.1) : Color.secondary.opacity(0.1))
                            )
                    }
                    
                    if !store.items.isEmpty {
                        EditButton()
                    }
                }
                
                // Bannière Premium si limite atteinte
                if !purchaseManager.isPremium && store.items.count >= PurchaseManager.freeTextLimit {
                    Button(action: { showPremium = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.orange)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Limite atteinte")
                                    .font(Theme.roundedFont(size: 14, weight: .bold))
                                Text("Passez Premium pour des textes illimités")
                                    .font(Theme.roundedFont(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [.orange.opacity(0.1), .pink.opacity(0.1)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.vertical, 4)
                }
                
                if store.items.isEmpty {
                    Text("Aucune entrée enregistrée pour l'instant.")
                        .font(Theme.roundedFont(size: 14))
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                } else {
                    List {
                        ForEach(store.items) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .center) {
                                    Text(item.title)
                                        .font(Theme.roundedFont(size: 16, weight: .semibold))
                                        .lineLimit(1)
                                    Spacer()
                                    Button {
                                        inputText = item.content
                                        textTitle = item.title
                                        mode = .edit
                                        haptic(.rigid)
                                    } label: {
                                        Image(systemName: "square.and.arrow.down.on.square")
                                            .foregroundColor(Theme.primary)
                                            .imageScale(.medium)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .accessibilityLabel("Charger dans l'éditeur")
                                }
                                Text(DateFormatter.longDateTime.string(from: item.date))
                                    .font(Theme.roundedFont(size: 12))
                                    .foregroundColor(.secondary)
                                let preview = item.content.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !preview.isEmpty {
                                    Text(preview.count > 140 ? String(preview.prefix(140)) + "…" : preview)
                                        .font(Theme.roundedFont(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete { store.remove(at: $0) }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .padding(.horizontal)
            Spacer(minLength: 0)
        }
    }

    private var controlBar: some View {
        VStack(spacing: 16) {
            // Bouton Play/Pause central avec effet moderne
            HStack(spacing: 20) {
                // Bouton Stop
                Button(action: { 
                    isPlaying = false
                    // Arrêter aussi la lecture vocale
                    if voiceEnabled {
                        speechSynthesizer.stop()
                    }
                    haptic(.light) 
                }) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(
                            Circle()
                                .fill(Theme.accent.opacity(0.9))
                        )
                        .shadow(color: Theme.accent.opacity(0.3), radius: 8, y: 4)
                }
                .buttonStyle(PlainButtonStyle())

                // Bouton Play/Pause principal
                Button(action: { 
                    handlePlayPause()
                    haptic(.medium) 
                }) {
                    ZStack {
                        // Cercle extérieur animé
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [currentTheme.primaryColor, currentTheme.accentColor],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 4
                            )
                            .frame(width: 88, height: 88)
                            .scaleEffect(isPlaying ? 1.1 : 1.0)
                            .opacity(isPlaying ? 0.5 : 1.0)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isPlaying)
                        
                        // Cercle principal
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 78, height: 78)
                            .background(
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [currentTheme.primaryColor, currentTheme.accentColor.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .shadow(color: currentTheme.primaryColor.opacity(0.4), radius: 12, y: 6)
                            .scaleEffect(isPlaying ? 0.95 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPlaying)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel(isPlaying ? "Pause" : "Lecture")

                // Bouton Options
                Button(action: { showOptions = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(currentTheme.isDark ? .white : .primary)
                        .frame(width: 50, height: 50)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                }
                .buttonStyle(PlainButtonStyle())
            }

            // Contrôles rapides avec design moderne
            HStack(spacing: 12) {
                // Syllabes
                ControlToggleButton(
                    icon: "textformat.abc",
                    label: "Syllabes",
                    isOn: $colorSyllables,
                    tintColor: currentTheme.primaryColor
                )
                
                // Lecture vocale
                ControlToggleButton(
                    icon: "speaker.wave.2.fill",
                    label: "Voix",
                    isOn: $voiceEnabled,
                    tintColor: currentTheme.primaryColor
                )
                
                // Miroir
                ControlToggleButton(
                    icon: "arrow.left.and.right.righttriangle.left.righttriangle.right",
                    label: "Miroir",
                    isOn: $mirror,
                    tintColor: currentTheme.primaryColor
                )
                
                // Centrer
                ControlToggleButton(
                    icon: "text.aligncenter",
                    label: "Centrer",
                    isOn: $centerAlign,
                    tintColor: currentTheme.primaryColor
                )
                
                // Bibliothèque
                Button {
                    showSavedSheet = true
                    haptic(.light)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "books.vertical.fill")
                            .font(.system(size: 18))
                        Text("Textes")
                            .font(Theme.roundedFont(size: 10, weight: .medium))
                    }
                    .foregroundColor(currentTheme.isDark ? .white.opacity(0.8) : .primary.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 20, y: -5)
        )
        .padding(.horizontal, 8)
        .sheet(isPresented: $showSavedSheet) {
            savedTextsSheet
        }
        .sheet(isPresented: $showOptions) { optionsSheet }
    }
    
    // MARK: - Sheet pour textes sauvegardés
    private var savedTextsSheet: some View {
        NavigationView {
            List {
                ForEach(store.items) { item in
                    Button {
                        inputText = item.content
                        showSavedSheet = false
                        isPlaying = false
                        haptic(.light)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.title)
                                .font(Theme.roundedFont(size: 18, weight: .semibold))
                            Text(DateFormatter.longDateTime.string(from: item.date))
                                .font(Theme.roundedFont(size: 12))
                                .foregroundColor(.secondary)
                            let preview = item.content.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !preview.isEmpty {
                                Text(preview.count > 100 ? String(preview.prefix(100)) + "…" : preview)
                                    .font(Theme.roundedFont(size: 13))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .foregroundColor(.primary)
                }
                .onDelete { store.remove(at: $0) }
            }
            .navigationTitle("Mes textes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { 
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") { showSavedSheet = false }
                }
            }
        }
    }
}

// MARK: - Composant Toggle moderne
private struct ControlToggleButton: View {
    let icon: String
    let label: String
    @Binding var isOn: Bool
    let tintColor: Color
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3)) {
                isOn.toggle()
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(label)
                    .font(Theme.roundedFont(size: 10, weight: .medium))
            }
            .foregroundColor(isOn ? .white : .primary.opacity(0.7))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isOn ? tintColor : Color(.systemBackground).opacity(0.8))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isOn ? tintColor : Color.clear, lineWidth: 2)
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
                        if SecureStore.load(key: apiKeyStorageKey) == nil {
                            try? SecureStore.save(key: apiKeyStorageKey, data: Data(apiKey.utf8))
                        }
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
    var controlBarPadding: CGFloat { kidMode ? 200 : 150 }

    // Barre d'outils d'édition
    var editorToolbar: some View {
        HStack(spacing: 12) {
            // Bouton Effacer
            Button(action: {
                showClearAlert = true
                haptic(.light)
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.system(size: 20))
                    Text("Effacer")
                        .font(Theme.roundedFont(size: 11, weight: .medium))
                }
                .foregroundColor(.red.opacity(0.8))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.95))
                )
            }
            .disabled(inputText.isEmpty)
            .opacity(inputText.isEmpty ? 0.5 : 1)
            
            // Bouton Sélectionner tout
            Button(action: {
                selectAllText()
                haptic(.light)
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "selection.pin.in.out")
                        .font(.system(size: 20))
                    Text("Tout")
                        .font(Theme.roundedFont(size: 11, weight: .medium))
                }
                .foregroundColor(currentTheme.primaryColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.95))
                )
            }
            .disabled(inputText.isEmpty)
            .opacity(inputText.isEmpty ? 0.5 : 1)
            
            // Bouton Lire (à voix haute)
            Button(action: {
                speechSynthesizer.speak(inputText)
                haptic(.light)
            }) {
                VStack(spacing: 4) {
                    Image(systemName: speechSynthesizer.isSpeaking ? "stop.fill" : "speaker.wave.3.fill")
                        .font(.system(size: 20))
                    Text(speechSynthesizer.isSpeaking ? "Stop" : "Lire")
                        .font(Theme.roundedFont(size: 11, weight: .medium))
                }
                .foregroundColor(speechSynthesizer.isSpeaking ? .orange : currentTheme.primaryColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.95))
                )
            }
            .disabled(inputText.isEmpty)
            .opacity(inputText.isEmpty ? 0.5 : 1)
            
            // Bouton Traduire
            Button(action: {
                showTranslation = true
                haptic(.light)
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "character.book.closed")
                        .font(.system(size: 20))
                    Text("Traduire")
                        .font(Theme.roundedFont(size: 11, weight: .medium))
                }
                .foregroundColor(currentTheme.primaryColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.95))
                )
            }
            .disabled(inputText.isEmpty)
            .opacity(inputText.isEmpty ? 0.5 : 1)
        }
        .padding(.horizontal)
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
    
    func selectAllText() {
        // Copier le texte dans le presse-papiers et notifier l'utilisateur
        UIPasteboard.general.string = inputText
        // Focus sur le champ body pour permettre l'édition
        focusedField = .body
    }

    func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    func handlePlayPause() {
        if isPlaying {
            isPlaying = false
            // Arrêter la lecture vocale si activée
            if voiceEnabled {
                speechSynthesizer.pause()
            }
            return
        }
        if countdownEnabled {
            startCountdown()
        } else {
            startPlayback()
        }
    }
    
    func startPlayback() {
        isPlaying = true
        // Démarrer la lecture vocale si activée
        if voiceEnabled {
            speechSynthesizer.speechRate = Float(speechRate)
            speechSynthesizer.speak(inputText)
        }
    }

    func startCountdown() {
        guard countdownValue == nil else { return }
        countdownValue = 3
        isPlaying = false
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] timer in
            guard var value = countdownValue else { timer.invalidate(); return }
            value -= 1
            if value <= 0 {
                countdownValue = nil
                startPlayback()
                timer.invalidate()
            } else {
                countdownValue = value
            }
        }
    }

    func saveCurrentText() {
        let finalTitle = textTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Texte du \(DateFormatter.shortDate.string(from: Date()))" : textTitle
        let result = store.add(title: finalTitle, content: inputText)
        
        switch result {
        case .success:
            haptic(.rigid)
        case .limitReached:
            showLimitAlert = true
            haptic(.heavy)
        }
    }
    
    // Fonction helper pour afficher le nom de la voix
    func voiceDisplayName(_ voice: AVSpeechSynthesisVoice) -> String {
        var name = voice.name
        // Ajouter une indication pour les voix de haute qualité
        if voice.quality == .enhanced {
            name += " ✨"
        }
        // Ajouter le pays/région (compatible iOS 15+)
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
            Text("\(value)").font(Theme.roundedFont(size: 80, weight: .bold)).foregroundColor(.white)
                .transition(.scale)
        }
        .animation(.easeOut(duration: 0.2), value: value)
    }
    // Options sheet: sliders, countdown, colors and save
    @ViewBuilder
    var optionsSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("Défilement")) {
                    HStack { Text("Vitesse"); Slider(value: $speed, in: 20...200); Text("\(Int(speed)) pt/s").monospacedDigit() }
                    HStack { Text("Taille du texte"); Slider(value: $fontSize, in: 24...56); Text("\(Int(fontSize)) pt").monospacedDigit() }
                    Toggle("Compte à rebours (3…1)", isOn: $countdownEnabled)
                }
                Section(header: Text("Lecture vocale")) {
                    Toggle(isOn: $voiceEnabled) {
                        Label("Activer le lecteur virtuel", systemImage: "speaker.wave.2.fill")
                    }
                    
                    if voiceEnabled {
                        // Sélection de la voix
                        Picker("Voix", selection: $speechSynthesizer.selectedVoiceIdentifier) {
                            ForEach(speechSynthesizer.availableVoices, id: \.identifier) { voice in
                                Text(voiceDisplayName(voice))
                                    .tag(voice.identifier)
                            }
                        }
                        
                        // Vitesse de lecture vocale
                        HStack {
                            Image(systemName: "tortoise.fill")
                                .foregroundColor(.secondary)
                            Slider(value: $speechRate, in: 0.1...0.7)
                            Image(systemName: "hare.fill")
                                .foregroundColor(.secondary)
                        }
                        
                        // Bouton de test de la voix
                        Button(action: {
                            if speechSynthesizer.isSpeaking {
                                speechSynthesizer.stop()
                            } else {
                                speechSynthesizer.speechRate = Float(speechRate)
                                speechSynthesizer.speak("Bonjour, je suis votre lecteur virtuel.")
                            }
                        }) {
                            Label(
                                speechSynthesizer.isSpeaking ? "Arrêter le test" : "Tester la voix",
                                systemImage: speechSynthesizer.isSpeaking ? "stop.fill" : "play.fill"
                            )
                        }
                    }
                }
                
                Section(header: Text("Affichage")) {
                    Toggle("Colorer les syllabes", isOn: $colorSyllables)
                    ColorPicker("Couleur 1", selection: $color1)
                    ColorPicker("Couleur 2", selection: $color2)
                    Toggle("Mode miroir", isOn: $mirror)
                    Toggle("Centrer le texte", isOn: $centerAlign)
                    HStack {
                        Text("Marges latérales")
                        Slider(value: $sidePadding, in: 10...60)
                        Text("\(Int(sidePadding)) pt").monospacedDigit()
                    }
                    HStack {
                        Text("Taille du cadre")
                        Slider(value: $readCardFraction, in: 0.30...0.60)
                        Text("\(Int(readCardFraction * 100)) %").monospacedDigit()
                    }
                }
                Section(header: Text("Mes textes")) {
                    Button { saveCurrentText() } label: { Label("Enregistrer le texte actuel", systemImage: "square.and.arrow.down") }
                    Button { showSavedSheet = true } label: { Label("Ouvrir la bibliothèque", systemImage: "books.vertical") }
                }
            }
            .navigationTitle("Options")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fermer") { showOptions = false } } }
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
// SwiftUI Previews: Éditer, Lire, et Mode enfant
extension ContentView {
    init(previewMode: Mode? = nil, kidMode: Bool? = nil) {
        self.init()
        if let m = previewMode { _mode = State(initialValue: m) }
        if let k = kidMode { _kidMode = State(initialValue: k) }
        _inputText = State(initialValue: SampleText.fr)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView(previewMode: .edit, kidMode: false)
                .previewDisplayName("Éditer")
                .previewDevice("iPhone 15 Pro")
            ContentView(previewMode: .read, kidMode: true)
                .previewDisplayName("Lire – Mode enfant")
                .previewDevice("iPhone 15 Pro")
            ContentView(previewMode: .read, kidMode: false)
                .previewDisplayName("iPad – Lecture")
                .previewDevice("iPad Pro (12.9-inch) (6th generation)")
        }
    }
}
#endif
