import Foundation

/// Un texte de la bibliothèque.
///
/// Les clés `title`, `content`, `date` et `id` sont celles de la version 1 :
/// les textes déjà enregistrés se relisent sans conversion.
struct Script: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var title: String
    var content: String
    /// Date de création.
    var date: Date
    var updatedAt: Date
    /// Dernier mot atteint en lecture (reprise là où on s'était arrêté).
    var lastWord: Int
    var colorIndex: Int
    /// Exemple fourni avec l'app (non modifiable, non compté dans la limite).
    var isSample: Bool = false
    var symbol: String? = nil

    init(id: UUID = UUID(), title: String, content: String, date: Date = Date(),
         updatedAt: Date? = nil, lastWord: Int = 0, colorIndex: Int? = nil,
         isSample: Bool = false, symbol: String? = nil) {
        self.id = id
        self.title = title
        self.content = content
        self.date = date
        self.updatedAt = updatedAt ?? date
        self.lastWord = lastWord
        self.colorIndex = colorIndex ?? Int.random(in: 0..<6)
        self.isSample = isSample
        self.symbol = symbol
    }

    enum CodingKeys: String, CodingKey {
        case id, title, content, date, updatedAt, lastWord, colorIndex
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        content = (try? c.decode(String.self, forKey: .content)) ?? ""
        date = (try? c.decode(Date.self, forKey: .date)) ?? Date()
        updatedAt = (try? c.decodeIfPresent(Date.self, forKey: .updatedAt)) ?? date
        lastWord = (try? c.decodeIfPresent(Int.self, forKey: .lastWord)) ?? 0
        colorIndex = (try? c.decodeIfPresent(Int.self, forKey: .colorIndex))
            ?? id.uuidString.utf8.reduce(0) { ($0 + Int($1)) % 6 }
        isSample = false
        symbol = nil
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(content, forKey: .content)
        try c.encode(date, forKey: .date)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encode(lastWord, forKey: .lastWord)
        try c.encode(colorIndex, forKey: .colorIndex)
    }

    var displayTitle: String {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { return t }
        let firstLine = content.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return "Sans titre" }
        return trimmed.count > 40 ? String(trimmed.prefix(40)) + "…" : trimmed
    }

    var excerpt: String {
        let flat = content.split(whereSeparator: \.isNewline).joined(separator: " ")
        return flat.count > 140 ? String(flat.prefix(140)) + "…" : flat
    }

    var wordCount: Int {
        content.split(whereSeparator: { $0.isWhitespace }).filter { $0.contains(where: { $0.isLetter || $0.isNumber }) }.count
    }

    var isBlank: Bool {
        content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
