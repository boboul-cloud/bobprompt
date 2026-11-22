import SwiftUI
import UIKit

// MARK: - Styles d'affichage

enum StageFamily: String, CaseIterable, Identifiable {
    case cartoon, classic, retro, threeD
    var id: String { rawValue }
    var title: String {
        switch self {
        case .cartoon: return "Dessin animé"
        case .classic: return "Classique"
        case .retro: return "Vieille école"
        case .threeD: return "3D"
        }
    }
}

/// Pour qui on lit : le coin des enfants ou le studio (ados, adultes).
/// Chacun garde ses propres réglages.
enum ReaderProfile: String, Codable, Hashable {
    case kids, studio
}

private struct ReaderProfileKey: EnvironmentKey {
    static let defaultValue: ReaderProfile = .studio
}

extension EnvironmentValues {
    var readerProfile: ReaderProfile {
        get { self[ReaderProfileKey.self] }
        set { self[ReaderProfileKey.self] = newValue }
    }
}

enum StageStyle: String, Codable, CaseIterable, Identifiable {
    case sky, classic, crtGreen, crtAmber, typewriter, drum, cards

    var id: String { rawValue }

    var family: StageFamily {
        switch self {
        case .sky: return .cartoon
        case .classic: return .classic
        case .crtGreen, .crtAmber, .typewriter: return .retro
        case .drum, .cards: return .threeD
        }
    }

    var title: String {
        switch self {
        case .sky: return "Pluie de mots"
        case .classic: return "Prompteur"
        case .crtGreen: return "Cathodique"
        case .crtAmber: return "Ambre"
        case .typewriter: return "Machine à écrire"
        case .drum: return "Tambour"
        case .cards: return "Cartes"
        }
    }

    var subtitle: String {
        switch self {
        case .sky: return "Les mots tombent sur un nuage"
        case .classic: return "Défilement net et réglable"
        case .crtGreen: return "Écran vert des années 80"
        case .crtAmber: return "Moniteur ambre, lueur chaude"
        case .typewriter: return "Lettre après lettre, ding !"
        case .drum: return "Un cylindre à faire tourner"
        case .cards: return "Une phrase par carte"
        }
    }

    var symbol: String {
        switch self {
        case .sky: return "cloud.sun.fill"
        case .classic: return "text.alignleft"
        case .crtGreen: return "tv"
        case .crtAmber: return "display"
        case .typewriter: return "keyboard"
        case .drum: return "cylinder.split.1x2"
        case .cards: return "rectangle.on.rectangle.angled"
        }
    }

    /// Le style gère-t-il un défilement continu (vitesse en lignes) ?
    var isContinuous: Bool { self != .cards && self != .typewriter && self != .sky }

    /// Les syllabes colorées ont-elles un sens dans ce style ?
    var supportsSyllables: Bool { true }
}

enum ClassicTheme: String, Codable, CaseIterable, Identifiable {
    case night, paper, contrast
    var id: String { rawValue }
    var title: String {
        switch self {
        case .night: return "Nuit"
        case .paper: return "Papier"
        case .contrast: return "Contraste"
        }
    }
    var isDark: Bool { self != .paper }
}

enum ReadingFont: String, Codable, CaseIterable, Identifiable {
    case rounded, serif, sans, mono
    var id: String { rawValue }
    var title: String {
        switch self {
        case .rounded: return "Arrondie"
        case .serif: return "Livre"
        case .sans: return "Moderne"
        case .mono: return "Machine"
        }
    }

    func uiFont(size: CGFloat, weight: UIFont.Weight = .semibold) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        let design: UIFontDescriptor.SystemDesign
        switch self {
        case .rounded: design = .rounded
        case .serif: design = .serif
        case .sans: design = .default
        case .mono: design = .monospaced
        }
        guard let d = base.fontDescriptor.withDesign(design) else { return base }
        return UIFont(descriptor: d, size: size)
    }
}

enum TextAlign: String, Codable, CaseIterable, Identifiable {
    case leading, center
    var id: String { rawValue }
    var title: String { self == .leading ? "Gauche" : "Centré" }
    var alignment: Alignment { self == .leading ? .leading : .center }
    var textAlignment: TextAlignment { self == .leading ? .leading : .center }
}

enum SyllablePalette: String, Codable, CaseIterable, Identifiable {
    case ecole, foret, soleil, custom
    var id: String { rawValue }
    var title: String {
        switch self {
        case .ecole: return "École"
        case .foret: return "Forêt"
        case .soleil: return "Soleil"
        case .custom: return "Perso"
        }
    }

    func colors(onDark: Bool, custom: (String, String)) -> (Color, Color) {
        switch self {
        case .ecole:
            return onDark ? (Color(hex: "#7FB2FF"), Color(hex: "#FF7A7A"))
                          : (Color(hex: "#1D5BD6"), Color(hex: "#D7263D"))
        case .foret:
            return onDark ? (Color(hex: "#63E2A6"), Color(hex: "#C89BFF"))
                          : (Color(hex: "#12805A"), Color(hex: "#7B3FD3"))
        case .soleil:
            return onDark ? (Color(hex: "#FFB84D"), Color(hex: "#52D9E3"))
                          : (Color(hex: "#C05A00"), Color(hex: "#08848E"))
        case .custom:
            return (Color(hex: custom.0), Color(hex: custom.1))
        }
    }
}

// MARK: - Réglages du lecteur

struct ReaderSettings: Codable, Equatable {
    var style: StageStyle = .classic
    var classicTheme: ClassicTheme = .night
    var wordsPerMinute: Double = 110
    var fontSize: Double = 42
    var font: ReadingFont = .rounded
    var alignment: TextAlign = .center
    var oneWordPerLine = false
    /// Position de la ligne de lecture (fraction de la hauteur, depuis le haut).
    var readingLine: Double = 0.38
    var syllables = true
    var palette: SyllablePalette = .ecole
    var customColor1 = "#2F6BFF"
    var customColor2 = "#FF4D4D"
    var highlightWord = true
    var focusLine = true
    var voiceOn = false
    var voiceID = ""
    var mirror = false
    var countdown = true
    var sounds = true
    var retroUppercase = false
    var motionParallax = true

    static let speedRange: ClosedRange<Double> = 10...260

    /// Réglages de départ du coin des enfants : lent, coloré, dessin animé.
    static var kidsDefaults: ReaderSettings {
        var s = ReaderSettings()
        s.style = .sky
        s.wordsPerMinute = 20
        s.fontSize = 46
        s.countdown = false
        s.readingLine = 0.42
        return s
    }

    /// Pas des boutons − / + : fin aux vitesses lentes, plus large aux rapides.
    static func speedStep(_ wpm: Double, up: Bool) -> Double {
        let probe = up ? wpm : wpm - 0.01
        if probe < 30 { return 2 }
        if probe < 80 { return 5 }
        return 10
    }

    static func stepped(_ wpm: Double, up: Bool) -> Double {
        let step = speedStep(wpm, up: up)
        let next = up ? (wpm / step).rounded(.down) * step + step : (wpm / step).rounded(.up) * step - step
        return min(speedRange.upperBound, max(speedRange.lowerBound, next))
    }

    /// Allures nommées (curseur et boutons des enfants).
    struct Pace: Identifiable {
        let emoji: String
        let name: String
        let wpm: Double
        var id: String { name }
    }

    static let kidsPaces: [Pace] = [
        Pace(emoji: "🐌", name: "Escargot", wpm: 12),
        Pace(emoji: "🐢", name: "Tortue", wpm: 20),
        Pace(emoji: "🐇", name: "Lapin", wpm: 32),
        Pace(emoji: "🚀", name: "Fusée", wpm: 50)
    ]

    static func paceLabel(_ wpm: Double) -> String {
        switch wpm {
        case ..<16: return "🐌 J'apprends à lire"
        case ..<30: return "🐢 Je lis doucement"
        case ..<60: return "🐇 Je lis bien"
        case ..<130: return "🦊 Lecture fluide"
        default: return "🚀 Orateur"
        }
    }
    static let fontRange: ClosedRange<Double> = 22...96

    init() {}

    // Décodage tolérant : une clé absente ou inconnue reprend sa valeur par défaut.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = ReaderSettings()
        func v<T: Decodable>(_ k: CodingKeys, _ def: T) -> T {
            (try? c.decodeIfPresent(T.self, forKey: k)) ?? def
        }
        style = v(.style, d.style)
        classicTheme = v(.classicTheme, d.classicTheme)
        wordsPerMinute = v(.wordsPerMinute, d.wordsPerMinute)
        fontSize = v(.fontSize, d.fontSize)
        font = v(.font, d.font)
        alignment = v(.alignment, d.alignment)
        oneWordPerLine = v(.oneWordPerLine, d.oneWordPerLine)
        readingLine = v(.readingLine, d.readingLine)
        syllables = v(.syllables, d.syllables)
        palette = v(.palette, d.palette)
        customColor1 = v(.customColor1, d.customColor1)
        customColor2 = v(.customColor2, d.customColor2)
        highlightWord = v(.highlightWord, d.highlightWord)
        focusLine = v(.focusLine, d.focusLine)
        voiceOn = v(.voiceOn, d.voiceOn)
        voiceID = v(.voiceID, d.voiceID)
        mirror = v(.mirror, d.mirror)
        countdown = v(.countdown, d.countdown)
        sounds = v(.sounds, d.sounds)
        retroUppercase = v(.retroUppercase, d.retroUppercase)
        motionParallax = v(.motionParallax, d.motionParallax)
        wordsPerMinute = min(max(wordsPerMinute, Self.speedRange.lowerBound), Self.speedRange.upperBound)
        fontSize = min(max(fontSize, Self.fontRange.lowerBound), Self.fontRange.upperBound)
    }

    /// Le texte s'affiche-t-il sur un fond sombre dans le style choisi ?
    var textOnDark: Bool {
        switch style {
        case .classic: return classicTheme.isDark
        case .sky, .typewriter, .cards: return false
        case .crtGreen, .crtAmber, .drum: return true
        }
    }

    func syllableColors(onDark: Bool) -> (Color, Color) {
        palette.colors(onDark: onDark, custom: (customColor1, customColor2))
    }
}

/// Réglages persistés (UserDefaults) : un jeu pour le studio, un pour les enfants.
@MainActor
@Observable
final class SettingsStore {
    /// Réglages du studio (ados, adultes).
    var reader: ReaderSettings {
        didSet { if reader != oldValue { save(reader, Self.studioKey) } }
    }
    /// Réglages du coin des enfants.
    var kids: ReaderSettings {
        didSet { if kids != oldValue { save(kids, Self.kidsKey) } }
    }

    private let defaults: UserDefaults
    private static let studioKey = "bobprompt.readerSettings.v2"
    private static let kidsKey = "bobprompt.kidsSettings.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        reader = Self.load(defaults, Self.studioKey) ?? ReaderSettings()
        kids = Self.load(defaults, Self.kidsKey) ?? .kidsDefaults
    }

    subscript(profile: ReaderProfile) -> ReaderSettings {
        get { profile == .kids ? kids : reader }
        set { if profile == .kids { kids = newValue } else { reader = newValue } }
    }

    func binding(_ profile: ReaderProfile) -> Binding<ReaderSettings> {
        Binding(get: { self[profile] }, set: { self[profile] = $0 })
    }

    private static func load(_ d: UserDefaults, _ key: String) -> ReaderSettings? {
        guard let data = d.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ReaderSettings.self, from: data)
    }

    private func save(_ s: ReaderSettings, _ key: String) {
        if let data = try? JSONEncoder().encode(s) { defaults.set(data, forKey: key) }
    }
}
