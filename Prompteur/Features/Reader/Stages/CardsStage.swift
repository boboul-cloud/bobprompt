import SwiftUI

/// 3D : une phrase par carte. Les cartes se tournent comme des pages.
struct CardsStage: View {
    let ctx: StageContext

    @State private var shown: Double = 0
    @GestureState(resetTransaction: Transaction(animation: .spring(response: 0.5, dampingFraction: 0.85)))
    private var drag: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let doc = ctx.document
            // Mot « grossier » : la pile n'est recalculée qu'au changement de mot.
            let current = doc.isEmpty ? 0 : doc.sentenceIndex(ofWord: ctx.engine.coarseWord)
            let cardW = min(size.width * 0.86, 640)
            let cardH = min(size.height * 0.52, 540)
            let tiltX = ctx.settings.motionParallax ? ctx.tilt.x : 0
            let tiltY = ctx.settings.motionParallax ? ctx.tilt.y : 0
            let dragProgress = Double(drag / max(1, cardW))

            ZStack {
                CardsBackdrop(accent: ctx.accent)

                // Pile à part : l'ordre des cartes ne doit pas passer sous le fond.
                ZStack {
                    ForEach(visibleCards(current: current, count: doc.sentences.count), id: \.self) { i in
                        card(index: i, current: current, size: CGSize(width: cardW, height: cardH))
                            .modifier(CardPose(r: liveR(i: i, current: current, dragProgress: dragProgress),
                                               width: cardW, tiltX: tiltX, tiltY: tiltY))
                            .zIndex(-Double(i))
                    }
                }
                .offset(y: -size.height * 0.03)

                counter(current: current, total: doc.sentences.count)
                    .position(x: size.width / 2, y: size.height * 0.47 + cardH / 2 + 104)
            }
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
            .gesture(swipe(width: cardW, current: current))
            .onChange(of: current, initial: true) { _, new in
                withAnimation(.spring(response: 0.62, dampingFraction: 0.82)) { shown = Double(new) }
            }
            .onChange(of: doc.id, initial: true) { ctx.engine.setTimeline(doc.timeline) }
        }
    }

    private func visibleCards(current: Int, count: Int) -> [Int] {
        guard count > 0 else { return [] }
        let lo = max(0, current - 1)
        let hi = min(count - 1, current + 3)
        return lo <= hi ? Array(lo...hi) : []
    }

    /// Pendant un glisser, la carte du dessus suit le doigt (et la précédente revient).
    private func liveR(i: Int, current: Int, dragProgress: Double) -> Double {
        let p = max(-1, min(1, dragProgress))
        if p < 0, i == current { return Double(i) - shown + p }
        if p > 0, i == current - 1 { return Double(i) - shown + p }
        return Double(i) - shown
    }

    // MARK: Carte

    private func card(index: Int, current: Int, size: CGSize) -> some View {
        let doc = ctx.document
        let sentence = doc.sentences[index]
        let s = ctx.settings
        let isCurrent = index == current
        var paint = LinePaint(base: Color(hex: "#1D1B22"))
        if s.syllables {
            let (a, b) = s.syllableColors(onDark: false)
            paint.syllableA = a
            paint.syllableB = b
        }
        paint.highlightBackground = Color(hex: "#FFD84A").opacity(0.85)
        paint.unreadColor = s.syllables ? nil : Color(hex: "#1D1B22").opacity(0.5)
        let word = ctx.engine.coarseWord
        let highlight = isCurrent && s.highlightWord && ctx.engine.phase != .idle ? word : nil
        let text = TextStyler.line(doc, words: sentence.words, paint: paint, highlight: highlight,
                                   readBefore: isCurrent && ctx.engine.phase != .idle ? word : nil)
        let font = s.font.uiFont(size: s.fontSize * 1.05)

        return VStack(spacing: 0) {
            HStack {
                Capsule().fill(ctx.accent).frame(width: 34, height: 6)
                Spacer()
                Text("\(index + 1)")
                    .font(Typo.caption(13))
                    .foregroundStyle(Color(hex: "#1D1B22").opacity(0.4))
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)

            Text(text)
                .font(Font(ui: font))
                .multilineTextAlignment(s.alignment.textAlignment)
                .lineSpacing(font.pointSize * 0.18)
                .minimumScaleFactor(0.3)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: s.alignment.alignment)
                .padding(.horizontal, 26)
                .padding(.vertical, 18)
        }
        .frame(width: size.width, height: size.height)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: "#FFFDF7"), Color(hex: "#F3EEE2")],
                                     startPoint: .top, endPoint: .bottom))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.7), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 22, y: 14)
    }

    private func counter(current: Int, total: Int) -> some View {
        VStack {
            HStack(spacing: 6) {
                ForEach(0..<min(total, 14), id: \.self) { i in
                    let idx = total <= 14 ? i : Int(Double(i) / 13 * Double(total - 1))
                    Capsule()
                        .fill(idx <= current ? ctx.accent : .white.opacity(0.25))
                        .frame(width: idx == current ? 18 : 6, height: 6)
                }
            }
            .animation(.spring(response: 0.4), value: current)
        }
        .allowsHitTesting(false)
    }

    // MARK: Gestes

    private func swipe(width: CGFloat, current: Int) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($drag) { v, drag, _ in
                guard abs(v.translation.width) > abs(v.translation.height) else { return }
                var d = v.translation.width
                if current == 0, d > 0 { d *= 0.25 }
                if current >= ctx.document.sentences.count - 1, d < 0 { d *= 0.25 }
                drag = d
            }
            .onEnded { v in
                let predicted = v.predictedEndTranslation.width
                let threshold = width * 0.22
                if predicted < -threshold || v.translation.width < -threshold {
                    ctx.engine.jumpSentence(+1)
                    Haptics.tap()
                } else if predicted > threshold || v.translation.width > threshold {
                    ctx.engine.jumpSentence(-1)
                    Haptics.tap()
                }
            }
    }
}

/// Pose d'une carte selon son rang `r` (0 = carte lue, < 0 = déjà tournée, > 0 = dans la pile).
struct CardPose: ViewModifier, Animatable {
    var r: Double
    let width: CGFloat
    let tiltX: Double
    let tiltY: Double

    var animatableData: Double {
        get { r }
        set { r = newValue }
    }

    func body(content: Content) -> some View {
        let flip = max(0, min(1, -r))          // 0 → 1 quand la carte se tourne
        let depth = max(0, r)                  // rang dans la pile
        let stack = min(depth, 3)
        return content
            .rotation3DEffect(.degrees(-flip * 104), axis: (x: 0, y: 1, z: 0),
                              anchor: .leading, perspective: 0.4)
            .rotation3DEffect(.degrees(Double(stack) * (Int(depth) % 2 == 0 ? 1.6 : -1.6)), axis: (x: 0, y: 0, z: 1))
            .rotation3DEffect(.degrees(tiltX * 7), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            .rotation3DEffect(.degrees(-tiltY * 5 + stack * 4), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
            .scaleEffect(1 - stack * 0.055)
            .offset(x: -flip * width * 0.08, y: CGFloat(stack) * 26 - CGFloat(flip) * 10)
            .brightness(-stack * 0.06)
            .opacity(r < -0.98 ? 0 : (depth > 3 ? max(0, 4 - depth) : 1))
    }
}

struct CardsBackdrop: View {
    var accent: Color
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#181A33"), Color(hex: "#2B2150"), Color(hex: "#151628")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [accent.opacity(0.28), .clear], center: .top, startRadius: 0, endRadius: 520)
            RadialGradient(colors: [Color(hex: "#5B5BF5").opacity(0.22), .clear], center: .bottomTrailing,
                           startRadius: 0, endRadius: 480)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
