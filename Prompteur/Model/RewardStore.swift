import Foundation
import Observation

/// Étoiles, niveaux et badges du coin des enfants.
@MainActor
@Observable
final class RewardStore {
    struct Level: Equatable {
        let threshold: Int
        let emoji: String
        let name: String
    }

    struct Badge: Identifiable, Equatable {
        let id: String
        let emoji: String
        let title: String
        let detail: String
    }

    /// Ce qui vient d'être gagné (affiché par le lecteur).
    struct Gain: Equatable {
        var stars = 0
        var badges: [Badge] = []
        var newLevel: Level?
    }

    static let levels: [Level] = [
        Level(threshold: 0, emoji: "🌱", name: "Graine de lecteur"),
        Level(threshold: 20, emoji: "🌿", name: "Petite pousse"),
        Level(threshold: 60, emoji: "📗", name: "Petit lecteur"),
        Level(threshold: 120, emoji: "🦉", name: "Lecteur malin"),
        Level(threshold: 250, emoji: "🦸", name: "Super lecteur"),
        Level(threshold: 500, emoji: "🏆", name: "Champion des mots"),
        Level(threshold: 1000, emoji: "👑", name: "Maître des histoires")
    ]

    static let badges: [Badge] = [
        Badge(id: "premiers-pas", emoji: "👣", title: "Premiers pas", detail: "Lire 10 phrases"),
        Badge(id: "premier-livre", emoji: "📖", title: "Premier livre", detail: "Lire un texte jusqu'au bout"),
        Badge(id: "bibliotheque", emoji: "📚", title: "Rat de bibliothèque", detail: "Finir 5 textes"),
        Badge(id: "cent-phrases", emoji: "🏅", title: "Cent phrases", detail: "Lire 100 phrases"),
        Badge(id: "trois-jours", emoji: "🔥", title: "Trois jours de suite", detail: "Lire 3 jours d'affilée"),
        Badge(id: "sept-jours", emoji: "🌈", title: "Une semaine entière", detail: "Lire 7 jours d'affilée"),
        Badge(id: "fabuliste", emoji: "🦊", title: "Ami des fables", detail: "Lire les deux fables de La Fontaine"),
        Badge(id: "etoiles-100", emoji: "🌟", title: "Pluie d'étoiles", detail: "Gagner 100 étoiles"),
        Badge(id: "fusee", emoji: "🚀", title: "Fusée", detail: "Finir un texte à l'allure Fusée")
    ]

    private struct State: Codable {
        var stars = 0
        var sentences = 0
        var finishedTexts = 0
        /// Étoiles (1 à 3) obtenues par texte.
        var textStars: [String: Int] = [:]
        var badges: [String: Date] = [:]
        var streak = 0
        var lastDay: String?
    }

    private var state: State {
        didSet { save() }
    }
    @ObservationIgnored private let defaults: UserDefaults
    private static let key = "bobprompt.rewards.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key), let s = try? JSONDecoder().decode(State.self, from: data) {
            state = s
        } else {
            state = State()
        }
    }

    // MARK: Lecture

    var stars: Int { state.stars }
    var sentencesRead: Int { state.sentences }
    var finishedTexts: Int { state.finishedTexts }
    var streak: Int { state.streak }

    var level: Level { Self.levels.last { state.stars >= $0.threshold } ?? Self.levels[0] }
    var nextLevel: Level? { Self.levels.first { $0.threshold > state.stars } }

    /// Avancée vers le niveau suivant (0…1).
    var levelProgress: Double {
        guard let next = nextLevel else { return 1 }
        let span = Double(next.threshold - level.threshold)
        return span > 0 ? Double(state.stars - level.threshold) / span : 1
    }

    func starsFor(_ scriptID: UUID) -> Int { state.textStars[scriptID.uuidString] ?? 0 }
    func unlockedDate(_ badge: Badge) -> Date? { state.badges[badge.id] }
    var unlockedCount: Int { state.badges.count }

    // MARK: Gains

    /// Une phrase vient d'être lue : +1 étoile (et +3 pour la première lecture du jour).
    @discardableResult
    func sentenceRead(today: Date = Date()) -> Gain {
        let before = level
        var gain = Gain(stars: 1)
        var s = state
        s.sentences += 1
        s.stars += 1
        let day = Self.dayKey(today)
        if s.lastDay != day {
            if let last = s.lastDay, Self.dayKey(Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today) == last {
                s.streak += 1
            } else {
                s.streak = 1
            }
            s.lastDay = day
            s.stars += 3
            gain.stars += 3
        }
        state = s
        gain.badges = checkBadges(scriptID: nil, wordsPerMinute: nil)
        if level != before { gain.newLevel = level }
        return gain
    }

    /// Un texte est fini : bonus et 3 étoiles pour ce texte.
    @discardableResult
    func textFinished(_ scriptID: UUID, wordsPerMinute: Double) -> Gain {
        let before = level
        var s = state
        s.finishedTexts += 1
        s.stars += 5
        s.textStars[scriptID.uuidString] = 3
        state = s
        var gain = Gain(stars: 5)
        gain.badges = checkBadges(scriptID: scriptID, wordsPerMinute: wordsPerMinute)
        if level != before { gain.newLevel = level }
        return gain
    }

    /// Lecture interrompue : 1 ou 2 étoiles selon l'avancée, sans écraser un meilleur score.
    func textProgress(_ scriptID: UUID, fraction: Double) {
        let earned = fraction >= 0.8 ? 2 : (fraction >= 0.4 ? 1 : 0)
        guard earned > starsFor(scriptID) else { return }
        state.textStars[scriptID.uuidString] = earned
    }

    func reset() { state = State() }

    // MARK: Badges

    private func checkBadges(scriptID: UUID?, wordsPerMinute: Double?) -> [Badge] {
        var won: [Badge] = []
        func unlock(_ id: String, _ condition: Bool) {
            guard condition, state.badges[id] == nil, let b = Self.badges.first(where: { $0.id == id }) else { return }
            state.badges[id] = Date()
            won.append(b)
        }
        unlock("premiers-pas", state.sentences >= 10)
        unlock("cent-phrases", state.sentences >= 100)
        unlock("premier-livre", state.finishedTexts >= 1)
        unlock("bibliotheque", state.finishedTexts >= 5)
        unlock("trois-jours", state.streak >= 3)
        unlock("sept-jours", state.streak >= 7)
        unlock("etoiles-100", state.stars >= 100)
        let fables = [SampleScripts.corbeau.id, SampleScripts.cigale.id]
        unlock("fabuliste", fables.allSatisfy { starsFor($0) >= 3 })
        if let wpm = wordsPerMinute { unlock("fusee", scriptID != nil && wpm >= 50) }
        return won
    }

    // MARK: Stockage

    private func save() {
        if let data = try? JSONEncoder().encode(state) { defaults.set(data, forKey: Self.key) }
    }

    private static func dayKey(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }
}
