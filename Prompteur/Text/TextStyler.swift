import SwiftUI

/// Manière de peindre le texte d'une ligne.
struct LinePaint: Equatable {
    var base: Color
    var syllableA: Color? = nil
    var syllableB: Color? = nil
    var uppercase = false
    var highlightBackground: Color? = nil
    var highlightForeground: Color? = nil
    var highlightUnderline: Color? = nil
    /// Couleur des mots déjà lus (mode cartes / karaoké).
    var readColor: Color? = nil
    var unreadColor: Color? = nil

    var hasSyllables: Bool { syllableA != nil && syllableB != nil }
}

enum TextStyler {
    /// Texte stylé d'une suite de mots.
    /// - Parameters:
    ///   - highlight: mot surligné (karaoké).
    ///   - readBefore: les mots d'indice < readBefore prennent `readColor`, les autres `unreadColor`.
    static func line(_ doc: PrompterDocument,
                     words: Range<Int>,
                     paint: LinePaint,
                     highlight: Int? = nil,
                     readBefore: Int? = nil) -> AttributedString {
        var out = AttributedString()
        for w in words where doc.words.indices.contains(w) {
            if w > words.lowerBound {
                var sp = AttributedString(" ")
                sp.foregroundColor = paint.base
                out.append(sp)
            }
            var piece = word(doc.words[w], paint: paint)
            if let readBefore {
                if w < readBefore, let rc = paint.readColor, !paint.hasSyllables { piece.foregroundColor = rc }
                if w >= readBefore, let uc = paint.unreadColor { piece.foregroundColor = uc }
            }
            if w == highlight {
                if let bg = paint.highlightBackground { piece.backgroundColor = bg }
                if let fg = paint.highlightForeground { piece.foregroundColor = fg }
                if let ul = paint.highlightUnderline { piece.underlineStyle = Text.LineStyle(pattern: .solid, color: ul) }
            }
            out.append(piece)
        }
        return out
    }

    /// Un mot, ses syllabes alternant entre deux couleurs (la ponctuation reste neutre).
    static func word(_ word: DocWord, paint: LinePaint) -> AttributedString {
        let text = word.text
        guard let a = paint.syllableA, let b = paint.syllableB else {
            var s = AttributedString(paint.uppercase ? text.uppercased() : text)
            s.foregroundColor = paint.base
            return s
        }
        var out = AttributedString()
        var idx = text.startIndex
        for (k, len) in word.syllableLengths.enumerated() {
            guard idx < text.endIndex else { break }
            let end = text.index(idx, offsetBy: len, limitedBy: text.endIndex) ?? text.endIndex
            let syllableColor = k % 2 == 0 ? a : b
            // Regroupe les caractères consécutifs de même nature (lettre / signe).
            var runStart = idx
            var runIsLetter = text[idx].isLetter || text[idx].isNumber
            var j = idx
            func flush(_ upTo: String.Index) {
                guard runStart < upTo else { return }
                let chunk = String(text[runStart..<upTo])
                var s = AttributedString(paint.uppercase ? chunk.uppercased() : chunk)
                s.foregroundColor = runIsLetter ? syllableColor : paint.base
                out.append(s)
            }
            while j < end {
                let isLetter = text[j].isLetter || text[j].isNumber
                if isLetter != runIsLetter {
                    flush(j)
                    runStart = j
                    runIsLetter = isLetter
                }
                j = text.index(after: j)
            }
            flush(end)
            idx = end
        }
        if idx < text.endIndex {
            var s = AttributedString(String(text[idx...]))
            s.foregroundColor = paint.base
            out.append(s)
        }
        return out
    }
}

/// Petit cache des lignes déjà stylées (évite de tout recolorier à chaque image).
final class StyledLineCache {
    private var store: [Int: AttributedString] = [:]
    private var signature: Int = 0

    func line(_ doc: PrompterDocument, line: LineLayout.Line, layoutSignature: Int,
              paint: LinePaint, highlight: Int?) -> AttributedString {
        var h = Hasher()
        h.combine(ObjectIdentifier(doc))
        h.combine(layoutSignature)
        h.combine(paint.base.description)
        h.combine(paint.syllableA?.description)
        h.combine(paint.syllableB?.description)
        h.combine(paint.uppercase)
        h.combine(paint.highlightBackground?.description)
        h.combine(paint.highlightForeground?.description)
        h.combine(paint.highlightUnderline?.description)
        let sig = h.finalize()
        if sig != signature { store.removeAll(keepingCapacity: true); signature = sig }

        let hl = highlight.flatMap { line.words.contains($0) ? $0 : nil }
        let key = line.id &* 100_003 &+ (hl ?? -1)
        if let cached = store[key] { return cached }
        let s = TextStyler.line(doc, words: line.words, paint: paint, highlight: hl)
        if store.count > 400 { store.removeAll(keepingCapacity: true) }
        store[key] = s
        return s
    }
}
