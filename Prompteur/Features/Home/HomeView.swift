import SwiftUI

/// Page d'accueil : Bob salue, deux portes — le coin lecture et le studio.
struct HomeView: View {
    @Environment(AppRouter.self) private var router
    @Environment(RewardStore.self) private var rewards
    @Environment(PurchaseManager.self) private var purchases
    @Environment(\.colorScheme) private var scheme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var appeared = false

    /// iPad : portes côte à côte, contenu centré dans la hauteur.
    private var wide: Bool { sizeClass == .regular }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                SkyBackground(night: scheme == .dark)
                ScrollView {
                    VStack(spacing: wide ? 28 : 18) {
                        topBar
                        if wide { Spacer(minLength: 0) }
                        hero
                        if wide {
                            HStack(alignment: .top, spacing: 20) {
                                kidsDoor.modifier(Appear(on: appeared, delay: 0.1))
                                studioDoor.modifier(Appear(on: appeared, delay: 0.2))
                            }
                            .fixedSize(horizontal: false, vertical: true)
                        } else {
                            kidsDoor.modifier(Appear(on: appeared, delay: 0.1))
                            studioDoor.modifier(Appear(on: appeared, delay: 0.2))
                        }
                        footer
                            .frame(maxWidth: wide ? 520 : .infinity)
                            .modifier(Appear(on: appeared, delay: 0.3))
                        if wide { Spacer(minLength: 0) }
                    }
                    .padding(.horizontal, wide ? 40 : 20)
                    .padding(.bottom, 40)
                    .frame(maxWidth: wide ? 1040 : 620)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: wide ? geo.size.height - 20 : nil)
                }
                .scrollIndicators(.hidden)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) { appeared = true } }
    }

    // MARK: Haut

    private var topBar: some View {
        HStack {
            Wordmark(size: 30)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(Palette.surface.opacity(0.85)))
            Spacer()
            circleButton("questionmark", label: "Mode d'emploi") { router.sheet = .help }
            circleButton(purchases.isPremium ? "crown.fill" : "crown", label: "Premium") { router.sheet = .premium }
        }
        .padding(.top, 8)
    }

    private func circleButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Palette.ink)
                .frame(width: 42, height: 42)
                .background(Circle().fill(Palette.surface.opacity(0.9)))
        }
        .accessibilityLabel(label)
    }

    private var hero: some View {
        HStack(alignment: .bottom, spacing: 4) {
            Mascot(mood: appeared ? .happy : .curious, size: wide ? 190 : 128)
            SpeechBubble(text: "\(greeting)\nJe suis Bob. On lit ensemble ?")
                .scaleEffect(wide ? 1.3 : 1, anchor: .bottomLeading)
                .padding(.bottom, wide ? 96 : 58)
        }
        .frame(maxWidth: .infinity, alignment: wide ? .center : .leading)
        .padding(.top, 6)
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return "Bonjour !"
        case 12..<18: return "Bon après-midi !"
        case 18..<22: return "Bonsoir !"
        default: return "Une petite histoire avant de dormir ?"
        }
    }

    // MARK: Portes

    private var kidsDoor: some View {
        Button { router.open(.kids) } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 6) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("COIN LECTURE")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .tracking(1.5)
                            .foregroundStyle(.white.opacity(0.9))
                        Text("Lire en\ns'amusant !")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: KidsPalette.orangeDeep.opacity(0.6), radius: 0, y: 3)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Les mots tombent du ciel, on gagne des étoiles.")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.92))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    FallingLetters()
                        .frame(width: 112, height: 150)
                }
                HStack(spacing: 8) {
                    StarCounter(stars: rewards.stars, compact: true)
                    Text("\(rewards.level.emoji) \(rewards.level.name)")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(KidsPalette.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(.white.opacity(0.85)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(22)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 34, style: .continuous).fill(KidsPalette.orangeDeep).offset(y: 7)
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .fill(LinearGradient(colors: [Color(hex: "#FFC93C"), KidsPalette.orange],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .strokeBorder(.white.opacity(0.4), lineWidth: 3).padding(3)
                }
            )
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Coin lecture : lire en s'amusant")
    }

    private var studioDoor: some View {
        Button { router.open(.studio) } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("STUDIO")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(Palette.onAir)
                    Text("Prompteur")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Présenter, filmer, répéter. Vieille école, 3D, miroir.")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                MiniPrompter()
                    .frame(width: 104, height: 92)
            }
            .padding(22)
            .frame(maxHeight: wide ? .infinity : nil)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 30, style: .continuous).fill(Color(hex: "#0B0D1A")).offset(y: 6)
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(LinearGradient(colors: [Color(hex: "#1D2347"), Color(hex: "#2E1F4F")],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            )
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Studio prompteur")
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button { router.sheet = .create(.kids) } label: {
                Label("Inventer", systemImage: "sparkles").frame(maxWidth: .infinity)
            }
            .buttonStyle(CandyButtonStyle(color: KidsPalette.grape, deep: KidsPalette.grapeDeep, height: 50))
            Button { router.open(.rewards) } label: {
                Label("Badges", systemImage: "trophy.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(CandyButtonStyle(color: KidsPalette.candy, deep: KidsPalette.candyDeep, height: 50))
        }
        .font(.system(size: 16, weight: .heavy, design: .rounded))
    }
}

/// Apparition échelonnée des éléments.
struct Appear: ViewModifier {
    let on: Bool
    let delay: Double
    func body(content: Content) -> some View {
        content
            .opacity(on ? 1 : 0)
            .offset(y: on ? 0 : 30)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(delay), value: on)
    }
}

/// Lettres colorées qui tombent en boucle (illustration de la porte « Coin lecture »).
struct FallingLetters: View {
    private let letters: [(String, Color)] = [("A", KidsPalette.candy), ("b", KidsPalette.sky),
                                               ("c", KidsPalette.grass), ("é", KidsPalette.grape)]
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            GeometryReader { g in
                ZStack {
                    FluffyCloud(seed: 4)
                        .frame(width: g.size.width, height: g.size.width * 0.42)
                        .position(x: g.size.width / 2, y: g.size.height - g.size.width * 0.18)
                    ForEach(letters.indices, id: \.self) { i in
                        let period = 2.6
                        let phase = (t / period + Double(i) * 0.25).truncatingRemainder(dividingBy: 1)
                        let fall = min(1, phase / 0.6)
                        let y = 14 + (g.size.height - g.size.width * 0.26 - 14) * CGFloat(SkyStage.bounce(fall))
                        Text(letters[i].0)
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(letters[i].1))
                            .overlay(Circle().strokeBorder(.white, lineWidth: 2.5))
                            .rotationEffect(.degrees((1 - fall) * 30 * (i % 2 == 0 ? 1 : -1)))
                            .opacity(phase > 0.9 ? (1 - phase) * 10 : min(1, phase * 12))
                            .position(x: g.size.width * (0.18 + CGFloat(i) * 0.22), y: y)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Petit prompteur (illustration de la porte « Studio »).
struct MiniPrompter: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14).fill(Color(hex: "#05060C"))
            VStack(spacing: 7) {
                Capsule().fill(.white.opacity(0.25)).frame(width: 56, height: 5)
                HStack(spacing: 5) {
                    Image(systemName: "arrowtriangle.right.fill").font(.system(size: 7)).foregroundStyle(Palette.onAir)
                    Capsule().fill(.white).frame(width: 62, height: 6)
                    Image(systemName: "arrowtriangle.left.fill").font(.system(size: 7)).foregroundStyle(Palette.onAir)
                }
                Capsule().fill(.white.opacity(0.6)).frame(width: 50, height: 5)
                Capsule().fill(.white.opacity(0.35)).frame(width: 40, height: 5)
            }
            VStack {
                HStack {
                    Spacer()
                    Circle().fill(Palette.onAir).frame(width: 9, height: 9)
                        .shadow(color: Palette.onAir, radius: 5)
                        .padding(8)
                }
                Spacer()
            }
        }
        .rotation3DEffect(.degrees(-14), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
        .accessibilityHidden(true)
    }
}
