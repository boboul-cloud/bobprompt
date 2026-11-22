import SwiftUI
import UIKit

/// 3D : le texte est enroulé sur un tambour qu'on fait tourner.
///
/// - glisser verticalement : fait tourner le tambour (avec élan) ;
/// - glisser horizontalement : fait pivoter la vue autour du tambour ;
/// - pincer : rapproche / éloigne ;
/// - incliner l'appareil : parallaxe.
struct DrumStage: View {
    let ctx: StageContext

    static let defaultYaw = -0.2
    static let defaultPitch = 0.08

    @State private var holder = LayoutHolder()
    @State private var yaw = DrumStage.defaultYaw
    @State private var pitch = DrumStage.defaultPitch
    @State private var zoom = 1.0
    @GestureState private var track: DragTrack?
    @State private var lastAxis: Axis = .vertical
    @State private var zoomStart: Double?

    struct DragTrack: Equatable {
        var axis: Axis
        var yaw: Double
        var pitch: Double
        var last: CGFloat
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let s = ctx.settings
            let uiFont = s.font.uiFont(size: s.fontSize * 0.86)
            let lineWidth = min(size.width * 0.74, 700)
            let (layout, key) = ContinuousLayout.make(ctx, holder: holder, width: lineWidth, uiFont: uiFont)
            let lh = layout.lineHeight
            let radius = max(size.height * 0.36, lh * 4.6)
            let tiltX = s.motionParallax ? ctx.tilt.x : 0
            let tiltY = s.motionParallax ? ctx.tilt.y : 0
            let view = ViewAngles(yaw: yaw + tiltX * 0.28, pitch: pitch - tiltY * 0.2)
            let proj = Projection3D(cameraDistance: size.height * 1.7 / zoom)
            let readingY = size.height * 0.46

            ZStack {
                DrumBackdrop(tiltX: tiltX, tiltY: tiltY, accent: ctx.accent)

                ZStack {
                    rims(radius: radius, halfWidth: lineWidth / 2 + 26, view: view, proj: proj)
                    slats(layout: layout, radius: radius, width: lineWidth + 52, view: view, proj: proj)
                    lines(layout: layout, radius: radius, font: Font(ui: uiFont), view: view, proj: proj)
                }
                .frame(width: size.width, height: size.height)
                .offset(y: readingY - size.height / 2)

                readingWindow(size: size, y: readingY, lh: lh, view: view)
                recenterButton
            }
            .contentShape(Rectangle())
            .gesture(drag(layout: layout))
            .simultaneousGesture(pinch)
            .onChange(of: key, initial: true) { ctx.engine.setTimeline(layout.timeline) }
        }
        .onChange(of: track == nil) { _, ended in
            if ended { DispatchQueue.main.async { ctx.engine.cancelScrubIfNeeded() } }
        }
    }

    struct ViewAngles { var yaw: Double; var pitch: Double }

    /// Rotation de la vue, recentrée pour que la ligne lue reste au milieu de l'écran.
    private func viewTransform(radius: CGFloat, view: ViewAngles) -> CATransform3D {
        let r = Projection3D.rotateY(CGFloat(view.yaw)).concatenating(Projection3D.rotateX(CGFloat(-view.pitch)))
        return r.concatenating(Projection3D.translate(-radius * r.m31, -radius * r.m32, -radius))
    }

    /// Position d'un élément posé sur le tambour à l'angle `theta`, vu depuis la caméra.
    private func model(theta: Double, radius: CGFloat, view: ViewAngles, x: CGFloat = 0) -> CATransform3D {
        Projection3D.translate(x, 0, radius)
            .concatenating(Projection3D.rotateX(CGFloat(-theta)))
            .concatenating(viewTransform(radius: radius, view: view))
    }

    // MARK: Lignes

    @ViewBuilder
    private func lines(layout: LineLayout, radius: CGFloat, font: Font, view: ViewAngles, proj: Projection3D) -> some View {
        let engine = ctx.engine
        let y = layout.readingY(atBeat: engine.beat)
        let visible = layout.lines(in: y - radius * 1.45, y + radius * 1.45)
        let current = ctx.settings.highlightWord ? engine.currentWord : nil
        let paint = drumPaint
        let lineSize = CGSize(width: layout.maxWidth, height: layout.lineHeight)
        let anchor: UnitPoint = ctx.settings.alignment == .leading ? .leading : .center

        ForEach(visible) { line in
            let theta = Double((line.center - y) / radius)
            if abs(theta) < 1.4 {
                let m = model(theta: theta, radius: radius, view: view)
                let facing = cos(theta)
                let near = max(0, 1 - abs(theta) / 0.16)
                Text(holder.cache.line(ctx.document, line: line, layoutSignature: holder.signature,
                                       paint: paint, highlight: current))
                    .font(font)
                    .lineLimit(1)
                    .fixedSize()
                    .scaleEffect(min(1, layout.maxWidth / max(1, line.width)), anchor: anchor)
                    .frame(width: lineSize.width, height: lineSize.height, alignment: ctx.settings.alignment.alignment)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.07 * near))
                            .padding(.horizontal, -18)
                    )
                    .projectionEffect(proj.projection(size: lineSize, model: m))
                    .opacity(pow(max(0, facing), 1.6) * (ctx.settings.focusLine ? (0.45 + 0.55 * max(near, facing > 0.97 ? 0.6 : 0)) : 1))
                    .zIndex(Double(Projection3D.depth(of: m)))
            }
        }
    }

    private var drumPaint: LinePaint {
        let s = ctx.settings
        var p = LinePaint(base: Color(hex: "#F6F2FF"))
        if s.syllables {
            let (a, b) = s.syllableColors(onDark: true)
            p.syllableA = a
            p.syllableB = b
        }
        if s.syllables {
            p.highlightBackground = Color.white.opacity(0.17)
            p.highlightUnderline = ctx.accent
        } else {
            p.highlightBackground = ctx.accent.opacity(0.6)
        }
        return p
    }

    // MARK: Structure du tambour

    private func slats(layout: LineLayout, radius: CGFloat, width: CGFloat, view: ViewAngles, proj: Projection3D) -> some View {
        let y = layout.readingY(atBeat: ctx.engine.beat)
        let step = Double(layout.lineHeight / radius)
        let phase = Double(y / radius).truncatingRemainder(dividingBy: step)
        let size = CGSize(width: width, height: 1.5)
        return ForEach(-9...9, id: \.self) { k in
            let theta = Double(k) * step - phase + step / 2
            if abs(theta) < 1.45 {
                let m = model(theta: theta, radius: radius - 2, view: view)
                Rectangle()
                    .fill(LinearGradient(colors: [.clear, .white.opacity(0.16), .white.opacity(0.16), .clear],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: size.width, height: size.height)
                    .projectionEffect(proj.projection(size: size, model: m))
                    .opacity(max(0, cos(theta)))
                    .zIndex(Double(Projection3D.depth(of: m)) - 1)
            }
        }
    }

    private func rims(radius: CGFloat, halfWidth: CGFloat, view: ViewAngles, proj: Projection3D) -> some View {
        let size = CGSize(width: radius * 2, height: radius * 2)
        return ForEach([-1.0, 1.0], id: \.self) { side in
            let m = Projection3D.rotateY(.pi / 2)
                .concatenating(Projection3D.translate(halfWidth * side, 0, 0))
                .concatenating(viewTransform(radius: radius, view: view))
            ZStack {
                Circle().fill(
                    RadialGradient(colors: [ctx.accent.opacity(0.06), Color.white.opacity(0.01)],
                                   center: .center, startRadius: 0, endRadius: radius))
                Circle().strokeBorder(
                    AngularGradient(colors: [.white.opacity(0.4), ctx.accent.opacity(0.35), .white.opacity(0.1),
                                             ctx.accent.opacity(0.35), .white.opacity(0.4)], center: .center),
                    lineWidth: 2.5)
                Circle().strokeBorder(.white.opacity(0.08), lineWidth: 1).padding(radius * 0.25)
            }
            .frame(width: size.width, height: size.height)
            .projectionEffect(proj.projection(size: size, model: m))
            .zIndex(Double(Projection3D.depth(of: m)) - radius)
        }
    }

    private func readingWindow(size: CGSize, y: CGFloat, lh: CGFloat, view: ViewAngles) -> some View {
        let dx = CGFloat(sin(view.yaw)) * 14
        return ZStack {
            Image(systemName: "arrowtriangle.right.fill").position(x: 14 + dx, y: y)
            Image(systemName: "arrowtriangle.left.fill").position(x: size.width - 14 + dx, y: y)
        }
        .font(.system(size: min(20, lh * 0.34), weight: .bold))
        .foregroundStyle(ctx.accent)
        .shadow(color: ctx.accent.opacity(0.7), radius: 8)
        .allowsHitTesting(false)
    }

    private var recenterButton: some View {
        let moved = abs(yaw - Self.defaultYaw) > 0.05 || abs(pitch - Self.defaultPitch) > 0.05 || abs(zoom - 1) > 0.05
        return VStack {
            HStack {
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                        yaw = Self.defaultYaw
                        pitch = Self.defaultPitch
                        zoom = 1
                    }
                    ctx.tilt.recenter()
                    Haptics.tap()
                } label: {
                    Image(systemName: "rotate.3d")
                }
                .buttonStyle(GlassCircleButtonStyle(size: 40))
                .accessibilityLabel("Recentrer la vue 3D")
            }
            Spacer()
        }
        .padding(.top, ctx.safeArea.top + 64)
        .padding(.trailing, 16)
        .opacity(moved ? 1 : 0)
        .animation(.easeInOut(duration: 0.25), value: moved)
    }

    // MARK: Gestes

    private func drag(layout: LineLayout) -> some Gesture {
        let bpp = ContinuousLayout.beatsPerPoint(layout)
        return DragGesture(minimumDistance: 8)
            .updating($track) { v, track, _ in
                if track == nil {
                    let axis: Axis = abs(v.translation.width) > abs(v.translation.height) ? .horizontal : .vertical
                    track = DragTrack(axis: axis, yaw: yaw, pitch: pitch, last: 0)
                    lastAxis = axis
                    if axis == .vertical { ctx.engine.beginScrub() }
                }
                guard var t = track else { return }
                switch t.axis {
                case .horizontal:
                    yaw = min(1.15, max(-1.15, t.yaw + Double(v.translation.width) * 0.006))
                    pitch = min(0.6, max(-0.35, t.pitch - Double(v.translation.height) * 0.002))
                case .vertical:
                    let dy = v.translation.height - t.last
                    t.last = v.translation.height
                    track = t
                    ctx.engine.scrub(by: -Double(dy) * bpp)
                }
            }
            .onEnded { v in
                if lastAxis == .vertical {
                    let vy = v.predictedEndTranslation.height - v.translation.height
                    ctx.engine.endScrub(velocity: -Double(vy) * bpp * 2.4)
                }
            }
    }

    private var pinch: some Gesture {
        MagnifyGesture()
            .onChanged { v in
                if zoomStart == nil { zoomStart = zoom }
                zoom = min(1.8, max(0.6, (zoomStart ?? 1) * v.magnification))
            }
            .onEnded { _ in zoomStart = nil }
    }
}

/// Fond nocturne avec des lueurs qui bougent avec l'inclinaison.
struct DrumBackdrop: View {
    var tiltX: Double
    var tiltY: Double
    var accent: Color

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#07081A"), Color(hex: "#151137"), Color(hex: "#0A0A1E")],
                           startPoint: .top, endPoint: .bottom)
            Canvas { context, size in
                var rng = SeededRandom(seed: 42)
                for i in 0..<38 {
                    let depth = 0.3 + rng.next() * 0.9
                    let x = rng.next() * size.width + CGFloat(tiltX) * 40 * depth
                    let y = rng.next() * size.height + CGFloat(tiltY) * 30 * depth
                    let r = 2 + rng.next() * 26 * depth
                    let tint: Color = i % 3 == 0 ? accent : (i % 3 == 1 ? Color(hex: "#6C7BFF") : .white)
                    context.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                                 with: .color(tint.opacity(0.05 + 0.08 * (1 - depth / 1.2))))
                }
            }
            .blur(radius: 6)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

/// Hasard reproductible (même décor à chaque image).
struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 6364136223846793005 &+ 1442695040888963407 }
    mutating func next() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat((state >> 33) % 10_000) / 10_000
    }
}
