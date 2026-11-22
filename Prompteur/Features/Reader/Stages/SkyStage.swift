import SwiftUI
import UIKit

/// Dessin animé : les mots tombent du ciel et se posent sur un nuage.
///
/// Une phrase par nuage. Chaque mot tombe au moment où il doit être lu,
/// rebondit en se posant, puis reste surligné le temps de le lire.
/// Toucher un mot posé le fait entendre. Balayer change de phrase.
struct SkyStage: View {
    let ctx: StageContext

    @State private var cache = SkyLayoutCache()
    @State private var speaker = SpeechEngine()
    @State private var wiggle: Int?
    @State private var cheering = false

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let doc = ctx.document
            ZStack {
                SkyBackground()
                if !doc.isEmpty {
                    let wp = ctx.engine.wordPosition
                    let w = min(max(0, Int(wp)), doc.words.count - 1)
                    let frac = wp >= Double(doc.words.count) ? 1 : wp - Double(w)
                    let s = doc.words[w].sentence
                    let rain = CGPoint(x: size.width * 0.6, y: ctx.safeArea.top + 100)

                    rainCloud(width: min(size.width * 0.56, 400), playing: ctx.engine.isPlaying)
                        .position(rain)

                    sentenceCloud(sentence: s, current: w, frac: frac, size: size, rain: rain)
                        .id(s)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .offset(x: -size.width, y: -size.height * 0.25).combined(with: .opacity)))
                }
                mascot(size: size)
            }
            .animation(.spring(response: 0.9, dampingFraction: 0.82), value: currentSentence)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 24).onEnded { v in
                    guard abs(v.translation.width) > abs(v.translation.height) else { return }
                    ctx.engine.jumpSentence(v.translation.width < 0 ? 1 : -1)
                    Haptics.tap()
                }
            )
            .onChange(of: doc.id, initial: true) { ctx.engine.setTimeline(doc.timeline) }
            .onChange(of: currentSentence) { old, new in
                guard new > old, ctx.engine.isPlaying else { return }
                cheering = true
                Task {
                    try? await Task.sleep(for: .seconds(1.6))
                    cheering = false
                }
            }
        }
        .onDisappear { speaker.stop() }
    }

    private var currentSentence: Int {
        ctx.document.isEmpty ? 0 : ctx.document.sentenceIndex(ofWord: ctx.engine.coarseWord)
    }

    // MARK: Nuage de la phrase

    @ViewBuilder
    private func sentenceCloud(sentence s: Int, current w: Int, frac: Double, size: CGSize, rain: CGPoint) -> some View {
        let settings = ctx.settings
        let crown: CGFloat = 0.26
        // Grand écran (iPad) : mots et nuage plus grands.
        let big: CGFloat = size.width > 700 ? 1.5 : 1
        let cloudW = min(size.width * 0.94, 760 * big)
        let pad: CGFloat = 26
        // Espace libre entre le nuage de pluie et la barre de commandes.
        let zoneTop = rain.y + 62
        let zoneBottom = size.height - ctx.safeArea.bottom - 236
        let maxCloudH = max(160, zoneBottom - zoneTop)
        let layout = cache.layout(document: ctx.document, sentence: s, maxWidth: cloudW - pad * 2,
                                  maxHeight: maxCloudH * (1 - crown) - pad * 1.6,
                                  fontSize: settings.fontSize * 1.02 * Double(big), font: settings.font)
        let cloudH = (layout.size.height + pad * 1.6) / (1 - crown)
        let centerY = (zoneTop + zoneBottom) / 2
        let textTop = cloudH * crown + pad * 0.8
        let cloudTop = centerY - cloudH / 2
        let cloudLeft = (size.width - cloudW) / 2
        let startY = rain.y + 30 - cloudTop - textTop
        let startX = rain.x - cloudLeft - pad
        let waiting = ctx.engine.phase == .idle && w == ctx.document.sentences[s].words.lowerBound && frac < 0.38
        let paint = wordPaint
        let font = Font(ui: layout.font)

        ZStack(alignment: .topLeading) {
            FluffyCloud(seed: UInt64(s % 7 + 1), crown: crown)
                .frame(width: cloudW, height: cloudH)

            if waiting {
                Text("Appuie sur ▶︎ :\nles mots vont tomber du ciel !")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(KidsPalette.ink.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .frame(width: cloudW, height: cloudH - cloudH * crown)
                    .offset(y: cloudH * crown)
            }

            ForEach(layout.words.filter { $0.word <= w }, id: \.word) { placed in
                let isCurrent = placed.word == w
                let fall = isCurrent ? min(1, frac / 0.38) : 1
                let landed = fall >= 1
                let wobble = isCurrent ? CGFloat(sin(fall * .pi * 3) * 10 * (1 - fall)) : 0
                let y = isCurrent ? startY + (placed.center.y - startY) * CGFloat(Self.bounce(fall)) : placed.center.y
                let glide = 1 - pow(1 - fall, 3)
                let x = isCurrent ? startX + (placed.center.x - startX) * CGFloat(glide) : placed.center.x
                ZStack {
                    if isCurrent && !landed { trail(fall: fall) }
                    if isCurrent && landed && frac < 0.6 { landingBurst(k: (frac - 0.38) / 0.22) }
                    Text(TextStyler.word(ctx.document.words[placed.word], paint: paint))
                        .font(font)
                        .fixedSize()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(
                            Capsule().fill(KidsPalette.sun.opacity(isCurrent && landed && settings.highlightWord ? 0.6 : 0))
                        )
                }
                .scaleEffect(isCurrent ? (landed ? 1 + 0.05 * CGFloat(sin(frac * .pi * 6)) : 1.18 - 0.18 * CGFloat(fall)) : 1)
                .rotationEffect(.degrees(isCurrent ? (1 - fall) * (placed.word % 2 == 0 ? -18 : 18) : 0))
                .rotationEffect(.degrees(wiggle == placed.word ? 8 : 0))
                .position(x: pad + x + wobble, y: textTop + y)
                .onTapGesture { say(placed.word) }
                .accessibilityLabel(ctx.document.words[placed.word].text)
                .accessibilityAddTraits(.isButton)
            }
        }
        .frame(width: cloudW, height: cloudH)
        .position(x: size.width / 2, y: centerY)
    }

    private var wordPaint: LinePaint {
        let s = ctx.settings
        var p = LinePaint(base: KidsPalette.ink)
        if s.syllables {
            let (a, b) = s.syllableColors(onDark: false)
            p.syllableA = a
            p.syllableB = b
        }
        return p
    }

    /// Rebond à l'arrivée (comme une balle qui tombe).
    static func bounce(_ t: Double) -> Double {
        let n = 7.5625, d = 2.75
        var x = t
        if x < 1 / d { return n * x * x }
        if x < 2 / d { x -= 1.5 / d; return n * x * x + 0.75 }
        if x < 2.5 / d { x -= 2.25 / d; return n * x * x + 0.9375 }
        x -= 2.625 / d
        return n * x * x + 0.984375
    }

    private func trail(fall: Double) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { k in
                Image(systemName: "sparkle")
                    .font(.system(size: CGFloat(12 - k * 2), weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: KidsPalette.sun, radius: 4)
                    .offset(x: CGFloat(k % 2 == 0 ? -10 : 12), y: -CGFloat(26 + k * 20))
                    .opacity((1 - fall) * (1 - Double(k) * 0.28))
            }
        }
    }

    private func landingBurst(k: Double) -> some View {
        let kk = min(1, max(0, k))
        return ZStack {
            ForEach(0..<7, id: \.self) { i in
                let a = Double(i) / 7 * 2 * .pi - .pi / 2
                Image(systemName: "star.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(i % 2 == 0 ? KidsPalette.sun : KidsPalette.candy)
                    .offset(x: CGFloat(cos(a) * (18 + 46 * kk)), y: CGFloat(sin(a) * (12 + 30 * kk)))
                    .opacity(1 - kk)
            }
        }
    }

    // MARK: Décor

    private func rainCloud(width: CGFloat, playing: Bool) -> some View {
        ZStack {
            if playing {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    Canvas { c, s in
                        var rng = SeededRandom(seed: 5)
                        for _ in 0..<14 {
                            let x = rng.next() * s.width * 0.8 + s.width * 0.1
                            let speed = 60 + rng.next() * 50
                            let y = CGFloat((t * Double(speed) + Double(rng.next()) * 200).truncatingRemainder(dividingBy: 90))
                            c.fill(Path(roundedRect: CGRect(x: x, y: s.height * 0.6 + y, width: 3, height: 9), cornerRadius: 1.5),
                                   with: .color(Color(hex: "#7CC4FF").opacity(1 - Double(y) / 90)))
                        }
                    }
                }
                .frame(width: width, height: width * 0.5 + 90)
                .offset(y: 45)
            }
            FluffyCloud(tint: Color(hex: "#F4F8FF"), seed: 11)
                .frame(width: width, height: width * 0.36)
        }
        .allowsHitTesting(false)
    }

    /// Bob regarde la pluie de mots depuis le ciel.
    private func mascot(size: CGSize) -> some View {
        let idle = ctx.engine.phase == .idle && ctx.engine.beat == 0
        return Mascot(mood: cheering ? .cheer : (idle ? .curious : .happy), size: 84)
            .position(x: min(80, size.width * 0.17), y: ctx.safeArea.top + 112)
            .allowsHitTesting(false)
    }

    private func say(_ word: Int) {
        let text = ctx.document.words[word].text
        speaker.preview(text, voiceID: ctx.settings.voiceID, wordsPerMinute: 30)
        Haptics.tap()
        withAnimation(.spring(response: 0.18, dampingFraction: 0.3)) { wiggle = word }
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            withAnimation(.spring(response: 0.3)) { wiggle = nil }
        }
    }
}

/// Position des mots d'une phrase sur le nuage (calculée une fois par phrase).
final class SkyLayoutCache {
    struct Placed { let word: Int; let center: CGPoint }
    struct Layout { let words: [Placed]; let size: CGSize; let font: UIFont }

    private var key = ""
    private var store: [Int: Layout] = [:]

    func layout(document: PrompterDocument, sentence: Int, maxWidth: CGFloat, maxHeight: CGFloat,
                fontSize: Double, font: ReadingFont) -> Layout {
        let k = "\(ObjectIdentifier(document).hashValue)-\(Int(maxWidth))-\(Int(maxHeight))-\(fontSize)-\(font.rawValue)"
        if k != key { store.removeAll(); key = k }
        if let l = store[sentence] { return l }
        let l = Self.make(document, sentence, maxWidth, maxHeight, fontSize, font)
        store[sentence] = l
        return l
    }

    private static func make(_ doc: PrompterDocument, _ s: Int, _ maxW: CGFloat, _ maxH: CGFloat,
                             _ fontSize: Double, _ fontChoice: ReadingFont) -> Layout {
        guard doc.sentences.indices.contains(s) else { return Layout(words: [], size: .zero, font: .systemFont(ofSize: 20)) }
        let range = doc.sentences[s].words
        var result = Layout(words: [], size: .zero, font: .systemFont(ofSize: 20))
        for scale in [1.0, 0.88, 0.77, 0.67, 0.58, 0.5, 0.43] {
            let font = fontChoice.uiFont(size: CGFloat(fontSize * scale), weight: .bold)
            let attrs: [NSAttributedString.Key: Any] = [.font: font]
            let space = (" " as NSString).size(withAttributes: attrs).width + 14
            let lh = font.lineHeight * 1.42
            var lines: [[(Int, CGFloat)]] = [[]]
            var lineW: CGFloat = 0
            for w in range {
                let ww = (doc.words[w].text as NSString).size(withAttributes: attrs).width + 12
                if !lines[lines.count - 1].isEmpty, lineW + space + ww > maxW {
                    lines.append([])
                    lineW = 0
                }
                lineW += (lines[lines.count - 1].isEmpty ? 0 : space) + ww
                lines[lines.count - 1].append((w, ww))
            }
            let height = CGFloat(lines.count) * lh
            var placed: [Placed] = []
            for (i, line) in lines.enumerated() {
                let total = line.reduce(0) { $0 + $1.1 } + space * CGFloat(max(0, line.count - 1))
                var x = (maxW - total) / 2
                for (w, ww) in line {
                    placed.append(Placed(word: w, center: CGPoint(x: x + ww / 2, y: CGFloat(i) * lh + lh / 2)))
                    x += ww + space
                }
            }
            result = Layout(words: placed, size: CGSize(width: maxW, height: height), font: font)
            if height <= maxH { break }
        }
        return result
    }
}
