import SwiftUI

/// Le coin lecture : les histoires, le niveau, les étoiles.
struct KidsHomeView: View {
    @Environment(AppRouter.self) private var router
    @Environment(ScriptStore.self) private var store
    @Environment(RewardStore.self) private var rewards
    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    private let columns = [GridItem(.adaptive(minimum: 158, maximum: 240), spacing: 14)]

    /// Exemples adaptés aux enfants, puis les textes de la bibliothèque.
    private var stories: [Script] {
        [SampleScripts.dragon, SampleScripts.corbeau, SampleScripts.herisson, SampleScripts.cigale] + store.scripts
    }

    var body: some View {
        ZStack {
            SkyBackground(night: scheme == .dark)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    levelCard
                    actions
                    Text("Mes histoires")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: KidsPalette.skyDeep.opacity(0.7), radius: 0, y: 2)
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(Array(stories.enumerated()), id: \.element.id) { i, s in
                            StoryTile(script: s, index: i, stars: rewards.starsFor(s.id),
                                      wordsPerMinute: settings.kids.wordsPerMinute) {
                                router.read(s, profile: .kids)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
                .frame(maxWidth: 820)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "house.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(KidsPalette.skyDeep)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(.white).shadow(color: .black.opacity(0.1), radius: 5, y: 3))
            }
            .accessibilityLabel("Accueil")
            Spacer()
            StarCounter(stars: rewards.stars)
        }
        .padding(.top, 8)
    }

    private var levelCard: some View {
        Button { router.open(.rewards) } label: {
            HStack(spacing: 14) {
                Mascot(mood: .happy, size: 84)
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(rewards.level.emoji) \(rewards.level.name)")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(KidsPalette.ink)
                    LevelBar(progress: rewards.levelProgress)
                    if let next = rewards.nextLevel {
                        Text("Encore \(next.threshold - rewards.stars) ⭐ pour devenir « \(next.name) »")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(KidsPalette.ink.opacity(0.7))
                    }
                    if rewards.streak > 1 {
                        Text("🔥 \(rewards.streak) jours de suite !")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(KidsPalette.orangeDeep)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 15, weight: .heavy)).foregroundStyle(KidsPalette.ink.opacity(0.4))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous).fill(.white.opacity(0.95))
                    .shadow(color: Color(hex: "#2A6FB8").opacity(0.2), radius: 14, y: 6)
            )
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Mon niveau : \(rewards.level.name). Voir mes badges")
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button { router.open(.rewards) } label: { Label("Badges", systemImage: "trophy.fill") }
                .buttonStyle(CandyButtonStyle(color: KidsPalette.candy, deep: KidsPalette.candyDeep))
            Button { router.sheet = .create(.kids) } label: { Label("Inventer", systemImage: "sparkles") }
                .buttonStyle(CandyButtonStyle(color: KidsPalette.grape, deep: KidsPalette.grapeDeep))
            Button { _ = router.newScript(in: store, profile: .kids) } label: { Label("Écrire", systemImage: "pencil") }
                .buttonStyle(CandyButtonStyle(color: KidsPalette.grass, deep: KidsPalette.grassDeep))
        }
        .font(.system(size: 16, weight: .heavy, design: .rounded))
        .labelStyle(StackedLabelStyle())
    }
}

/// Icône au-dessus du texte (boutons des enfants).
struct StackedLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 3) {
            configuration.icon.font(.system(size: 20, weight: .heavy))
            configuration.title.font(.system(size: 14, weight: .heavy, design: .rounded))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }
}

/// Une histoire : tuile bonbon, ses étoiles gagnées.
struct StoryTile: View {
    let script: Script
    let index: Int
    let stars: Int
    let wordsPerMinute: Double
    let action: () -> Void

    var body: some View {
        let (color, deep) = KidsPalette.tile(index)
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: script.symbol ?? "book.fill")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(color)
                        .frame(width: 46, height: 46)
                        .background(Circle().fill(.white))
                    Spacer()
                    HStack(spacing: 1) {
                        ForEach(0..<3, id: \.self) { i in
                            Image(systemName: "star.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(i < stars ? KidsPalette.sun : .white.opacity(0.35))
                        }
                    }
                }
                Spacer(minLength: 0)
                Text(script.displayTitle)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .shadow(color: deep.opacity(0.6), radius: 0, y: 2)
                Text("⏱ \(Format.duration(Double(script.wordCount) / max(1, wordsPerMinute) * 60))")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(14)
            .frame(height: 178)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 26, style: .continuous).fill(deep).offset(y: 6)
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(LinearGradient(colors: [color.opacity(0.88), color], startPoint: .top, endPoint: .bottom))
                    RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.35), lineWidth: 2.5).padding(2)
                }
            )
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(script.displayTitle), \(stars) étoiles sur 3")
    }
}
