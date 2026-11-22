import SwiftUI
import AVFoundation

/// Tous les réglages du lecteur, au même endroit.
struct ReaderSettingsView: View {
    @Environment(SettingsStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.readerProfile) private var profile
    @State private var voices: [AVSpeechSynthesisVoice] = []
    @State private var tester = SpeechEngine()
    @State private var c1 = Color.blue
    @State private var c2 = Color.red

    var body: some View {
        let s = store.binding(profile)
        NavigationStack {
            Form {
                Section {
                    SyllablePreview(settings: s.wrappedValue)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                Section("Vitesse et taille") {
                    SpeedSlider(value: s.wordsPerMinute)
                    LabeledSlider(title: "Taille du texte", value: s.fontSize,
                                  range: ReaderSettings.fontRange, step: 2,
                                  minSymbol: "textformat.size.smaller", maxSymbol: "textformat.size.larger",
                                  format: { "\(Int($0)) pt" })
                    Picker("Police", selection: s.font) {
                        ForEach(ReadingFont.allCases) { f in Text(f.title).tag(f) }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Mise en page") {
                    Picker("Alignement", selection: s.alignment) {
                        ForEach(TextAlign.allCases) { a in Text(a.title).tag(a) }
                    }
                    .pickerStyle(.segmented)
                    Toggle("Un mot par ligne", isOn: s.oneWordPerLine)
                    Toggle("Éclairer la ligne lue", isOn: s.focusLine)
                    LabeledSlider(title: "Ligne de lecture", value: s.readingLine,
                                  range: 0.22...0.62, step: 0.02,
                                  minSymbol: "arrow.up.to.line", maxSymbol: "arrow.down.to.line",
                                  format: { $0 < 0.32 ? "En haut" : ($0 > 0.5 ? "Au centre" : "Au tiers") })
                    if s.wrappedValue.style.family == .retro {
                        Toggle("Tout en majuscules", isOn: s.retroUppercase)
                    }
                }

                Section {
                    Toggle("Syllabes en couleurs", isOn: s.syllables)
                    if s.wrappedValue.syllables {
                        paletteChooser
                        if s.wrappedValue.palette == .custom {
                            ColorPicker("Couleur 1", selection: $c1, supportsOpacity: false)
                                .onChange(of: c1) { _, v in s.wrappedValue.customColor1 = v.hexString() }
                            ColorPicker("Couleur 2", selection: $c2, supportsOpacity: false)
                                .onChange(of: c2) { _, v in s.wrappedValue.customColor2 = v.hexString() }
                        }
                    }
                    Toggle("Surligner le mot en cours", isOn: s.highlightWord)
                } header: {
                    Text("Aide à la lecture")
                } footer: {
                    Text("Les syllabes suivent le découpage appris à l'école : a-mi, ta-bleau, pa-pi-llon.")
                }

                Section {
                    Toggle("Lire à voix haute", isOn: s.voiceOn)
                    Picker("Voix", selection: s.voiceID) {
                        Text("Automatique").tag("")
                        ForEach(voices, id: \.identifier) { v in
                            Text(SpeechEngine.displayName(v)).tag(v.identifier)
                        }
                    }
                    Button {
                        tester.preview("Bonjour ! Je vais lire ton texte avec toi.",
                                       voiceID: s.wrappedValue.voiceID,
                                       wordsPerMinute: s.wrappedValue.wordsPerMinute)
                    } label: {
                        Label("Écouter cette voix", systemImage: "play.circle.fill")
                    }
                } header: {
                    Text("Voix")
                } footer: {
                    Text("Quand la voix est activée, c'est elle qui fait avancer le texte, mot à mot. Des voix de meilleure qualité s'installent dans Réglages › Accessibilité › Contenu énoncé › Voix.")
                }

                Section {
                    Toggle(isOn: s.mirror) {
                        Label("Miroir", systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                    }
                    Toggle(isOn: s.countdown) {
                        Label("Compte à rebours 3-2-1", systemImage: "timer")
                    }
                    Toggle(isOn: s.sounds) {
                        Label("Sons de la machine à écrire", systemImage: "speaker.wave.1")
                    }
                    Toggle(isOn: s.motionParallax) {
                        Label("3D : suivre l'inclinaison", systemImage: "gyroscope")
                    }
                } header: {
                    Text("Prompteur")
                } footer: {
                    Text("Le miroir inverse le texte pour un prompteur à vitre. Au clavier ou avec une télécommande Bluetooth : espace = lecture/pause, flèches ↑↓ = phrase, ←→ = vitesse.")
                }

                Section {
                    Button("Rétablir les réglages par défaut", role: .destructive) {
                        let style = s.wrappedValue.style
                        s.wrappedValue = profile == .kids ? .kidsDefaults : ReaderSettings()
                        s.wrappedValue.style = style
                    }
                }
            }
            .navigationTitle("Réglages de lecture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }.fontWeight(.bold)
                }
            }
            .onAppear {
                voices = SpeechEngine.frenchVoices
                c1 = Color(hex: s.wrappedValue.customColor1)
                c2 = Color(hex: s.wrappedValue.customColor2)
            }
            .onDisappear { tester.stop() }
        }
        .presentationDetents([.medium, .large])
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        .tint(Palette.onAir)
    }

    private var paletteChooser: some View {
        let s = store.binding(profile)
        return HStack(spacing: 10) {
            ForEach(SyllablePalette.allCases) { p in
                let (a, b) = p.colors(onDark: false, custom: (s.wrappedValue.customColor1, s.wrappedValue.customColor2))
                let selected = s.wrappedValue.palette == p
                Button {
                    s.wrappedValue.palette = p
                    Haptics.tick()
                } label: {
                    VStack(spacing: 6) {
                        HStack(spacing: 3) {
                            Circle().fill(a).frame(width: 16, height: 16)
                            Circle().fill(b).frame(width: 16, height: 16)
                        }
                        Text(p.title).font(Typo.caption(12))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 12)
                        .fill(selected ? Palette.onAir.opacity(0.12) : Color.clear))
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(selected ? Palette.onAir : Palette.hairline, lineWidth: selected ? 2 : 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Aperçu en direct des réglages de texte.
struct SyllablePreview: View {
    let settings: ReaderSettings
    private static let doc = PrompterDocument(text: "Le petit dragon s'amuse avec un papillon.")

    var body: some View {
        let dark = settings.textOnDark
        var paint = LinePaint(base: dark ? Color(hex: "#F4F0E6") : Color(hex: "#1C1A17"))
        if settings.syllables {
            let (a, b) = settings.syllableColors(onDark: dark)
            paint.syllableA = a
            paint.syllableB = b
        }
        if settings.highlightWord { paint.highlightBackground = Palette.onAir.opacity(dark ? 0.5 : 0.25) }
        let font = settings.font.uiFont(size: min(30, settings.fontSize * 0.7))
        return Text(TextStyler.line(Self.doc, words: 0..<Self.doc.words.count, paint: paint,
                                    highlight: settings.highlightWord ? 2 : nil))
            .font(Font(ui: font))
            .multilineTextAlignment(settings.alignment.textAlignment)
            .frame(maxWidth: .infinity, alignment: settings.alignment.alignment)
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(dark ? Color(hex: "#111528") : Color(hex: "#FBF6EA"))
            )
            .scaleEffect(x: settings.mirror ? -1 : 1)
            .animation(.snappy, value: settings)
    }
}

struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let minSymbol: String
    let maxSymbol: String
    let format: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(format(value)).foregroundStyle(.secondary).monospacedDigit()
            }
            HStack(spacing: 10) {
                Image(systemName: minSymbol).foregroundStyle(.secondary)
                Slider(value: $value, in: range, step: step)
                Image(systemName: maxSymbol).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityValue(format(value))
    }
}

/// Curseur de vitesse progressif : la moitié gauche couvre les allures
/// d'apprentissage (10 à 50 mots/min), où chaque cran compte.
struct SpeedSlider: View {
    @Binding var value: Double
    private let lo = ReaderSettings.speedRange.lowerBound
    private let hi = ReaderSettings.speedRange.upperBound

    private var position: Binding<Double> {
        Binding(
            get: { log(max(lo, value) / lo) / log(hi / lo) },
            set: { t in
                let raw = lo * pow(hi / lo, t)
                let step: Double = raw < 30 ? 1 : (raw < 100 ? 5 : 10)
                value = min(hi, max(lo, (raw / step).rounded() * step))
            })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Vitesse")
                Spacer()
                Text("\(Int(value)) mots/min").foregroundStyle(.secondary).monospacedDigit()
            }
            HStack(spacing: 10) {
                Text("🐌")
                Slider(value: position, in: 0...1)
                Text("🚀")
            }
            Text(ReaderSettings.paceLabel(value))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Vitesse")
        .accessibilityValue("\(Int(value)) mots par minute, \(ReaderSettings.paceLabel(value))")
        .accessibilityAdjustableAction { dir in
            value = ReaderSettings.stepped(value, up: dir == .increment)
        }
    }
}
