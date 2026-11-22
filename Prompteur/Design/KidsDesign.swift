import SwiftUI

/// Couleurs franches du coin des enfants.
enum KidsPalette {
    static let sky = Color(hex: "#4FB8FF")
    static let skyDeep = Color(hex: "#2A8CF0")
    static let sun = Color(hex: "#FFD23F")
    static let sunDeep = Color(hex: "#F5A400")
    static let grass = Color(hex: "#58CC5C")
    static let grassDeep = Color(hex: "#3BA640")
    static let candy = Color(hex: "#FF6FB5")
    static let candyDeep = Color(hex: "#E0458F")
    static let orange = Color(hex: "#FF9A3C")
    static let orangeDeep = Color(hex: "#E57716")
    static let grape = Color(hex: "#9B6BFF")
    static let grapeDeep = Color(hex: "#7646E0")
    static let ink = Color(hex: "#24304D")

    static let tiles: [(Color, Color)] = [(sky, skyDeep), (candy, candyDeep), (grass, grassDeep),
                                          (orange, orangeDeep), (grape, grapeDeep), (sun, sunDeep)]
    static func tile(_ i: Int) -> (Color, Color) { tiles[((i % tiles.count) + tiles.count) % tiles.count] }
}

// MARK: - Nuage

/// Nuage dodu : un socle arrondi surmonté de bosses.
struct CloudShape: Shape {
    var bumps: Int = 0
    var seed: UInt64 = 3
    /// Hauteur des bosses (fraction de la hauteur totale).
    var crown: CGFloat = 0.42

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        let baseTop = rect.minY + h * crown
        p.addRoundedRect(in: CGRect(x: rect.minX, y: baseTop, width: w, height: rect.maxY - baseTop),
                         cornerSize: CGSize(width: (rect.maxY - baseTop) * 0.5, height: (rect.maxY - baseTop) * 0.5))
        let n = bumps > 0 ? bumps : max(3, Int((w / max(1, h * crown / 0.42)) * 1.6))
        var rng = SeededRandom(seed: seed)
        for i in 0..<n {
            let t = (CGFloat(i) + 0.5) / CGFloat(n)
            let middle = 1 - abs(t - 0.5) * 1.2
            let r = h * (crown / 0.42) * (0.22 + 0.2 * middle + rng.next() * 0.06)
            let cx = rect.minX + w * (0.1 + 0.8 * t)
            let cy = baseTop + h * 0.1 - r * 0.35
            p.addEllipse(in: CGRect(x: cx - r, y: cy - r * 0.55, width: r * 2, height: r * 1.7))
        }
        return p
    }
}

/// Le nuage dessiné : blanc nacré, ombre douce.
struct FluffyCloud: View {
    var tint: Color = .white
    var bumps: Int = 0
    var seed: UInt64 = 3
    var crown: CGFloat = 0.42
    var body: some View {
        CloudShape(bumps: bumps, seed: seed, crown: crown)
            .fill(LinearGradient(colors: [tint, tint.opacity(0.92), Color(hex: "#DDEFFF")],
                                 startPoint: .top, endPoint: .bottom))
            .shadow(color: Color(hex: "#2A6FB8").opacity(0.18), radius: 14, y: 8)
    }
}

// MARK: - Mascotte

/// Bob, le petit nuage de bobprompt.
struct Mascot: View {
    enum Mood { case happy, cheer, curious }
    var mood: Mood = .happy
    var size: CGFloat = 110

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            let blink = t.truncatingRemainder(dividingBy: 3.7) < 0.13
            let bob = sin(t * 2.1) * size * 0.035
            ZStack {
                FluffyCloud(bumps: 3, seed: 9)
                face(blink: blink)
                    .offset(y: size * 0.14)
            }
            .frame(width: size, height: size * 0.72)
            .offset(y: bob - (mood == .cheer ? abs(sin(t * 9)) * size * 0.06 : 0))
            .rotationEffect(.degrees(mood == .cheer ? sin(t * 9) * 6 : sin(t * 1.3) * 2))
        }
        .frame(width: size, height: size * 0.85)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func face(blink: Bool) -> some View {
        let eyeW = size * 0.075, eyeH = size * 0.12, gap = size * 0.2
        ZStack {
            HStack(spacing: gap) {
                eye(w: eyeW, h: eyeH, blink: blink)
                eye(w: eyeW, h: eyeH, blink: blink)
            }
            .offset(y: -size * 0.04)
            HStack(spacing: gap * 1.9) {
                Circle().fill(KidsPalette.candy.opacity(0.45)).frame(width: size * 0.1)
                Circle().fill(KidsPalette.candy.opacity(0.45)).frame(width: size * 0.1)
            }
            .offset(y: size * 0.05)
            mouth
                .offset(y: size * 0.08)
        }
    }

    @ViewBuilder
    private func eye(w: CGFloat, h: CGFloat, blink: Bool) -> some View {
        if mood == .cheer {
            Path { p in
                p.move(to: CGPoint(x: 0, y: h * 0.6))
                p.addQuadCurve(to: CGPoint(x: w * 1.6, y: h * 0.6), control: CGPoint(x: w * 0.8, y: -h * 0.2))
            }
            .stroke(KidsPalette.ink, style: StrokeStyle(lineWidth: w * 0.45, lineCap: .round))
            .frame(width: w * 1.6, height: h)
        } else {
            Capsule()
                .fill(KidsPalette.ink)
                .overlay(Circle().fill(.white).frame(width: w * 0.42).offset(x: w * 0.12, y: -h * 0.18))
                .frame(width: w, height: blink ? h * 0.12 : h)
        }
    }

    private var mouth: some View {
        let w = size * (mood == .cheer ? 0.2 : 0.14)
        return Path { p in
            p.move(to: .zero)
            p.addQuadCurve(to: CGPoint(x: w, y: 0), control: CGPoint(x: w / 2, y: w * (mood == .curious ? 0.25 : 0.75)))
            if mood == .cheer { p.closeSubpath() }
        }
        .fill(mood == .cheer ? KidsPalette.candyDeep : .clear)
        .overlay(
            Path { p in
                p.move(to: .zero)
                p.addQuadCurve(to: CGPoint(x: w, y: 0), control: CGPoint(x: w / 2, y: w * (mood == .curious ? 0.25 : 0.75)))
            }
            .stroke(KidsPalette.ink, style: StrokeStyle(lineWidth: size * 0.025, lineCap: .round))
        )
        .frame(width: w, height: w * 0.5)
    }
}

/// Bulle de dialogue de la mascotte.
struct SpeechBubble: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .foregroundStyle(KidsPalette.ink)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.white)
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
            )
            .overlay(alignment: .bottomLeading) {
                Triangle().fill(.white).frame(width: 18, height: 12).rotationEffect(.degrees(180)).offset(x: 22, y: 10)
            }
    }
}

struct Triangle: Shape {
    func path(in r: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: r.midX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
            p.closeSubpath()
        }
    }
}

// MARK: - Ciel animé

struct SkyBackground: View {
    var night = false
    var hills = true

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            GeometryReader { g in
                let size = g.size
                ZStack {
                    LinearGradient(colors: night ? [Color(hex: "#151A45"), Color(hex: "#2C2A6E"), Color(hex: "#3F3A86")]
                                                  : [Color(hex: "#5BBEFF"), Color(hex: "#A9DFFF"), Color(hex: "#E6F6FF")],
                                   startPoint: .top, endPoint: .bottom)
                    if night { stars(size: size, t: t) }
                    sun(t: t)
                        .position(x: size.width * 0.84, y: min(110, size.height * 0.14))
                    ForEach(0..<4, id: \.self) { i in
                        let speed = 8.0 + Double(i) * 5
                        let w = CGFloat(120 + i * 40)
                        let span = size.width + w * 2
                        let x = CGFloat((t * speed + Double(i) * 230).truncatingRemainder(dividingBy: Double(span))) - w
                        FluffyCloud(tint: night ? Color(hex: "#B8BEE8") : .white, seed: UInt64(i + 1))
                            .frame(width: w, height: w * 0.45)
                            .opacity(night ? 0.25 : (0.55 + Double(i % 2) * 0.3))
                            .position(x: x, y: size.height * (0.12 + CGFloat(i) * 0.09))
                    }
                    if hills {
                        Ellipse().fill(night ? Color(hex: "#2F4F6B") : Color(hex: "#86DC6A"))
                            .frame(width: size.width * 1.4, height: size.height * 0.34)
                            .position(x: size.width * 0.15, y: size.height * 1.02)
                        Ellipse().fill(night ? Color(hex: "#24425C") : Color(hex: "#5CC64A"))
                            .frame(width: size.width * 1.3, height: size.height * 0.3)
                            .position(x: size.width * 0.95, y: size.height * 1.05)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func sun(t: Double) -> some View {
        if night {
            Circle().fill(Color(hex: "#FFF6CF"))
                .frame(width: 58)
                .overlay(Circle().fill(Color(hex: "#2C2A6E")).frame(width: 50).offset(x: 16, y: -10))
                .shadow(color: .white.opacity(0.4), radius: 18)
        } else {
            ZStack {
                ForEach(0..<12, id: \.self) { k in
                    Capsule().fill(KidsPalette.sun.opacity(0.7))
                        .frame(width: 6, height: 22)
                        .offset(y: -54)
                        .rotationEffect(.degrees(Double(k) * 30 + t * 12))
                }
                Circle().fill(RadialGradient(colors: [Color(hex: "#FFF1A8"), KidsPalette.sun], center: .center,
                                             startRadius: 2, endRadius: 40))
                    .frame(width: 76)
                    .shadow(color: KidsPalette.sun.opacity(0.7), radius: 20)
            }
        }
    }

    private func stars(size: CGSize, t: Double) -> some View {
        Canvas { ctx, s in
            var rng = SeededRandom(seed: 21)
            for i in 0..<60 {
                let x = rng.next() * s.width, y = rng.next() * s.height * 0.7
                let r = 0.8 + rng.next() * 1.8
                let tw = 0.45 + 0.55 * abs(sin(t * (0.6 + Double(i % 7) * 0.2) + Double(i)))
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)),
                         with: .color(.white.opacity(tw)))
            }
        }
    }
}

// MARK: - Boutons bonbon

/// Gros bouton en relief, façon bonbon.
struct CandyButtonStyle: ButtonStyle {
    var color: Color
    var deep: Color
    var cornerRadius: CGFloat = 22
    var height: CGFloat? = nil

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .font(.system(size: 18, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .shadow(color: deep.opacity(0.5), radius: 0, y: 1.5)
            .padding(.horizontal, 18)
            .frame(minHeight: height ?? 54)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(deep)
                        .offset(y: pressed ? 2 : 6)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(LinearGradient(colors: [color.opacity(0.92), color], startPoint: .top, endPoint: .bottom))
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(.white.opacity(0.35), lineWidth: 2)
                        .padding(2)
                }
            )
            .offset(y: pressed ? 4 : 0)
            .padding(.bottom, 6)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: pressed)
    }
}

/// Compteur d'étoiles.
struct StarCounter: View {
    let stars: Int
    var compact = false
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "star.fill")
                .foregroundStyle(KidsPalette.sun)
                .shadow(color: KidsPalette.sunDeep.opacity(0.6), radius: 0, y: 1)
            Text("\(stars)")
                .contentTransition(.numericText())
                .monospacedDigit()
        }
        .font(.system(size: compact ? 16 : 20, weight: .heavy, design: .rounded))
        .foregroundStyle(KidsPalette.ink)
        .padding(.horizontal, compact ? 12 : 16)
        .padding(.vertical, compact ? 7 : 9)
        .background(Capsule().fill(.white).shadow(color: .black.opacity(0.1), radius: 6, y: 3))
        .animation(.spring(response: 0.4), value: stars)
        .accessibilityLabel("\(stars) étoiles")
    }
}

/// Barre de progression vers le niveau suivant.
struct LevelBar: View {
    let progress: Double
    var color: Color = KidsPalette.grass
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.6))
                Capsule().fill(LinearGradient(colors: [color.opacity(0.85), color], startPoint: .top, endPoint: .bottom))
                    .frame(width: max(14, g.size.width * progress))
            }
        }
        .frame(height: 14)
    }
}

/// Une salve d'étoiles qui s'envolent (récompense).
struct StarBurst: View {
    @State private var go = false
    var count = 10
    var radius: CGFloat = 120
    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { i in
                let a = Double(i) / Double(count) * 2 * .pi
                Image(systemName: i % 2 == 0 ? "star.fill" : "sparkle")
                    .font(.system(size: CGFloat(14 + (i % 3) * 7)))
                    .foregroundStyle(i % 3 == 0 ? KidsPalette.candy : KidsPalette.sun)
                    .offset(x: go ? cos(a) * radius : 0, y: go ? sin(a) * radius : 0)
                    .scaleEffect(go ? 1.2 : 0.2)
                    .opacity(go ? 0 : 1)
            }
        }
        .onAppear { withAnimation(.easeOut(duration: 1.0)) { go = true } }
        .allowsHitTesting(false)
    }
}
