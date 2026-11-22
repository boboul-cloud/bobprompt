import SwiftUI
import UIKit

/// Lignes qui défilent devant une ligne de lecture fixe.
/// Partagé par le mode classique et les écrans cathodiques.
struct ScrollingTextLayer: View {
    let ctx: StageContext
    let holder: LayoutHolder
    let layout: LineLayout
    let size: CGSize
    let readingY: CGFloat
    let font: Font
    let paint: LinePaint
    var highlightWord: Bool
    var focus: Bool
    var alignment: Alignment

    var body: some View {
        let engine = ctx.engine
        let y = layout.readingY(atBeat: engine.beat)
        let lh = layout.lineHeight
        let visible = layout.lines(in: y - readingY - lh, y + (size.height - readingY) + lh)
        let current = highlightWord ? engine.currentWord : nil
        let anchor: UnitPoint = alignment == .leading ? .leading : .center

        ZStack(alignment: .topLeading) {
            ForEach(visible) { line in
                let screenY = readingY + (line.center - y)
                let d = (screenY - readingY) / lh
                let text = holder.cache.line(ctx.document, line: line, layoutSignature: holder.signature,
                                             paint: paint, highlight: current)
                Text(text)
                    .font(font)
                    .lineLimit(1)
                    .fixedSize()
                    .scaleEffect(min(1, layout.maxWidth / max(1, line.width)), anchor: anchor)
                    .frame(width: layout.maxWidth, height: line.height, alignment: alignment)
                    .opacity(focus ? Self.opacity(d) : 1)
                    .position(x: size.width / 2, y: screenY)
            }
        }
        .frame(width: size.width, height: size.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ctx.document.sentenceText(ctx.document.sentenceIndex(ofWord: engine.currentWord)))
    }

    /// Les lignes déjà lues s'effacent, les suivantes restent visibles.
    static func opacity(_ d: CGFloat) -> Double {
        if abs(d) < 0.55 { return 1 }
        if d < 0 { return max(0.16, 1 - Double(-d - 0.55) * 0.6) }
        return max(0.34, 1 - Double(d - 0.55) * 0.2)
    }
}

/// Mise en lignes d'un mode à défilement continu (et ligne de temps associée).
enum ContinuousLayout {
    static func make(_ ctx: StageContext, holder: LayoutHolder, width: CGFloat, uiFont: UIFont,
                     spacing: CGFloat = 1.32, uppercase: Bool = false) -> (LineLayout, LayoutKey) {
        let s = ctx.settings
        let key = LayoutKey(document: ctx.document.id, width: Int(width), fontSize: Double(uiFont.pointSize),
                            font: uiFont.fontName, oneWordPerLine: s.oneWordPerLine,
                            uppercase: uppercase, spacing: Double(spacing))
        let layout = holder.update(key: key) {
            LineLayout.make(document: ctx.document, font: uiFont, maxWidth: width, lineSpacing: spacing,
                            oneWordPerLine: s.oneWordPerLine, uppercase: uppercase)
        }
        return (layout, key)
    }

    static func beatsPerPoint(_ layout: LineLayout) -> Double {
        layout.timeline.total / Double(max(1, layout.totalHeight))
    }
}

struct ClassicStage: View {
    let ctx: StageContext
    @State private var holder = LayoutHolder()

    var body: some View {
        GeometryReader { geo in
            let s = ctx.settings
            let size = geo.size
            let theme = s.classicTheme
            let uiFont = s.font.uiFont(size: s.fontSize)
            let margin = max(22, size.width * 0.07)
            let (layout, key) = ContinuousLayout.make(ctx, holder: holder,
                                                      width: min(size.width - margin * 2, 980), uiFont: uiFont)
            let readingY = size.height * s.readingLine
            let lh = layout.lineHeight

            ZStack {
                background(theme)
                band(theme, y: readingY, height: lh * 1.04, width: size.width)
                ScrollingTextLayer(ctx: ctx, holder: holder, layout: layout, size: size,
                                   readingY: readingY, font: Font(ui: uiFont), paint: paint(theme),
                                   highlightWord: s.highlightWord, focus: s.focusLine,
                                   alignment: s.alignment.alignment)
                    .edgeFade(top: 0.1, bottom: 0.12)
                cueArrows(theme, y: readingY, size: size, lh: lh)
            }
            .contentShape(Rectangle())
            .modifier(ScrubGesture(engine: ctx.engine, beatsPerPoint: ContinuousLayout.beatsPerPoint(layout)))
            .onChange(of: key, initial: true) { ctx.engine.setTimeline(layout.timeline) }
        }
    }

    private func paint(_ theme: ClassicTheme) -> LinePaint {
        let s = ctx.settings
        var p = LinePaint(base: textColor(theme))
        if s.syllables {
            let (a, b) = s.syllableColors(onDark: theme.isDark)
            p.syllableA = a
            p.syllableB = b
        }
        switch theme {
        case .night:
            if s.syllables {
                // Sur des syllabes colorées, un fond clair reste lisible.
                p.highlightBackground = Color.white.opacity(0.17)
                p.highlightUnderline = Palette.onAir
            } else {
                p.highlightBackground = Palette.onAir.opacity(0.55)
                p.highlightForeground = .white
            }
        case .paper:
            p.highlightBackground = Color(hex: "#FFD84A").opacity(0.75)
        case .contrast:
            p.highlightBackground = Color.white.opacity(0.28)
            p.highlightUnderline = s.syllables ? .white : nil
        }
        return p
    }

    private func textColor(_ theme: ClassicTheme) -> Color {
        switch theme {
        case .night: return Color(hex: "#F4F0E6")
        case .paper: return Color(hex: "#1C1A17")
        case .contrast: return .white
        }
    }

    @ViewBuilder
    private func background(_ theme: ClassicTheme) -> some View {
        switch theme {
        case .night:
            ZStack {
                LinearGradient(colors: [Color(hex: "#0A0D1A"), Color(hex: "#121933"), Color(hex: "#0B0E1C")],
                               startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [Color(hex: "#2A3A8A").opacity(0.35), .clear],
                               center: UnitPoint(x: 0.5, y: ctx.settings.readingLine), startRadius: 10, endRadius: 420)
            }
            .ignoresSafeArea()
        case .paper:
            ZStack {
                Color(hex: "#FBF6EA")
                LinearGradient(colors: [.black.opacity(0.05), .clear, .black.opacity(0.06)],
                               startPoint: .top, endPoint: .bottom)
            }
            .ignoresSafeArea()
        case .contrast:
            Color.black.ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func band(_ theme: ClassicTheme, y: CGFloat, height: CGFloat, width: CGFloat) -> some View {
        Group {
            switch theme {
            case .night:
                Rectangle().fill(
                    LinearGradient(colors: [.white.opacity(0.02), .white.opacity(0.075), .white.opacity(0.02)],
                                   startPoint: .top, endPoint: .bottom))
            case .paper:
                // Règle de lecture surligneur (aide les enfants à suivre la ligne).
                RoundedRectangle(cornerRadius: 6).fill(Color(hex: "#FFE27A").opacity(0.55))
                    .padding(.horizontal, 10)
            case .contrast:
                VStack {
                    Rectangle().fill(.white.opacity(0.22)).frame(height: 1)
                    Spacer()
                    Rectangle().fill(.white.opacity(0.22)).frame(height: 1)
                }
            }
        }
        .frame(width: width, height: height)
        .position(x: width / 2, y: y)
        .allowsHitTesting(false)
    }

    private func cueArrows(_ theme: ClassicTheme, y: CGFloat, size: CGSize, lh: CGFloat) -> some View {
        let color: Color = theme == .contrast ? .white : Palette.onAir
        let arrow = min(22, lh * 0.36)
        return ZStack {
            Image(systemName: "arrowtriangle.right.fill")
                .position(x: 10 + arrow / 2, y: y)
            Image(systemName: "arrowtriangle.left.fill")
                .position(x: size.width - 10 - arrow / 2, y: y)
        }
        .font(.system(size: arrow, weight: .bold))
        .foregroundStyle(color)
        .shadow(color: color.opacity(0.6), radius: 6)
        .allowsHitTesting(false)
    }
}
