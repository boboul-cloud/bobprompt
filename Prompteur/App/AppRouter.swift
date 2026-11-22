import SwiftUI
import Observation

/// Navigation : accueil → coin des enfants ou studio → éditeur ;
/// lecteur plein écran ; feuilles.
@MainActor
@Observable
final class AppRouter {
    enum Route: Hashable {
        case kids, studio, rewards
        case editor(UUID, ReaderProfile)
    }

    enum Sheet: Identifiable, Equatable {
        case premium, help
        case create(ReaderProfile)
        var id: String {
            switch self {
            case .premium: return "premium"
            case .help: return "help"
            case .create(let p): return "create-\(p.rawValue)"
            }
        }
    }

    struct Reading: Identifiable {
        let script: Script
        let profile: ReaderProfile
        var id: UUID { script.id }
    }

    var path: [Route] = []
    var reading: Reading?
    var sheet: Sheet?
    /// Message bref affiché en bas de l'écran.
    var toast: String?

    func open(_ route: Route) {
        Haptics.tap()
        path.append(route)
    }

    func read(_ script: Script, profile: ReaderProfile = .studio) {
        Haptics.tap()
        reading = Reading(script: script, profile: profile)
    }

    func edit(_ id: UUID, profile: ReaderProfile = .studio) {
        if path.last != .editor(id, profile) { path.append(.editor(id, profile)) }
    }

    /// Crée un nouveau texte et ouvre l'éditeur, ou propose Premium si la limite est atteinte.
    func newScript(in store: ScriptStore, title: String = "", content: String = "",
                   profile: ReaderProfile = .studio) -> Bool {
        guard let s = store.create(title: title, content: content) else {
            Haptics.warning()
            sheet = .premium
            return false
        }
        edit(s.id, profile: profile)
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
