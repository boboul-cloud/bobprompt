import Foundation
import Observation

/// Où sont rangés les textes.
protocol ScriptPersistence {
    /// `nil` : rien d'enregistré. Exception : stockage illisible pour le moment.
    func load() throws -> [Script]?
    func save(_ scripts: [Script])
}

/// Stockage dans le Trousseau (clé de la v1), avec reprise de l'ancien stockage
/// UserDefaults si besoin.
struct KeychainScriptPersistence: ScriptPersistence {
    static let key = "prompteur.savedTexts.v2"
    static let legacyDefaultsKey = "prompteur.savedTexts.v1"

    func load() throws -> [Script]? {
        if let data = try SecureStore.read(key: Self.key) {
            // Données présentes mais illisibles : on lève une erreur plutôt que
            // de repartir d'une liste vide qui les écraserait.
            return try JSONDecoder().decode([Script].self, from: data)
        }
        if let data = UserDefaults.standard.data(forKey: Self.legacyDefaultsKey),
           let decoded = try? JSONDecoder().decode([Script].self, from: data) {
            save(decoded)
            UserDefaults.standard.removeObject(forKey: Self.legacyDefaultsKey)
            return decoded
        }
        return nil
    }

    func save(_ scripts: [Script]) {
        guard let data = try? JSONEncoder().encode(scripts) else { return }
        try? SecureStore.save(key: Self.key, data: data)
    }
}

final class MemoryScriptPersistence: ScriptPersistence {
    var stored: [Script]?
    var failNextLoad = false
    private(set) var saveCount = 0
    init(_ scripts: [Script]? = nil) { stored = scripts }
    func load() throws -> [Script]? {
        if failNextLoad { failNextLoad = false; throw SecureStore.ReadError.status(-25308) }
        return stored
    }
    func save(_ scripts: [Script]) { stored = scripts; saveCount += 1 }
}

@MainActor
@Observable
final class ScriptStore {
    static let freeLimit = 2
    static let premiumLimit = 50

    private(set) var scripts: [Script] = []
    /// Fourni par l'app : l'utilisateur a-t-il Premium ?
    @ObservationIgnored var isPremium: @MainActor () -> Bool = { false }

    @ObservationIgnored private let persistence: ScriptPersistence
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    /// La lecture a échoué : on n'écrit rien tant qu'on n'a pas pu relire,
    /// pour ne jamais écraser les textes existants par une liste vide.
    @ObservationIgnored private(set) var loadFailed = false

    init(persistence: ScriptPersistence = KeychainScriptPersistence()) {
        self.persistence = persistence
        do {
            scripts = (try persistence.load() ?? []).sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            loadFailed = true
        }
    }

    /// Nouvel essai de lecture (au retour au premier plan), fusionné avec ce
    /// qui a été créé entre-temps.
    func retryLoadIfNeeded() {
        guard loadFailed, let stored = try? persistence.load() else { return }
        loadFailed = false
        let ids = Set(stored.map(\.id))
        scripts = (stored + scripts.filter { !ids.contains($0.id) }).sorted { $0.updatedAt > $1.updatedAt }
    }

    var limit: Int { isPremium() ? Self.premiumLimit : Self.freeLimit }
    var canCreate: Bool { scripts.count < limit }
    var remaining: Int { max(0, limit - scripts.count) }

    func script(_ id: UUID) -> Script? { scripts.first { $0.id == id } }

    /// Crée un texte, ou renvoie `nil` si la limite est atteinte.
    @discardableResult
    func create(title: String = "", content: String = "") -> Script? {
        guard canCreate else { return nil }
        let used = Set(scripts.prefix(5).map(\.colorIndex))
        let color = (0..<Palette.cardColors.count).first { !used.contains($0) } ?? Int.random(in: 0..<6)
        let s = Script(title: title, content: content, colorIndex: color)
        scripts.insert(s, at: 0)
        scheduleSave()
        return s
    }

    @discardableResult
    func duplicate(_ source: Script) -> Script? {
        let base = source.displayTitle
        return create(title: source.isSample ? base : "\(base) (copie)", content: source.content)
    }

    /// Met à jour titre / contenu (la date de modification suit).
    func update(_ script: Script) {
        guard let i = scripts.firstIndex(where: { $0.id == script.id }) else { return }
        var s = script
        let old = scripts[i]
        if old.title != s.title || old.content != s.content {
            s.updatedAt = Date()
            if old.content != s.content { s.lastWord = 0 }
        }
        guard s != old else { return }
        scripts[i] = s
        if i != 0, s.updatedAt > old.updatedAt {
            scripts.remove(at: i)
            scripts.insert(s, at: 0)
        }
        scheduleSave()
    }

    func savePosition(_ id: UUID, word: Int) {
        guard let i = scripts.firstIndex(where: { $0.id == id }), scripts[i].lastWord != word else { return }
        scripts[i].lastWord = word
        scheduleSave()
    }

    func delete(_ id: UUID) {
        scripts.removeAll { $0.id == id }
        scheduleSave()
    }

    /// Supprime un texte resté vide (créé puis abandonné).
    func discardIfBlank(_ id: UUID) {
        guard let s = script(id), s.isBlank else { return }
        delete(id)
    }

    func flush() {
        saveTask?.cancel()
        saveTask = nil
        retryLoadIfNeeded()
        guard !loadFailed else { return }
        persistence.save(scripts)
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.flush()
        }
    }
}
