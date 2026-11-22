import SwiftUI

/// Commandes du lecteur pour les enfants : grosses, colorées, sans chiffres.
struct KidsControlBar: View {
    @Environment(SettingsStore.self) private var store
    let engine: PrompterEngine
    let onSettings: () -> Void
    let onStyles: () -> Void
    let onInteract: () -> Void

    var body: some View {
        let s = store.kids
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(ReaderSettings.kidsPaces) { pace in
                    let on = abs(s.wordsPerMinute - pace.wpm) < 0.5
                    Button {
                        withAnimation(.spring(response: 0.3)) { store.kids.wordsPerMinute = pace.wpm }
                        Haptics.tick()
                        onInteract()
                    } label: {
                        VStack(spacing: 0) {
                            Text(pace.emoji).font(.system(size: on ? 30 : 24))
                            Text(pace.name).font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundStyle(on ? KidsPalette.ink : KidsPalette.ink.opacity(0.55))
                        }
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(on ? KidsPalette.sun.opacity(0.9) : Color(hex: "#EEF5FF"))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(on ? KidsPalette.sunDeep : .clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("Allure \(pace.name)")
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }

            HStack(spacing: 10) {
                round("arrow.counterclockwise", KidsPalette.grape, KidsPalette.grapeDeep, "Recommencer") {
                    engine.restart()
                }
                round("backward.fill", KidsPalette.sky, KidsPalette.skyDeep, "Phrase d'avant") {
                    engine.jumpSentence(-1)
                }
                bigPlay
                round("arrow.right", KidsPalette.grass, KidsPalette.grassDeep, "Mot suivant") {
                    engine.jumpWord(1)
                }
                round("ear.fill", KidsPalette.candy, KidsPalette.candyDeep, "Écouter la phrase") {
                    engine.readSentenceAloud()
                }
            }

            HStack(spacing: 8) {
                chip(s.voiceOn ? "🗣️ La voix lit" : "🤫 Je lis seul", on: s.voiceOn) {
                    store.kids.voiceOn.toggle()
                }
                chip("🎨 Style", on: false, action: onStyles)
                chip("⚙️ Parents", on: false, action: onSettings)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.white.opacity(0.92))
                .shadow(color: Color(hex: "#2A6FB8").opacity(0.25), radius: 18, y: 8)
        )
        .frame(maxWidth: 560)
    }

    private var bigPlay: some View {
        let playing = engine.isPlaying
        return Button {
            engine.toggle(countdown: store.kids.countdown)
            Haptics.thump()
            onInteract()
        } label: {
            Image(systemName: playing ? "pause.fill" : "play.fill")
                .font(.system(size: 32, weight: .black))
                .foregroundStyle(KidsPalette.ink)
                .offset(x: playing ? 0 : 3)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 80, height: 80)
                .background(
                    ZStack {
                        Circle().fill(KidsPalette.sunDeep).offset(y: 5)
                        Circle().fill(LinearGradient(colors: [Color(hex: "#FFE36B"), KidsPalette.sun],
                                                     startPoint: .top, endPoint: .bottom))
                        Circle().strokeBorder(.white.opacity(0.5), lineWidth: 3).padding(3)
                    }
                )
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(playing ? "Pause" : "Lecture")
    }

    private func round(_ symbol: String, _ color: Color, _ deep: Color, _ label: String,
                       action: @escaping () -> Void) -> some View {
        Button {
            action()
            Haptics.tap()
            onInteract()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
                .background(
                    ZStack {
                        Circle().fill(deep).offset(y: 4)
                        Circle().fill(color)
                    }
                )
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(label)
    }

    private func chip(_ text: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            Haptics.tick()
            onInteract()
        } label: {
            Text(text)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(KidsPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(Capsule().fill(on ? KidsPalette.grass.opacity(0.35) : Color(hex: "#EEF5FF")))
        }
        .buttonStyle(PressableStyle())
    }
}

/// « +1 ⭐ », nouveau badge, nouveau niveau.
struct RewardBanner: View {
    let gain: RewardStore.Gain

    var body: some View {
        Group {
            if let badge = gain.badges.first {
                card(emoji: badge.emoji, kicker: "Nouveau badge !", title: badge.title)
            } else if let level = gain.newLevel {
                card(emoji: level.emoji, kicker: "Nouveau niveau !", title: level.name)
            } else {
                HStack(spacing: 6) {
                    Text("+\(gain.stars)")
                    Image(systemName: "star.fill").foregroundStyle(KidsPalette.sun)
                    if gain.stars > 1 { Text("Bonus du jour !").font(.system(size: 15, weight: .heavy, design: .rounded)) }
                }
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(KidsPalette.ink)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Capsule().fill(.white).shadow(color: .black.opacity(0.15), radius: 10, y: 5))
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func card(emoji: String, kicker: String, title: String) -> some View {
        HStack(spacing: 14) {
            Text(emoji).font(.system(size: 44))
            VStack(alignment: .leading, spacing: 2) {
                Text(kicker).font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundStyle(KidsPalette.candyDeep)
                Text(title).font(.system(size: 21, weight: .black, design: .rounded)).foregroundStyle(KidsPalette.ink)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous).fill(.white)
                .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
        )
        .overlay(StarBurst(count: 12, radius: 150))
    }
}

/// Fin de lecture des enfants : Bob fait la fête, les étoiles tombent.
struct KidsFinishView: View {
    let stars: Int
    let badges: [RewardStore.Badge]
    let total: Int
    let onReplay: () -> Void
    let onClose: () -> Void
    @State private var shown = 0

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            LinearGradient(colors: [Color(hex: "#3C8DEB").opacity(0.92), Color(hex: "#7A5CF0").opacity(0.92)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            StarBurst(count: 18, radius: 220)
            VStack(spacing: 16) {
                Mascot(mood: .cheer, size: 130)
                Text("Bravo !")
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: KidsPalette.candyDeep.opacity(0.6), radius: 0, y: 4)
                HStack(spacing: 14) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: "star.fill")
                            .font(.system(size: i == 1 ? 64 : 50))
                            .foregroundStyle(KidsPalette.sun)
                            .shadow(color: KidsPalette.sunDeep, radius: 0, y: 4)
                            .scaleEffect(shown > i ? 1 : 0.1)
                            .opacity(shown > i ? 1 : 0)
                            .offset(y: i == 1 ? -10 : 0)
                    }
                }
                Text(stars > 0 ? "Tu as gagné \(stars) étoiles !" : "Tu as lu toute l'histoire !")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                ForEach(badges) { b in
                    HStack(spacing: 10) {
                        Text(b.emoji).font(.system(size: 30))
                        Text("Badge « \(b.title) »").font(.system(size: 17, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(KidsPalette.ink)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(.white))
                }
                HStack(spacing: 12) {
                    Button(action: onReplay) { Label("Encore !", systemImage: "arrow.counterclockwise") }
                        .buttonStyle(CandyButtonStyle(color: KidsPalette.grass, deep: KidsPalette.grassDeep))
                    Button(action: onClose) { Label("Fini", systemImage: "house.fill") }
                        .buttonStyle(CandyButtonStyle(color: KidsPalette.sky, deep: KidsPalette.skyDeep))
                }
                .padding(.top, 8)
            }
            .padding(24)
        }
        .onAppear {
            for i in 1...3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25 + Double(i) * 0.3) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.45)) { shown = i }
                    Haptics.tap()
                }
            }
        }
    }
}
