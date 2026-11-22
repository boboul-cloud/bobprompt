import SwiftUI
import UIKit

/// Vieille école : moniteur cathodique vert ou ambre.
struct CRTStage: View {
    let ctx: StageContext
    let amber: Bool
    let title: String

    @State private var holder = LayoutHolder()
    @State private var start = Date()

    private var phosphor: Color { amber ? Color(hex: "#FFB43A") : Color(hex: "#46FF86") }
    private var phosphorDim: Color { amber ? Color(hex: "#C9781A") : Color(hex: "#1FB956") }
    private var glow: Color { amber ? Color(hex: "#FF8A00") : Color(hex: "#18FF5A") }
    private var screen: Color { amber ? Color(hex: "#0C0602") : Color(hex: "#020A05") }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                let t = tl.date.timeIntervalSince(start)
                let bezel = min(size.width, size.height) * 0.025
                ZStack {
                    screenContent(size: size, time: t)
                        .opacity(0.965 + 0.035 * sin(t * 53) * sin(t * 7.3))
                    CRTGlass(time: t, glow: glow)
                }
                .clipShape(RoundedRectangle(cornerRadius: bezel * 3.2, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: bezel * 3.2, style: .continuous)
                        .strokeBorder(LinearGradient(colors: [Color(hex: "#2A2A2A"), Color(hex: "#050505")],
                                                     startPoint: .top, endPoint: .bottom), lineWidth: bezel)
                )
            }
        }
        .background(Color.black.ignoresSafeArea())
    }

    @ViewBuilder
    private func screenContent(size: CGSize, time: Double) -> some View {
        let s = ctx.settings
        let uiFont = StageFonts.crt(size: s.fontSize * 0.86)
        let margin = max(26, size.width * 0.08)
        let (layout, key) = ContinuousLayout.make(ctx, holder: holder, width: min(size.width - margin * 2, 940),
                                                  uiFont: uiFont, spacing: 1.36, uppercase: s.retroUppercase)
        let readingY = size.height * s.readingLine
        let lh = layout.lineHeight
        let boot = min(1, time / 1.7)

        ZStack {
            screen
            RadialGradient(colors: [glow.opacity(0.10), .clear], center: .center, startRadius: 0,
                           endRadius: max(size.width, size.height) * 0.7)

            Rectangle()
                .fill(phosphor.opacity(0.06))
                .frame(height: lh * 1.04)
                .position(x: size.width / 2, y: readingY)

            ScrollingTextLayer(ctx: ctx, holder: holder, layout: layout, size: size, readingY: readingY,
                               font: Font(ui: uiFont), paint: paint, highlightWord: s.highlightWord,
                               focus: s.focusLine, alignment: s.alignment.alignment)
                .edgeFade(top: 0.12, bottom: 0.12)
                .compositingGroup()
                .shadow(color: glow.opacity(0.85), radius: 3)
                .shadow(color: glow.opacity(0.45), radius: 14)
                .opacity(boot < 1 ? max(0, (boot - 0.75) * 4) : 1)

            markers(size: size, readingY: readingY, lh: lh, time: time)
            statusBars(size: size, time: time)
            if boot < 1 { bootScreen(progress: boot, size: size) }
        }
        .contentShape(Rectangle())
        .modifier(ScrubGesture(engine: ctx.engine, beatsPerPoint: ContinuousLayout.beatsPerPoint(layout)))
        .onChange(of: key, initial: true) { ctx.engine.setTimeline(layout.timeline) }
    }

    private var paint: LinePaint {
        var p = LinePaint(base: phosphor, uppercase: ctx.settings.retroUppercase)
        if ctx.settings.syllables {
            p.syllableA = phosphor
            p.syllableB = phosphorDim
        }
        // Vidéo inverse sur le mot en cours.
        p.highlightBackground = phosphor
        p.highlightForeground = screen
        return p
    }

    private func markers(size: CGSize, readingY: CGFloat, lh: CGFloat, time: Double) -> some View {
        let blink = Int(time * 2.2) % 2 == 0
        return ZStack {
            Text("▶").position(x: 16, y: readingY)
            Text("◀").position(x: size.width - 16, y: readingY)
            if !ctx.engine.isPlaying && blink {
                Rectangle().fill(phosphor)
                    .frame(width: lh * 0.32, height: lh * 0.62)
                    .position(x: size.width - 40, y: readingY + lh * 0.9)
            }
        }
        .font(.system(size: min(20, lh * 0.34), weight: .heavy, design: .monospaced))
        .foregroundStyle(phosphor)
        .shadow(color: glow, radius: 6)
        .allowsHitTesting(false)
    }

    private func statusBars(size: CGSize, time: Double) -> some View {
        let pct = Int((ctx.engine.displayProgress * 100).rounded())
        let state: String = {
            switch ctx.engine.phase {
            case .playing: return "LECTURE"
            case .countdown: return "PRÊT"
            case .finished: return "FIN"
            default: return "PAUSE"
            }
        }()
        return VStack {
            HStack {
                Text("BOBPROMPT ▸ \(title.uppercased())").lineLimit(1)
                Spacer(minLength: 12)
                Text(String(format: "%03d%%", pct))
            }
            Spacer()
            HStack {
                Text("\(state) ▸ \(Int(ctx.settings.wordsPerMinute)) MOTS/MIN")
                Spacer()
                Text(String(format: "%02d:%02d", ctx.engine.remainingSeconds / 60, ctx.engine.remainingSeconds % 60))
            }
        }
        .font(.system(size: 12, weight: .bold, design: .monospaced))
        .foregroundStyle(phosphor.opacity(0.75))
        .shadow(color: glow.opacity(0.7), radius: 4)
        .padding(.horizontal, 30)
        .padding(.top, max(26, ctx.safeArea.top + 2))
        .padding(.bottom, max(30, ctx.safeArea.bottom + 18))
        .allowsHitTesting(false)
    }

    private func bootScreen(progress: Double, size: CGSize) -> some View {
        let lines = [
            "BOBPROMPT 2.0  (C) 2026",
            "MÉMOIRE ........ 64K OK",
            "TEXTE .......... \(ctx.document.wordCount) MOTS",
            "PRÊT."
        ]
        let full = lines.joined(separator: "\n")
        let shown = Int(Double(full.count) * min(1, progress / 0.7))
        return Text(String(full.prefix(shown)) + (progress < 0.95 ? "█" : ""))
            .font(.system(size: 15, weight: .bold, design: .monospaced))
            .foregroundStyle(phosphor)
            .shadow(color: glow, radius: 5)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 34)
            .padding(.top, size.height * 0.18)
            .opacity(progress > 0.85 ? (1 - progress) / 0.15 : 1)
            .allowsHitTesting(false)
    }
}

/// Verre du tube cathodique : lignes de balayage, bande qui roule, vignettage
/// et reflet bombé.
struct CRTGlass: View {
    let time: Double
    let glow: Color

    var body: some View {
        GeometryReader { g in
            let size = g.size
            let roll = (time * 0.085).truncatingRemainder(dividingBy: 1) * 1.5 - 0.25
            ZStack {
                Scanlines().equatable()
                LinearGradient(colors: [.clear, .white.opacity(0.045), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: size.height * 0.16)
                    .position(x: size.width / 2, y: size.height * roll)
                RadialGradient(colors: [.clear, .clear, .black.opacity(0.55), .black.opacity(0.9)],
                               center: .center, startRadius: 0,
                               endRadius: hypot(size.width, size.height) * 0.56)
                // Reflet du verre bombé.
                Ellipse()
                    .fill(LinearGradient(colors: [.white.opacity(0.09), .clear], startPoint: .top, endPoint: .bottom))
                    .frame(width: size.width * 0.9, height: size.height * 0.42)
                    .position(x: size.width * 0.42, y: size.height * 0.2)
                    .blur(radius: 18)
                RadialGradient(colors: [glow.opacity(0.06), .clear], center: .center, startRadius: 0,
                               endRadius: max(size.width, size.height) * 0.6)
                    .blendMode(.screen)
            }
        }
        .allowsHitTesting(false)
    }
}

struct Scanlines: View, Equatable {
    var body: some View {
        Canvas { ctx, size in
            var y: CGFloat = 0
            while y < size.height {
                ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1.2)), with: .color(.black.opacity(0.28)))
                y += 3
            }
        }
        .allowsHitTesting(false)
    }
}
