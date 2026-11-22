import SwiftUI
import Observation

/// Navigation de l'app : bibliothèque → éditeur, lecteur plein écran, feuilles.
@MainActor
@Observable
final class AppRouter {
    enum Sheet: String, Identifiable {
        case premium, help, create
        var id: String { rawValue }
    }

    var path: [UUID] = []
    var reading: Script?
    var sheet: Sheet?
    /// Message bref affiché en bas de la bibliothèque.
    var toast: String?

    func read(_ script: Script) {
        Haptics.tap()
        reading = script
    }

    func edit(_ id: UUID) {
        if path.last != id { path.append(id) }
    }

    /// Crée un nouveau texte et ouvre l'éditeur, ou propose Premium si la limite est atteinte.
    func newScript(in store: ScriptStore, title: String = "", content: String = "") -> Bool {
        guard let s = store.create(title: title, content: content) else {
            Haptics.warning()
            sheet = .premium
            return false
        }
        edit(s.id)
        return true
    }

    func show(_ message: String) {
        toast = message
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.4))
            if toast == message { toast = nil }
        }
    }
}
