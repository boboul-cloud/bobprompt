import SwiftUI
import UIKit

/// Vieille école : le texte se tape lettre après lettre sur une feuille.
struct TypewriterStage: View {
    let ctx: StageContext

    @State private var holder = LayoutHolder()
    @State private var typing = TypingCache()
    @State private var paperLine = 0
    @State private var lastKey = -1
    @State private var bellLine = -1

    private let ink = Color(hex: "#1E1A16")
    private let red = Color(hex: "#B3261E")
    private let paperColor = Color(hex: "#F7F0DE")

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let s = ctx.settings
            let uiFont = StageFonts.typewriter(size: s.fontSize * 0.8)
            let paperW = min(size.width - 26, 760)
            let margin = max(20, paperW * 0.075)
            let (layout, key) = ContinuousLayout.make(ctx, holder: holder, width: paperW - margin * 2,
                                                      uiFont: uiFont, spacing: 1.5,
                                                      uppercase: s.retroUppercase)
            let timeline = typing.timeline(for: layout, signature: holder.signature, document: ctx.document)
            let state = TypingState(layout: layout, document: ctx.document, charStarts: typing.charStarts,
                                    position: ctx.engine.wordPosition, uppercase: s.retroUppercase)
            let lh = layout.lineHeight
            let typingY = size.height * 0.6
            let paperX = (size.width - paperW) / 2
            let anchorTop = layout.lines.isEmpty ? 0 : layout.lines[min(paperLine, layout.lines.count - 1)].top
            // Ordonnée écran du haut d'une ligne du texte.
            let screenTop: (CGFloat) -> CGFloat = { top in typingY - lh * 0.86 + (top - anchorTop) }

            ZStack(alignment: .topLeading) {
                desk(size: size)

                paper(width: paperW, top: screenTop(0) - lh * 1.4, bottom: typingY + lh * 1.2)
                    .offset(x: paperX)

                typedText(layout: layout, state: state, font: Font(ui: uiFont), screenTop: screenTop,
                          x: paperX + margin, lh: lh, size: size)

                typeGuide(x: paperX + margin + state.caretX(font: uiFont, layout: layout), y: typingY, lh: lh)

                machine(size: size, typingY: typingY, lh: lh)
            }
            .clipped()
            .contentShape(Rectangle())
            .modifier(ScrubGesture(engine: ctx.engine,
                                   beatsPerPoint: timeline.total / Double(max(1, layout.totalHeight))))
            .onChange(of: key, initial: true) { ctx.engine.setTimeline(timeline) }
            .onChange(of: state.line, initial: true) { old, new in
                withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) { paperLine = new }
                if old != new, new > old { sound { TypewriterSound.shared.carriageReturn() } }
            }
            .onChange(of: state.keyIndex) { old, new in
                guard new > old else { return }
                sound { TypewriterSound.shared.key() }
                if state.lineFraction > 0.82, state.lineLength > 14, bellLine != state.line {
                    bellLine = state.line
                    sound { TypewriterSound.shared.bell() }
                }
            }
        }
    }

    private func sound(_ play: () -> Void) {
        guard ctx.settings.sounds, ctx.engine.isPlaying else { return }
        play()
    }

    // MARK: Texte tapé

    @ViewBuilder
    private func typedText(layout: LineLayout, state: TypingState, font: Font,
                           screenTop: @escaping (CGFloat) -> CGFloat, x: CGFloat, lh: CGFloat,
                           size: CGSize) -> some View {
        let firstVisible = layout.lineIndex(atY: layout.lines.isEmpty ? 0 :
                                            layout.lines[min(paperLine, layout.lines.count - 1)].top - size.height)
        // `paperLine` peut encore désigner l'ancienne ligne après un retour en
        // arrière : on borne pour que l'intervalle reste valide.
        let hi = min(layout.lines.count, state.line + 1)
        let range = layout.lines.isEmpty ? 0..<0 : min(max(0, firstVisible), hi)..<hi
        ForEach(Array(range), id: \.self) { i in
            let line = layout.lines[i]
            let text = i < state.line ? typing.inked(line, document: ctx.document, paint: paint, signature: holder.signature)
                : TypingCache.inkedText(ctx.document, words: line.words, upTo: state.typedInLine, paint: paint)
            Text(text)
                .font(font)
                .lineLimit(1)
                .fixedSize()
                .scaleEffect(min(1, layout.maxWidth / max(1, line.width)), anchor: .leading)
                .frame(height: lh, alignment: .leading)
                .offset(x: x, y: screenTop(line.top))
        }
    }

    private var paint: LinePaint {
        var p = LinePaint(base: ink, uppercase: ctx.settings.retroUppercase)
        if ctx.settings.syllables {
            p.syllableA = ink
            p.syllableB = red
        }
        return p
    }

    // MARK: Décor

    private func desk(size: CGSize) -> some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#3A2E25"), Color(hex: "#241C16")], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Color(hex: "#FFE2B0").opacity(0.18), .clear],
                           center: UnitPoint(x: 0.5, y: 0.35), startRadius: 0, endRadius: size.height * 0.7)
        }
        .frame(width: size.width, height: size.height)
        .ignoresSafeArea()
    }

    private func paper(width: CGFloat, top: CGFloat, bottom: CGFloat) -> some View {
        Rectangle()
            .fill(paperColor)
            .overlay { PaperGrain().equatable() }
            .overlay(alignment: .top) {
                LinearGradient(colors: [.black.opacity(0.06), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 30)
            }
            .frame(width: width, height: max(0, bottom - top))
            .shadow(color: .black.opacity(0.45), radius: 14, y: 6)
            .offset(y: top)
    }

    private func typeGuide(x: CGFloat, y: CGFloat, lh: CGFloat) -> some View {
        // Le guide de frappe : petit repère métallique sous la lettre en cours.
        Path { p in
            p.move(to: CGPoint(x: -7, y: 0))
            p.addLine(to: CGPoint(x: 7, y: 0))
            p.addLine(to: CGPoint(x: 0, y: -9))
            p.closeSubpath()
        }
        .fill(LinearGradient(colors: [Color(hex: "#E9E4DA"), Color(hex: "#8C877D")], startPoint: .top, endPoint: .bottom))
        .frame(width: 14, height: 9)
        .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
        .offset(x: x - 7, y: y + lh * 0.2)
        .opacity(ctx.engine.isPlaying ? 1 : 0.75)
    }

    private func machine(size: CGSize, typingY: CGFloat, lh: CGFloat) -> some View {
        let platenH = max(34, lh * 0.95)
        let platenY = typingY + lh * 0.28
        return ZStack(alignment: .topLeading) {
            // Barre presse-papier chromée et ses deux galets.
            ZStack {
                Capsule().fill(LinearGradient(colors: [Color(hex: "#F4F2EE"), Color(hex: "#9C978E"), Color(hex: "#E3E0DA")],
                                              startPoint: .top, endPoint: .bottom))
                    .frame(height: 5)
                HStack {
                    Spacer().frame(width: size.width * 0.28)
                    roller
                    Spacer()
                    roller
                    Spacer().frame(width: size.width * 0.28)
                }
            }
            .frame(width: size.width)
            .offset(y: platenY - 3)
            .zIndex(2)

            // Rouleau (cylindre noir) avec molettes.
            RoundedRectangle(cornerRadius: platenH / 2)
                .fill(LinearGradient(stops: [
                    .init(color: Color(hex: "#0B0B0C"), location: 0),
                    .init(color: Color(hex: "#4A4A4E"), location: 0.32),
                    .init(color: Color(hex: "#1A1A1C"), location: 0.6),
                    .init(color: Color(hex: "#050505"), location: 1)
                ], startPoint: .top, endPoint: .bottom))
                .frame(width: size.width + 40, height: platenH)
                .offset(x: -20, y: platenY)

            knob(height: platenH * 1.35).offset(x: -platenH * 0.2, y: platenY - platenH * 0.17)
            knob(height: platenH * 1.35).offset(x: size.width - platenH * 0.5, y: platenY - platenH * 0.17)

            // Corps de la machine.
            UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26)
                .fill(LinearGradient(colors: [Color(hex: "#3E4A43"), Color(hex: "#26302B")], startPoint: .top, endPoint: .bottom))
                .overlay(alignment: .top) {
                    Rectangle().fill(.white.opacity(0.18)).frame(height: 1).padding(.horizontal, 20)
                }
                .overlay(alignment: .center) {
                    Text("bobprompt")
                        .font(.system(size: 17, weight: .heavy, design: .serif).italic())
                        .foregroundStyle(LinearGradient(colors: [Color(hex: "#F6F1E6"), Color(hex: "#A7A196")],
                                                        startPoint: .top, endPoint: .bottom))
                        .shadow(color: .black.opacity(0.5), radius: 1, y: 1)
                        .offset(y: -6)
                }
                .frame(width: size.width, height: max(60, size.height - platenY - platenH * 0.55))
                .offset(y: platenY + platenH * 0.62)
        }
        .allowsHitTesting(false)
    }

    private var roller: some View {
        Capsule().fill(Color(hex: "#151515")).frame(width: 26, height: 12)
    }

    private func knob(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(LinearGradient(colors: [Color(hex: "#2A2A2C"), Color(hex: "#6B6B70"), Color(hex: "#1B1B1D")],
                                 startPoint: .top, endPoint: .bottom))
            .overlay(
                VStack(spacing: 3) { ForEach(0..<6, id: \.self) { _ in Rectangle().fill(.black.opacity(0.5)).frame(height: 1) } }
                    .padding(.vertical, 6)
            )
            .frame(width: height * 0.38, height: height)
    }
}

// MARK: - État de frappe

/// Où en est la frappe pour une position donnée.
struct TypingState {
    let line: Int
    /// Nombre de caractères visibles sur la ligne en cours.
    let typedInLine: Int
    let lineLength: Int
    /// Compteur strictement croissant à chaque lettre frappée.
    let keyIndex: Int
    private let lineText: String

    init(layout: LineLayout, document: PrompterDocument, charStarts: [Int], position: Double, uppercase: Bool) {
        guard !layout.lines.isEmpty, !document.words.isEmpty else {
            line = 0; typedInLine = 0; lineLength = 0; keyIndex = 0; lineText = ""; return
        }
        let w = min(Int(position), document.words.count - 1)
        let frac = position >= Double(document.words.count) ? 1 : position - Double(w)
        let l = layout.lineOfWord[w]
        let lineWords = layout.lines[l].words
        var count = 0
        for i in lineWords.lowerBound..<w { count += document.words[i].text.count + 1 }
        let wordLen = document.words[w].text.count
        let typedWord = min(wordLen, Int(frac * Double(wordLen + 1)))
        count += typedWord
        line = l
        typedInLine = count
        let text = document.words[lineWords].map(\.text).joined(separator: " ")
        lineText = uppercase ? text.uppercased() : text
        lineLength = text.count
        keyIndex = (charStarts.indices.contains(w) ? charStarts[w] : 0) + typedWord
    }

    var lineFraction: Double { lineLength > 0 ? Double(typedInLine) / Double(lineLength) : 0 }

    func caretX(font: UIFont, layout: LineLayout) -> CGFloat {
        let prefix = String(lineText.prefix(typedInLine))
        let w = (prefix as NSString).size(withAttributes: [.font: font]).width
        let scale = layout.lines.indices.contains(line) ? min(1, layout.maxWidth / max(1, layout.lines[line].width)) : 1
        return w * scale + font.pointSize * 0.28
    }
}

/// Lignes déjà tapées (encrage irrégulier) et ligne de temps lettre à lettre.
final class TypingCache {
    private var signature = -1
    private var cachedTimeline = Timeline(weights: [])
    /// Nombre de caractères frappés avant chaque mot (précalculé).
    private(set) var charStarts: [Int] = []
    private var lines: [Int: AttributedString] = [:]
    private var paintKey = ""

    /// Chaque mot dure en proportion de ses lettres, avec une pause de retour chariot.
    func timeline(for layout: LineLayout, signature: Int, document: PrompterDocument) -> Timeline {
        if signature == self.signature { return cachedTimeline }
        self.signature = signature
        lines.removeAll()
        var acc = 0
        charStarts = document.words.map { w in defer { acc += w.text.count + 1 }; return acc }
        var weights = document.words.map { Double($0.text.count + 1) }
        for line in layout.lines { if let last = line.words.last { weights[last] += 5 } }
        let total = weights.reduce(0, +)
        let scale = total > 0 ? document.timeline.total / total : 1
        cachedTimeline = Timeline(weights: weights.map { $0 * scale })
        return cachedTimeline
    }

    func inked(_ line: LineLayout.Line, document: PrompterDocument, paint: LinePaint, signature: Int) -> AttributedString {
        let key = "\(paint.hasSyllables)\(paint.uppercase)"
        if key != paintKey { lines.removeAll(); paintKey = key }
        if let s = lines[line.id] { return s }
        let s = Self.inkedText(document, words: line.words, upTo: nil, paint: paint)
        lines[line.id] = s
        return s
    }

    /// Texte à l'encre de ruban : chaque lettre un peu plus ou moins appuyée.
    static func inkedText(_ doc: PrompterDocument, words: Range<Int>, upTo limit: Int?, paint: LinePaint) -> AttributedString {
        var out = AttributedString()
        var count = 0
        for w in words {
            if let limit, count >= limit { break }
            if w > words.lowerBound {
                out.append(AttributedString(" "))
                count += 1
            }
            let word = TextStyler.word(doc.words[w], paint: paint)
            for run in word.runs {
                let chunk = String(word[run.range].characters)
                let color = run.foregroundColor ?? paint.base
                for (k, ch) in chunk.enumerated() {
                    if let limit, count >= limit { break }
                    var c = AttributedString(String(ch))
                    let h = (w &* 131 &+ count &* 31 &+ k) & 0xFFFF
                    let pressure = 0.78 + Double(h % 23) / 100
                    c.foregroundColor = color.opacity(pressure)
                    c.baselineOffset = CGFloat((h / 23) % 5) * 0.35 - 0.7
                    out.append(c)
                    count += 1
                }
            }
        }
        return out
    }
}

/// Grain et fibres du papier (dessinés une fois, reproductibles).
struct PaperGrain: View, Equatable {
    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRandom(seed: 7)
            let specks = Int(size.width * size.height / 260)
            for _ in 0..<min(specks, 6000) {
                let x = rng.next() * size.width, y = rng.next() * size.height
                let r = 0.4 + rng.next() * 0.9
                let dark = rng.next() > 0.5
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                         with: .color(dark ? .black.opacity(0.07) : .white.opacity(0.35)))
            }
            for _ in 0..<min(specks / 40, 160) {
                let x = rng.next() * size.width, y = rng.next() * size.height
                var p = Path()
                p.move(to: CGPoint(x: x, y: y))
                p.addLine(to: CGPoint(x: x + 6 + rng.next() * 14, y: y + (rng.next() - 0.5) * 3))
                ctx.stroke(p, with: .color(.brown.opacity(0.06)), lineWidth: 0.6)
            }
        }
        .allowsHitTesting(false)
    }
}
