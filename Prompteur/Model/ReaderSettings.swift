import SwiftUI
import UIKit

// MARK: - Styles d'affichage

enum StageFamily: String, CaseIterable, Identifiable {
    case classic, retro, threeD
    var id: String { rawValue }
    var title: String {
        switch self {
        case .classic: return "Classique"
        case .retro: return "Vieille école"
        case .threeD: return "3D"
        }
    }
}

enum StageStyle: String, Codable, CaseIterable, Identifiable {
    case classic, crtGreen, crtAmber, typewriter, drum, cards

    var id: String { rawValue }

    var family: StageFamily {
        switch self {
        case .classic: return .classic
        case .crtGreen, .crtAmber, .typewriter: return .retro
        case .drum, .cards: return .threeD
        }
    }

    var title: String {
        switch self {
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
        case .classic: return "text.alignleft"
        case .crtGreen: return "tv"
        case .crtAmber: return "display"
        case .typewriter: return "keyboard"
        case .drum: return "cylinder.split.1x2"
        case .cards: return "rectangle.on.rectangle.angled"
        }
    }

    /// Le style gère-t-il un défilement continu (vitesse en lignes) ?
    var isContinuous: Bool { self != .cards && self != .typewriter }

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

    static let speedRange: ClosedRange<Double> = 40...260
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

    func syllableColors(onDark: Bool) -> (Color, Color) {
        palette.colors(onDark: onDark, custom: (customColor1, customColor2))
    }
}

/// Réglages persistés (UserDefaults), partagés par tout le lecteur.
@MainActor
@Observable
final class SettingsStore {
    var reader: ReaderSettings {
        didSet { if reader != oldValue { save() } }
    }

    private let defaults: UserDefaults
    private static let key = "bobprompt.readerSettings.v2"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(ReaderSettings.self, from: data) {
            reader = decoded
        } else {
            reader = ReaderSettings()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(reader) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
