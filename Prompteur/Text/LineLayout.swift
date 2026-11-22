import UIKit

/// Texte découpé en lignes pour une largeur et une police données.
/// Utilisé par tous les modes « défilement » (classique, cathodique, tambour 3D,
/// machine à écrire).
struct LineLayout {
    struct Line: Identifiable, Equatable {
        let id: Int
        let words: Range<Int>
        let top: CGFloat
        let height: CGFloat
        /// Espace ajouté après la ligne (fin de paragraphe).
        let gapAfter: CGFloat
        /// Largeur réelle du texte de la ligne.
        let width: CGFloat
        var center: CGFloat { top + height / 2 }
        var bottom: CGFloat { top + height + gapAfter }
    }

    let lines: [Line]
    let lineOfWord: [Int]
    let lineHeight: CGFloat
    let maxWidth: CGFloat
    let totalHeight: CGFloat
    /// Ligne de temps où chaque ligne dure en proportion de sa hauteur :
    /// le défilement est parfaitement régulier.
    let timeline: Timeline

    var isEmpty: Bool { lines.isEmpty }

    /// Ordonnée (dans le texte) du point de lecture pour une position donnée.
    func y(atBeat beat: Double) -> CGFloat {
        guard timeline.total > 0 else { return 0 }
        return CGFloat(beat / timeline.total) * totalHeight
    }

    /// Ordonnée à placer sur la ligne de lecture : comme `y(atBeat:)`, avec un
    /// départ et une arrivée en douceur pour que la première et la dernière
    /// ligne soient centrées sur la ligne de lecture.
    func readingY(atBeat beat: Double) -> CGFloat {
        var y = self.y(atBeat: beat)
        guard let first = lines.first, let last = lines.last else { return y }
        let firstBeats = timeline.start(ofWord: first.words.upperBound)
        if firstBeats > 0, beat < firstBeats {
            let t = CGFloat(1 - beat / firstBeats)
            y += first.height / 2 * t * t
        }
        let lastBeats = timeline.total - timeline.start(ofWord: last.words.lowerBound)
        let toEnd = timeline.total - beat
        if lastBeats > 0, toEnd < lastBeats {
            let t = CGFloat(1 - toEnd / lastBeats)
            y -= (last.height / 2 + last.gapAfter) * t * t
        }
        return y
    }

    func beat(atY y: CGFloat) -> Double {
        guard totalHeight > 0 else { return 0 }
        return Double(y / totalHeight) * timeline.total
    }

    /// Lignes qui recoupent l'intervalle [minY, maxY] (coordonnées du texte).
    func lines(in minY: CGFloat, _ maxY: CGFloat) -> ArraySlice<Line> {
        guard !lines.isEmpty else { return [] }
        var lo = 0, hi = lines.count - 1
        while lo < hi {
            let mid = (lo + hi) / 2
            if lines[mid].bottom < minY { lo = mid + 1 } else { hi = mid }
        }
        var end = lo
        while end < lines.count, lines[end].top <= maxY { end += 1 }
        return lines[lo..<end]
    }

    func lineIndex(atY y: CGFloat) -> Int {
        guard !lines.isEmpty else { return 0 }
        var lo = 0, hi = lines.count - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if lines[mid].top <= y { lo = mid } else { hi = mid - 1 }
        }
        return lo
    }

    static func make(document: PrompterDocument,
                     font: UIFont,
                     maxWidth: CGFloat,
                     lineSpacing: CGFloat = 1.32,
                     oneWordPerLine: Bool = false,
                     uppercase: Bool = false,
                     naturalTimeline: Timeline? = nil) -> LineLayout {
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let space = (" " as NSString).size(withAttributes: attrs).width
        let lineHeight = ceil(font.lineHeight * lineSpacing)
        let width = max(40, maxWidth)

        var lines: [Line] = []
        var lineOfWord = [Int](repeating: 0, count: document.words.count)
        var y: CGFloat = 0
        var start = 0
        var current: CGFloat = 0

        func flush(_ end: Int) {
            guard end > start else { return }
            var gap: CGFloat = 0
            if end < document.words.count {
                switch document.words[end].breakBefore {
                case 1: gap = lineHeight * 0.35
                case 2: gap = lineHeight * 0.85
                default: gap = 0
                }
            }
            let line = Line(id: lines.count, words: start..<end, top: y,
                            height: lineHeight, gapAfter: gap, width: current)
            for w in start..<end { lineOfWord[w] = lines.count }
            lines.append(line)
            y += lineHeight + gap
            start = end
            current = 0
        }

        for (i, word) in document.words.enumerated() {
            let text = uppercase ? word.text.uppercased() : word.text
            let w = (text as NSString).size(withAttributes: attrs).width
            if i > start {
                let forcedBreak = word.breakBefore > 0 || oneWordPerLine
                if forcedBreak || current + space + w > width {
                    flush(i)
                }
            }
            current = (i == start) ? w : current + space + w
        }
        flush(document.words.count)

        // Poids de chaque mot proportionnel à la hauteur de sa ligne, puis
        // normalisé pour garder la même durée totale que la lecture naturelle.
        let natural = naturalTimeline ?? document.timeline
        var weights = [Double](repeating: 1, count: document.words.count)
        let totalHeight = y
        if totalHeight > 0, natural.total > 0 {
            let scale = natural.total / Double(totalHeight)
            for line in lines {
                let n = Double(line.words.count)
                let perWord = Double(line.height + line.gapAfter) * scale / n
                for w in line.words { weights[w] = perWord }
            }
        }
        return LineLayout(lines: lines, lineOfWord: lineOfWord, lineHeight: lineHeight,
                          maxWidth: width, totalHeight: totalHeight,
                          timeline: Timeline(weights: weights))
    }
}
