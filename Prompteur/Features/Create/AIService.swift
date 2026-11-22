import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Ce que l'utilisateur demande.
struct AIRequest: Equatable {
    enum Audience: String, CaseIterable, Identifiable {
        case petits = "Enfants 6-8 ans", grands = "Enfants 9-12 ans", ados = "Ados", adultes = "Adultes"
        var id: String { rawValue }
        var guidance: String {
            switch self {
            case .petits: return "pour un enfant de 6 à 8 ans qui apprend à lire : mots simples et courants, phrases très courtes (8 mots maximum), pas de mots difficiles."
            case .grands: return "pour un enfant de 9 à 12 ans : vocabulaire simple mais varié, phrases courtes."
            case .ados: return "pour des adolescents : ton vivant, vocabulaire actuel sans argot excessif."
            case .adultes: return "pour des adultes : registre soigné, naturel à l'oral."
            }
        }
    }

    enum Kind: String, CaseIterable, Identifiable {
        case histoire = "Histoire", expose = "Exposé", video = "Vidéo", discours = "Discours", poeme = "Poème"
        var id: String { rawValue }
        var symbol: String {
            switch self {
            case .histoire: return "book.fill"
            case .expose: return "graduationcap.fill"
            case .video: return "video.fill"
            case .discours: return "mic.fill"
            case .poeme: return "music.quarternote.3"
            }
        }
        var guidance: String {
            switch self {
            case .histoire: return "Raconte une histoire avec un début, un problème et une fin heureuse."
            case .expose: return "Écris un exposé oral clair : introduction, trois idées, conclusion avec une question au public."
            case .video: return "Écris le script d'une vidéo face caméra : accroche immédiate, contenu en étapes, appel à l'action final."
            case .discours: return "Écris un discours chaleureux, avec une ouverture, une anecdote et un final qui invite à lever son verre ou à applaudir."
            case .poeme: return "Écris un poème rimé en vers courts, facile à dire à voix haute."
            }
        }
    }

    enum Tone: String, CaseIterable, Identifiable {
        case joyeux = "Joyeux", calme = "Calme", drole = "Drôle", serieux = "Sérieux", inspirant = "Inspirant"
        var id: String { rawValue }
    }

    enum Length: String, CaseIterable, Identifiable {
        case court = "Court", moyen = "Moyen", long = "Long"
        var id: String { rawValue }
        var words: Int {
            switch self { case .court: return 90; case .moyen: return 180; case .long: return 320 }
        }
    }

    var subject = ""
    var audience: Audience = .grands
    var kind: Kind = .histoire
    var tone: Tone = .joyeux
    var length: Length = .court
    var mustInclude = ""

    static let instructions = """
    Tu écris des textes en français destinés à être lus à voix haute sur un prompteur.
    Règles :
    - phrases courtes, rythmées, faciles à dire ;
    - un paragraphe par idée, séparé par une ligne vide ;
    - aucun titre, aucune liste à puces, aucun emoji, aucune mise en forme Markdown ;
    - commence directement par le texte.
    """

    var prompt: String {
        var p = """
        \(kind.guidance)
        Sujet : \(subject.trimmingCharacters(in: .whitespacesAndNewlines)).
        Public : \(audience.guidance)
        Ton : \(tone.rawValue.lowercased()).
        Longueur : environ \(length.words) mots.
        """
        let extra = mustInclude.trimmingCharacters(in: .whitespacesAndNewlines)
        if !extra.isEmpty { p += "\nMots ou idées à placer naturellement : \(extra)." }
        return p
    }
}

enum AIServiceError: LocalizedError {
    case unavailable(String)
    case http(Int)
    case empty

    var errorDescription: String? {
        switch self {
        case .unavailable(let why): return why
        case .http(let code):
            return code == 401 ? "Clé OpenAI refusée. Vérifie-la dans « Moteur »." : "Le service a répondu par une erreur (\(code))."
        case .empty: return "La réponse était vide. Réessaie."
        }
    }
}

/// Moteurs disponibles, du plus simple au plus avancé.
enum AIEngine: String, CaseIterable, Identifiable {
    case apple, openAI
    var id: String { rawValue }
    var title: String { self == .apple ? "Apple Intelligence" : "OpenAI (clé perso)" }
}

enum AIService {
    static let apiKeyAccount = "OPENAI_API_KEY"

    static var storedKey: String {
        get { SecureStore.load(key: apiKeyAccount).flatMap { String(data: $0, encoding: .utf8) } ?? "" }
        set {
            let v = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if v.isEmpty { SecureStore.delete(key: apiKeyAccount) }
            else { try? SecureStore.save(key: apiKeyAccount, data: Data(v.utf8)) }
        }
    }

    /// Apple Intelligence est-il utilisable ici ? Sinon, pourquoi.
    static var appleStatus: (available: Bool, reason: String) {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return (true, "Sur l'appareil, gratuit et privé.")
            case .unavailable(.appleIntelligenceNotEnabled):
                return (false, "Active Apple Intelligence dans les Réglages pour l'utiliser.")
            case .unavailable(.modelNotReady):
                return (false, "Le modèle d'Apple se télécharge encore. Réessaie plus tard.")
            case .unavailable(.deviceNotEligible):
                return (false, "Cet appareil n'est pas compatible avec Apple Intelligence.")
            default:
                return (false, "Apple Intelligence n'est pas disponible.")
            }
        }
        #endif
        return (false, "Apple Intelligence demande iOS 26 ou plus récent.")
    }

    static func generate(_ request: AIRequest, engine: AIEngine) async throws -> String {
        let raw: String
        switch engine {
        case .apple: raw = try await generateWithApple(request)
        case .openAI: raw = try await generateWithOpenAI(request)
        }
        let cleaned = clean(raw)
        guard !cleaned.isEmpty else { throw AIServiceError.empty }
        return cleaned
    }

    /// Retire la mise en forme que le modèle aurait ajoutée malgré tout.
    static func clean(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> String in
                var l = line.trimmingCharacters(in: .whitespaces)
                while l.hasPrefix("#") || l.hasPrefix("*") || l.hasPrefix("- ") { l = String(l.dropFirst()).trimmingCharacters(in: .whitespaces) }
                return l.replacingOccurrences(of: "**", with: "")
            }
            .joined(separator: "\n")
            .replacingOccurrences(of: "\n\n\n", with: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func generateWithApple(_ request: AIRequest) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard appleStatus.available else { throw AIServiceError.unavailable(appleStatus.reason) }
            let session = LanguageModelSession(instructions: AIRequest.instructions)
            let response = try await session.respond(to: request.prompt)
            return response.content
        }
        #endif
        throw AIServiceError.unavailable(appleStatus.reason)
    }

    private static func generateWithOpenAI(_ request: AIRequest) async throws -> String {
        let key = storedKey
        guard !key.isEmpty else { throw AIServiceError.unavailable("Ajoute ta clé OpenAI dans « Moteur ».") }
        var r = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        r.httpMethod = "POST"
        r.timeoutInterval = 60
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "temperature": 0.8,
            "max_tokens": min(2048, request.length.words * 3 + 200),
            "messages": [
                ["role": "system", "content": AIRequest.instructions],
                ["role": "user", "content": request.prompt]
            ]
        ]
        r.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: r)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else { throw AIServiceError.http(code) }
        struct Reply: Decodable {
            struct Choice: Decodable { struct Message: Decodable { let content: String }; let message: Message }
            let choices: [Choice]
        }
        return try JSONDecoder().decode(Reply.self, from: data).choices.first?.message.content ?? ""
    }
}
