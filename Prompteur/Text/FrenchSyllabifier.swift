import Foundation

/// Découpage syllabique « à l'école » du français écrit.
///
/// Règles appliquées (celles enseignées en CP) :
/// - une consonne entre deux voyelles ouvre la syllabe suivante : a-mi, cho-co-lat ;
/// - deux consonnes se séparent : par-tir, pom-me… sauf les groupes inséparables
///   (bl, br, cl, cr, dr, fl, fr, gl, gr, pl, pr, tr, vr) : ta-bleau, li-vre ;
/// - les graphèmes ch, ph, th, gn, qu, gu(+e/i/y) et ill ne se coupent jamais :
///   mon-ta-gne, gui-ta-re, pa-pi-llon ;
/// - les voyelles qui se suivent restent ensemble (oi-seau), sauf hiatus marqué
///   par un accent : po-è-me, thé-â-tre, ré-el.
enum FrenchSyllabifier {

    /// Découpe un mot en syllabes. Les caractères non alphabétiques (apostrophe,
    /// ponctuation collée) restent attachés à la syllabe voisine.
    static func syllables(of word: String) -> [String] {
        // Les mots composés (arc-en-ciel) se découpent partie par partie.
        if word.contains("-"), word.count > 2 {
            var parts: [String] = []
            var current = ""
            for c in word {
                current.append(c)
                if c == "-" { parts.append(current); current = "" }
            }
            if !current.isEmpty { parts.append(current) }
            if parts.count > 1 { return parts.flatMap { syllablesOfSimpleWord($0) } }
        }
        return syllablesOfSimpleWord(word)
    }

    private static func syllablesOfSimpleWord(_ word: String) -> [String] {
        let chars = Array(word)
        guard chars.count > 1 else { return [word] }
        let breaks = breakIndices(in: chars)
        guard !breaks.isEmpty else { return [word] }
        var result: [String] = []
        var start = 0
        for b in breaks {
            result.append(String(chars[start..<b]))
            start = b
        }
        result.append(String(chars[start...]))
        return result
    }

    /// Indices (dans `chars`) où commence une nouvelle syllabe.
    static func breakIndices(in chars: [Character]) -> [Int] {
        let lower = chars.map { c -> Character in
            let l = c.lowercased()
            return l.count == 1 ? Character(l) : c
        }
        let units = makeUnits(lower)
        // Position des noyaux vocaliques (indices dans `units`).
        let nuclei = units.indices.filter { units[$0].kind == .vowel }
        guard nuclei.count > 1 else { return [] }

        var breaks: [Int] = []
        for k in 0..<(nuclei.count - 1) {
            let left = nuclei[k], right = nuclei[k + 1]
            let between = Array(units[(left + 1)..<right]).filter { $0.kind == .consonant }
            let splitUnit: Int
            switch between.count {
            case 0:
                splitUnit = right
            case 1:
                splitUnit = right - 1
            default:
                let lastTwo = between.suffix(2).map(\.text).joined()
                if inseparable.contains(lastTwo) {
                    splitUnit = right - 2
                } else {
                    splitUnit = right - 1
                }
            }
            // Ne jamais couper à l'intérieur d'un mot réduit à des signes.
            let charIndex = units[splitUnit].start
            if charIndex > 0, charIndex < chars.count, !breaks.contains(charIndex) {
                breaks.append(charIndex)
            }
        }
        return breaks.sorted()
    }

    // MARK: - Graphèmes

    private enum Kind { case vowel, consonant, other }

    private struct Unit {
        var text: String
        var kind: Kind
        var start: Int
    }

    private static let vowels: Set<Character> = Set("aeiouyàâäéèêëîïôöùûüÿœæ")
    private static let accentedHiatusSecond: Set<Character> = Set("éèêëïü")
    private static let hiatusFirst: Set<Character> = Set("é")
    private static let digraphs: Set<String> = ["ch", "ph", "th", "gn", "rh", "sh"]
    private static let inseparable: Set<String> = [
        "bl", "br", "cl", "cr", "dr", "fl", "fr", "gl", "gr", "pl", "pr", "tr", "vr",
        "ch", "ph", "th", "gn", "rh", "sh", "qu", "gu"
    ]

    private static func isLetter(_ c: Character) -> Bool { c.isLetter }

    /// Regroupe les lettres en graphèmes consonantiques / noyaux vocaliques.
    private static func makeUnits(_ s: [Character]) -> [Unit] {
        var units: [Unit] = []
        var i = 0
        while i < s.count {
            let c = s[i]
            guard isLetter(c) else {
                // Apostrophe, tiret, ponctuation : rattachés à ce qui suit.
                units.append(Unit(text: String(c), kind: .other, start: i))
                i += 1
                continue
            }
            if vowels.contains(c) {
                // Noyau vocalique : on avale les voyelles suivantes sauf hiatus.
                var j = i + 1
                while j < s.count, vowels.contains(s[j]) {
                    let prev = s[j - 1]
                    if hiatusFirst.contains(prev) || accentedHiatusSecond.contains(s[j]) { break }
                    j += 1
                }
                units.append(Unit(text: String(s[i..<j]), kind: .vowel, start: i))
                i = j
                continue
            }
            // Consonnes : graphèmes à deux lettres.
            if i + 1 < s.count {
                let pair = String([c, s[i + 1]])
                if digraphs.contains(pair) {
                    units.append(Unit(text: pair, kind: .consonant, start: i))
                    i += 2
                    continue
                }
                // qu + voyelle, gu + e/i/y : le u appartient à la consonne.
                if (c == "q" && s[i + 1] == "u") ||
                    (c == "g" && s[i + 1] == "u" && i + 2 < s.count && "eéèêiîy".contains(s[i + 2])) {
                    units.append(Unit(text: pair, kind: .consonant, start: i))
                    i += 2
                    continue
                }
                // « ill » + voyelle : le ll part avec la syllabe suivante (pa-pi-llon).
                if c == "l", s[i + 1] == "l", i > 0, s[i - 1] == "i",
                   i + 2 < s.count, vowels.contains(s[i + 2]) {
                    units.append(Unit(text: "ll", kind: .consonant, start: i))
                    i += 2
                    continue
                }
            }
            units.append(Unit(text: String(c), kind: .consonant, start: i))
            i += 1
        }
        // Les signes en tête (l', d') se rattachent au premier groupe : on les
        // considère comme consonnes pour qu'ils ne forment pas de syllabe seuls.
        return units.map { u in
            var u = u
            if u.kind == .other { u.kind = .consonant }
            return u
        }
    }
}
