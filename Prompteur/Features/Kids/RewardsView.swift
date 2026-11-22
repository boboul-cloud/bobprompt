import SwiftUI

/// Mes récompenses : niveau, chemin des niveaux, badges.
struct RewardsView: View {
    @Environment(RewardStore.self) private var rewards
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    private let columns = [GridItem(.adaptive(minimum: 104, maximum: 160), spacing: 12)]

    var body: some View {
        ZStack {
            SkyBackground(night: scheme == .dark, hills: false)
            ScrollView {
                VStack(spacing: 20) {
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .heavy))
                                .foregroundStyle(KidsPalette.skyDeep)
                                .frame(width: 46, height: 46)
                                .background(Circle().fill(.white))
                        }
                        .accessibilityLabel("Retour")
                        Spacer()
                        StarCounter(stars: rewards.stars)
                    }
                    .padding(.top, 8)

                    levelHero
                    levelPath
                    stats

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Mes badges · \(rewards.unlockedCount)/\(RewardStore.badges.count)")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(KidsPalette.ink)
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(RewardStore.badges) { b in BadgeCell(badge: b, date: rewards.unlockedDate(b)) }
                        }
                    }
                    .padding(18)
                    .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(.white.opacity(0.95)))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var levelHero: some View {
        VStack(spacing: 8) {
            Text(rewards.level.emoji).font(.system(size: 72))
            Text(rewards.level.name)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(KidsPalette.ink)
            LevelBar(progress: rewards.levelProgress, color: KidsPalette.sun)
                .background(Capsule().fill(Color(hex: "#E7EEF8")))
                .frame(maxWidth: 300)
            Text(rewards.nextLevel.map { "Encore \($0.threshold - rewards.stars) ⭐ pour : \($0.emoji) \($0.name)" }
                 ?? "Tu as atteint le plus haut niveau !")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(KidsPalette.ink.opacity(0.65))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(.white.opacity(0.95)))
    }

    private var levelPath: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(RewardStore.levels.enumerated()), id: \.offset) { i, l in
                    let reached = rewards.stars >= l.threshold
                    if i > 0 {
                        Capsule().fill(reached ? KidsPalette.sun : .white.opacity(0.5)).frame(width: 22, height: 6)
                    }
                    VStack(spacing: 4) {
                        Text(l.emoji)
                            .font(.system(size: 28))
                            .frame(width: 56, height: 56)
                            .background(Circle().fill(reached ? .white : .white.opacity(0.4)))
                            .overlay(Circle().strokeBorder(l == rewards.level ? KidsPalette.sun : .clear, lineWidth: 4))
                            .grayscale(reached ? 0 : 1)
                        Text("\(l.threshold) ⭐")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private var stats: some View {
        HStack(spacing: 10) {
            stat("📖", "\(rewards.finishedTexts)", rewards.finishedTexts > 1 ? "histoires finies" : "histoire finie")
            stat("✏️", "\(rewards.sentencesRead)", "phrases lues")
            stat("🔥", "\(rewards.streak)", rewards.streak > 1 ? "jours de suite" : "jour de suite")
        }
    }

    private func stat(_ emoji: String, _ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(emoji).font(.system(size: 24))
            Text(value).font(.system(size: 24, weight: .black, design: .rounded)).foregroundStyle(KidsPalette.ink)
            Text(label).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(KidsPalette.ink.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.95)))
    }
}

struct BadgeCell: View {
    let badge: RewardStore.Badge
    let date: Date?

    var body: some View {
        let unlocked = date != nil
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(unlocked ? LinearGradient(colors: [Color(hex: "#FFE36B"), KidsPalette.sun], startPoint: .top, endPoint: .bottom)
                                   : LinearGradient(colors: [Color(hex: "#E7ECF3"), Color(hex: "#D5DDE8")], startPoint: .top, endPoint: .bottom))
                    .frame(width: 66, height: 66)
                if unlocked {
                    Text(badge.emoji).font(.system(size: 34))
                } else {
                    Image(systemName: "lock.fill").font(.system(size: 22, weight: .bold)).foregroundStyle(Color(hex: "#9AA6B8"))
                }
            }
            Text(badge.title)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(KidsPalette.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text(unlocked ? (date.map { Format.shortDate.string(from: $0) } ?? "") : badge.detail)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(KidsPalette.ink.opacity(0.55))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(unlocked ? "Badge obtenu : \(badge.title)" : "Badge à gagner : \(badge.title), \(badge.detail)")
    }
}
