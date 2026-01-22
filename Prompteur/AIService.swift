import Foundation

// MARK: - Abstraction
protocol AITextGenerator {
    func generate(criteria: AIGeneratorCriteria, wordCount: Int) async throws -> String
}

enum AIServiceError: Error, LocalizedError {
    case missingAPIKey
    case invalidResponse
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Clé API manquante."
        case .invalidResponse: return "Réponse invalide du service IA."
        case .httpError(let code, let msg): return "Erreur réseau (\(code)) : \(msg)"
        }
    }
}

// MARK: - OpenAI Chat Completions
final class OpenAITextGenerator: AITextGenerator {
    private let apiKey: String
    private let model: String
    private let temperature: Double

    init(apiKey: String, model: String = "gpt-4o-mini", temperature: Double = 0.9) {
        self.apiKey = apiKey
        self.model = model
        self.temperature = temperature
    }

    func generate(criteria: AIGeneratorCriteria, wordCount: Int) async throws -> String {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIServiceError.missingAPIKey
        }
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let prompt = PromptBuilder.buildPrompt(criteria: criteria, wordCount: wordCount)
        let payload = OpenAIChatRequest(
            model: model,
            messages: [
                .init(role: "system", content: PromptBuilder.systemInstruction),
                .init(role: "user", content: prompt)
            ],
            temperature: temperature,
            max_tokens: PromptBuilder.estimateMaxTokens(targetWords: wordCount)
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIServiceError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw AIServiceError.httpError(http.statusCode, msg)
        }
        let decoded = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        guard let choice = decoded.choices.first else { throw AIServiceError.invalidResponse }
        return choice.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - OpenAI DTOs
private struct OpenAIChatRequest: Encodable {
    struct Message: Encodable { let role: String; let content: String }
    let model: String
    let messages: [Message]
    let temperature: Double
    let max_tokens: Int
}

private struct OpenAIChatResponse: Decodable {
    struct Choice: Decodable { let message: Message }
    struct Message: Decodable { let role: String; let content: String }
    let choices: [Choice]
}

// MARK: - Prompt builder
enum PromptBuilder {
    static let systemInstruction = """
Tu es un assistant expert en rédaction de textes pour prompteur/télésouffleur. Tu maîtrises l'art d'écrire des textes fluides, naturels et faciles à lire à voix haute.

RÈGLES ESSENTIELLES :
• Écris des phrases courtes et rythmées, idéales pour la lecture orale
• Utilise des transitions douces entre les idées
• Évite les phrases trop longues ou les structures complexes
• Privilégie un vocabulaire accessible et précis
• Ajoute des respirations naturelles (virgules, points) pour le confort du lecteur
• Intègre les mots-clés de façon naturelle, jamais forcée
• Respecte scrupuleusement le nombre de mots demandé (±10%)
• Pas de listes à puces, pas de titres, pas de formatage - uniquement du texte fluide
• Commence directement par le contenu, sans formule d'introduction générique

POUR LE STORYTELLING :
• Utilise des détails sensoriels et des images vivantes
• Crée une progression narrative même dans un texte court
• Termine sur une note mémorable

POUR LES DISCOURS :
• Commence par une accroche forte
• Varie le rythme pour maintenir l'attention
• Inclus des moments d'emphase et de pause

Écris en français impeccable, naturel et engageant.
"""

    static func buildPrompt(criteria: AIGeneratorCriteria, wordCount: Int) -> String {
        let mots = criteria.contraintes.split { $0 == "," || $0 == ";" || $0 == "\n" }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        let safeCount = max(20, min(1200, wordCount))
        
        let styleGuide: String
        switch criteria.style {
        case .storytelling:
            styleGuide = "Raconte une histoire captivante avec un début, un développement et une conclusion. Utilise des images fortes et des détails concrets."
        case .tutoriel:
            styleGuide = "Explique de façon claire et progressive, comme si tu guidais quelqu'un pas à pas. Reste pratique et concret."
        case .liste:
            styleGuide = "Présente les points clés de façon fluide et connectée, sans utiliser de puces. Chaque idée doit s'enchaîner naturellement."
        case .discours:
            styleGuide = "Écris un discours engageant avec une rhétorique soignée. Varie les longueurs de phrases pour créer du rythme."
        case .annonce:
            styleGuide = "Sois percutant et mémorable. Crée de l'enthousiasme tout en restant crédible. Va droit au but."
        }
        
        let tonGuide: String
        switch criteria.ton {
        case .amical:
            tonGuide = "Utilise un ton chaleureux et accessible, comme si tu parlais à un ami."
        case .professionnel:
            tonGuide = "Adopte un ton sérieux mais pas froid, expert sans être jargonnant."
        case .inspirant:
            tonGuide = "Élève le propos, inspire confiance et motivation. Utilise des formulations positives et encourageantes."
        case .humoristique:
            tonGuide = "Ajoute des touches d'humour subtil, des formulations amusantes, sans tomber dans la caricature."
        case .neutre:
            tonGuide = "Reste factuel et équilibré, sans emphase excessive."
        }
        
        return """
MISSION : Rédige un texte pour prompteur sur le sujet suivant.

📌 SUJET : \(criteria.sujet.isEmpty ? "(libre - choisis un sujet intéressant)" : criteria.sujet)

🎯 OBJECTIF : \(criteria.objectif.rawValue)
🎨 STYLE : \(criteria.style.rawValue) — \(styleGuide)
🎤 TON : \(criteria.ton.rawValue) — \(tonGuide)
👥 PUBLIC : \(criteria.publicCible.rawValue)
🔑 MOTS-CLÉS À INTÉGRER : \(mots.isEmpty ? "(aucun imposé)" : mots)

📏 LONGUEUR : Exactement environ \(safeCount) mots.

⚠️ RAPPELS :
- Texte fluide uniquement, pas de formatage
- Phrases courtes et rythmées
- Commence directement par le contenu
- Termine de façon mémorable
"""
    }

    static func estimateMaxTokens(targetWords: Int) -> Int {
        // Approximation: 1 mot ≈ 1.3 tokens en français
        let approxTokens = Int(Double(targetWords) * 1.3)
        return max(128, min(4096, approxTokens + 256))
    }
}
