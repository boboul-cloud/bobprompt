import Foundation
import UIKit
import CoreFoundation

struct Syllabifier {
    static let defaultLocale = "fr_FR"

    static func hyphenationPoints(in word: String, localeIdentifier: String = defaultLocale) -> [Int] {
        let cfStr = word as CFString
        var index = word.utf16.count
        var points: [Int] = []
        let range = CFRange(location: 0, length: index)
        // Crée un CFLocale via NSLocale (bridge toll-free)
        let nsLocale = NSLocale(localeIdentifier: localeIdentifier)
        let cfLocale = nsLocale as CFLocale

        while index > 0 {
            let loc = CFStringGetHyphenationLocationBeforeIndex(cfStr, index, range, 0, cfLocale, nil)
            if loc == kCFNotFound { break }
            points.append(loc)
            index = loc
        }
        points.sort()
        return points
    }

    static func syllables(for word: String, localeIdentifier: String = defaultLocale) -> [String] {
        if word.count < 4 { return [word] }
        let points = hyphenationPoints(in: word, localeIdentifier: localeIdentifier)
        if points.isEmpty { return [word] }
        var syllables: [String] = []
        var start = word.startIndex
        for p in points {
            if let idx = word.index(word.startIndex, offsetByUTF16: p) {
                let syl = String(word[start..<idx])
                if !syl.isEmpty { syllables.append(syl) }
                start = idx
            }
        }
        let last = String(word[start...])
        if !last.isEmpty { syllables.append(last) }
        return syllables
    }

    static func attributed(text: String,
                           font: UIFont,
                           syllableColors: [UIColor] = [UIColor.systemBlue, UIColor.systemPink],
                           enabled: Bool = true,
                           localeIdentifier: String = defaultLocale,
                           lineSpacing: CGFloat = 8,
                           alignment: NSTextAlignment = .natural) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let baseAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.label
        ]

        let regex = try! NSRegularExpression(pattern: "[\\p{L}]+|[^\\p{L}]+", options: [])
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            guard let match = match else { return }
            let token = ns.substring(with: match.range)
            if token.range(of: "[\\p{L}]", options: .regularExpression) != nil {
                if enabled {
                    let sylls = syllables(for: token, localeIdentifier: localeIdentifier)
                    for (i, s) in sylls.enumerated() {
                        let attrs = baseAttrs.merging([.foregroundColor: syllableColors[i % syllableColors.count]]) { $1 }
                        result.append(NSAttributedString(string: s, attributes: attrs))
                    }
                } else {
                    result.append(NSAttributedString(string: token, attributes: baseAttrs))
                }
            } else {
                result.append(NSAttributedString(string: token, attributes: baseAttrs))
            }
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing
        paragraph.alignment = alignment
        paragraph.hyphenationFactor = 0
        paragraph.baseWritingDirection = .leftToRight
        paragraph.lineBreakMode = .byWordWrapping
        result.addAttributes([.paragraphStyle: paragraph], range: NSRange(location: 0, length: result.length))
        return result
    }
}

private extension String.Index {
    // Helper to create index from UTF16 offset safely
    init?(_utf16Offset: Int, in string: String) {
        guard let idx = string.index(string.startIndex, offsetBy: _utf16Offset, limitedBy: string.endIndex) else { return nil }
        self = idx
    }
}

private extension String {
    func index(_ idx: Index, offsetByUTF16 offset: Int) -> Index? {
        let startUTF16 = self.utf16.distance(from: self.utf16.startIndex, to: idx.samePosition(in: self.utf16) ?? self.utf16.startIndex)
        let newUTF16 = startUTF16 + offset
        guard newUTF16 >= 0 && newUTF16 <= self.utf16.count else { return nil }
        let utf16Index = self.utf16.index(self.utf16.startIndex, offsetBy: newUTF16)
        return utf16Index.samePosition(in: self)
    }
}
