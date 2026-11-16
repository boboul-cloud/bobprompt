import Foundation

struct SavedText: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var content: String
    var date: Date = Date()
}

// Résultat de la tentative de sauvegarde
enum SaveResult {
    case success
    case limitReached
}

@MainActor
final class TextStore: ObservableObject {
    @Published private(set) var items: [SavedText] = []
    private let keychainKey = "prompteur.savedTexts.v2"
    private let userDefaultsKey = "prompteur.savedTexts.v1" // Pour migration

    init() { load() }

    func load() {
        // Essayer d'abord le Keychain (nouvelle méthode persistante)
        if let data = SecureStore.load(key: keychainKey),
           let decoded = try? JSONDecoder().decode([SavedText].self, from: data) {
            items = decoded.sorted { $0.date > $1.date }
            return
        }
        
        // Migration depuis UserDefaults (ancienne méthode)
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([SavedText].self, from: data) {
            items = decoded.sorted { $0.date > $1.date }
            // Migrer vers Keychain
            saveAll()
            // Nettoyer UserDefaults après migration
            UserDefaults.standard.removeObject(forKey: userDefaultsKey)
            return
        }
        
        items = []
    }

    func saveAll() {
        if let data = try? JSONEncoder().encode(items) {
            try? SecureStore.save(key: keychainKey, data: data)
        }
    }

    /// Vérifie si l'utilisateur peut sauvegarder un nouveau texte
    func canSave() -> Bool {
        return PurchaseManager.shared.canSaveMoreTexts(currentCount: items.count)
    }
    
    /// Nombre de textes restants en mode gratuit
    var remainingFreeSlots: Int {
        max(0, PurchaseManager.freeTextLimit - items.count)
    }
    
    /// Nombre de textes restants en mode Premium
    var remainingPremiumSlots: Int {
        max(0, PurchaseManager.premiumTextLimit - items.count)
    }
    
    /// Ajoute un texte avec vérification de la limite
    @discardableResult
    func add(title: String, content: String) -> SaveResult {
        // Vérifier la limite (gratuit ou premium)
        if !PurchaseManager.shared.canSaveMoreTexts(currentCount: items.count) {
            return .limitReached
        }
        
        items.insert(SavedText(title: title, content: content), at: 0)
        saveAll()
        return .success
    }

    func remove(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        saveAll()
    }
}
