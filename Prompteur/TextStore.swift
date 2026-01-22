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
    private let key = "prompteur.savedTexts.v1"

    init() { load() }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { items = []; return }
        if let decoded = try? JSONDecoder().decode([SavedText].self, from: data) {
            items = decoded.sorted { $0.date > $1.date }
        } else {
            items = []
        }
    }

    func saveAll() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
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
    
    /// Ajoute un texte avec vérification de la limite
    @discardableResult
    func add(title: String, content: String) -> SaveResult {
        // Vérifier la limite pour les utilisateurs gratuits
        if !PurchaseManager.shared.isPremium && items.count >= PurchaseManager.freeTextLimit {
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
