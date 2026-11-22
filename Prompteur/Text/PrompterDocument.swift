import Foundation

/// Un mot du texte, tel qu'il sera affiché et lu.
struct DocWord: Equatable {
    /// Texte affiché (ponctuation isolée rattachée : « Bonjour ! » forme un seul mot).
    let text: String
    /// Plage UTF-16 dans le texte source (pour la synthèse vocale).
    let range: NSRange
    let paragraph: Int
    let sentence: Int
    /// 0 : même paragraphe ; 1 : retour à la ligne ; 2 : ligne vide avant ce mot.
    let breakBefore: Int
    /// Poids de lecture (1 ≈ un mot moyen), pause de ponctuation incluse.
    let weight: Double
    /// Longueurs (en caractères) des syllabes successives de `text`.
    let syllableLengths: [Int]
}

struct DocSentence: Equatable {
    let words: Range<Int>
    let paragraph: Int
}

/// Texte prêt à être affiché par n'importe quel mode du lecteur.
final class PrompterDocument: Identifiable {
    let id = UUID()
    let text: String
    let words: [DocWord]
    let sentences: [DocSentence]
    /// Ligne de temps « naturelle » : un pas par mot + pauses de ponctuation.
    let timeline: Timeline

    init(text: String) {
        self.text = text
        let tokens = Tokenizer.tokens(in: text)
        var words: [DocWord] = []
        var sentences: [DocSentence] = []
        var sentenceStart = 0
        var paragraph = 0

        for (i, tok) in tokens.enumerated() {
            if i > 0, tok.breakBefore > 0 {
                paragraph += 1
                if sentenceStart < i {
                    sentences.append(DocSentence(words: sentenceStart..<i, paragraph: paragraph - 1))
                    sentenceStart = i
                }
            }
            let next = i + 1 < tokens.count ? tokens[i + 1] : nil
            let endsSentence = Tokenizer.endsSentence(tok.text)
            var pause = Tokenizer.punctuationPause(tok.text)
            if let next, next.breakBefore > 0 { pause = max(pause, next.breakBefore > 1 ? 1.2 : 0.7) }
            let letters = tok.text.filter(\.isLetter).count
            let base = min(1.6, max(0.8, 0.7 + 0.06 * Double(letters)))
            words.append(DocWord(
                text: tok.text,
                range: tok.range,
                paragraph: paragraph,
                sentence: sentences.count,
                breakBefore: i == 0 ? 0 : tok.breakBefore,
                weight: base + pause,
                syllableLengths: FrenchSyllabifier.syllables(of: tok.text).map(\.count)
            ))
            if endsSentence, i + 1 < tokens.count, tokens[i + 1].breakBefore == 0 {
                sentences.append(DocSentence(words: sentenceStart..<(i + 1), paragraph: paragraph))
                sentenceStart = i + 1
            }
        }
        if sentenceStart < tokens.count {
            sentences.append(DocSentence(words: sentenceStart..<tokens.count, paragraph: paragraph))
        }
        // Recalage des indices de phrase (les phrases closes par un saut de ligne
        // ont été ajoutées après coup).
        var fixed: [DocWord] = []
        fixed.reserveCapacity(words.count)
        var s = 0
        for (i, w) in words.enumerated() {
            while s < sentences.count, !sentences[s].words.contains(i) { s += 1 }
            fixed.append(DocWord(text: w.text, range: w.range, paragraph: w.paragraph,
                                 sentence: min(s, max(0, sentences.count - 1)),
                                 breakBefore: w.breakBefore, weight: w.weight,
                                 syllableLengths: w.syllableLengths))
        }
        self.words = fixed
        self.sentences = sentences
        self.timeline = Timeline(weights: fixed.map(\.weight))
    }

    var isEmpty: Bool { words.isEmpty }

    /// Mot dont la plage UTF-16 contient (ou suit immédiatement) `utf16Offset`.
    func wordIndex(atUTF16 offset: Int) -> Int? {
        guard !words.isEmpty else { return nil }
        var lo = 0, hi = words.count - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if words[mid].range.location <= offset { lo = mid } else { hi = mid - 1 }
        }
        return lo
    }

    func sentenceIndex(ofWord w: Int) -> Int {
        guard !words.isEmpty else { return 0 }
        return words[min(max(0, w), words.count - 1)].sentence
    }

    /// Texte d'une phrase, tel qu'écrit dans la source.
    func sentenceText(_ s: Int) -> String {
        guard sentences.indices.contains(s) else { return "" }
        return words[sentences[s].words].map(\.text).joined(separator: " ")
    }

    var wordCount: Int { words.count }
}

// MARK: - Ligne de temps

/// Associe une position continue (en « temps de lecture ») à un mot.
struct Timeline: Equatable {
    /// `starts[i]` = début du mot i ; `starts.last` = durée totale.
    let starts: [Double]

    init(weights: [Double]) {
        var s: [Double] = [0]
        s.reserveCapacity(weights.count + 1)
        var acc = 0.0
        for w in weights { acc += max(0.0001, w); s.append(acc) }
        starts = s
    }

    var total: Double { starts.last ?? 0 }
    var wordCount: Int { starts.count - 1 }

    func start(ofWord i: Int) -> Double {
        guard wordCount > 0 else { return 0 }
        return starts[min(max(0, i), wordCount)]
    }

    /// Position exprimée en mots (partie entière = mot courant, décimale = avancée dans ce mot).
    func wordPosition(atBeat beat: Double) -> Double {
        guard wordCount > 0 else { return 0 }
        if beat <= 0 { return 0 }
        if beat >= total { return Double(wordCount) }
        var lo = 0, hi = wordCount - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if starts[mid] <= beat { lo = mid } else { hi = mid - 1 }
        }
        let len = starts[lo + 1] - starts[lo]
        return Double(lo) + (len > 0 ? (beat - starts[lo]) / len : 0)
    }

    func beat(atWordPosition p: Double) -> Double {
        guard wordCount > 0 else { return 0 }
        if p <= 0 { return 0 }
        if p >= Double(wordCount) { return total }
        let i = Int(p)
        let f = p - Double(i)
        return starts[i] + f * (starts[i + 1] - starts[i])
    }

    func wordIndex(atBeat beat: Double) -> Int {
        min(max(0, Int(wordPosition(atBeat: beat))), max(0, wordCount - 1))
    }
}

// MARK: - Découpage en mots

enum Tokenizer {
    struct Token: Equatable {
        var text: String
        var range: NSRange
        var breakBefore: Int
    }

    private static let openers: Set<Character> = ["«", "“", "\"", "(", "[", "—", "–", "-", "‹", "¿", "¡"]
    private static let abbreviations: Set<String> = ["m.", "mm.", "mme.", "mlle.", "dr.", "st.", "ste.", "cf.", "ex.", "p.", "env."]

    static func tokens(in text: String) -> [Token] {
        var raw: [Token] = []
        var newlines = 0
        var i = text.startIndex
        while i < text.endIndex {
            let c = text[i]
            if c.isNewline { newlines += 1; i = text.index(after: i); continue }
            if c.isWhitespace { i = text.index(after: i); continue }
            var j = i
            while j < text.endIndex, !text[j].isWhitespace { j = text.index(after: j) }
            raw.append(Token(text: String(text[i..<j]),
                             range: NSRange(i..<j, in: text),
                             breakBefore: min(newlines, 2)))
            newlines = 0
            i = j
        }

        // Rattache la ponctuation isolée (« Bonjour ! », « — Oui ») à un vrai mot.
        var out: [Token] = []
        var pendingPrefix: Token? = nil
        for tok in raw {
            let hasContent = tok.text.contains { $0.isLetter || $0.isNumber }
            if hasContent {
                if let p = pendingPrefix {
                    let start = p.range.location
                    let end = tok.range.location + tok.range.length
                    out.append(Token(text: p.text + "\u{00A0}" + tok.text,
                                     range: NSRange(location: start, length: end - start),
                                     breakBefore: p.breakBefore))
                    pendingPrefix = nil
                } else {
                    out.append(tok)
                }
                continue
            }
            let isOpener = tok.text.first.map { openers.contains($0) } ?? false
            if !isOpener, tok.breakBefore == 0, pendingPrefix == nil, var last = out.popLast() {
                let end = tok.range.location + tok.range.length
                last.text += "\u{00A0}" + tok.text
                last.range = NSRange(location: last.range.location, length: end - last.range.location)
                out.append(last)
            } else if var p = pendingPrefix {
                let end = tok.range.location + tok.range.length
                p.text += "\u{00A0}" + tok.text
                p.range = NSRange(location: p.range.location, length: end - p.range.location)
                pendingPrefix = p
            } else {
                pendingPrefix = tok
            }
        }
        if let p = pendingPrefix { out.append(p) }
        return out
    }

    static func endsSentence(_ word: String) -> Bool {
        let trimmed = word.trimmingCharacters(in: CharacterSet(charactersIn: "»”\")]’' \u{00A0}"))
        guard let last = trimmed.last else { return false }
        if "!?…".contains(last) { return true }
        if last == "." {
            let lower = trimmed.lowercased()
            if abbreviations.contains(lower) { return false }
            // Initiale (« J. »)
            let letters = trimmed.filter(\.isLetter)
            if letters.count == 1, trimmed.count == 2 { return false }
            return true
        }
        return false
    }

    /// Pause supplémentaire (en mots) après la ponctuation finale du mot.
    static func punctuationPause(_ word: String) -> Double {
        let trimmed = word.trimmingCharacters(in: CharacterSet(charactersIn: "»”\")]’' \u{00A0}"))
        guard let last = trimmed.last else { return 0 }
        switch last {
        case ".", "!", "?": return endsSentence(word) ? 0.9 : 0.2
        case "…": return 1.1
        case ";", ":": return 0.5
        case ",": return 0.35
        case "—", "–": return 0.3
        default: return 0
        }
    }
}
