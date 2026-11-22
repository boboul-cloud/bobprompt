import SwiftUI

/// Accueil : mes textes, exemples, création.
struct LibraryView: View {
    @Environment(ScriptStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @Environment(AppRouter.self) private var router
    @Environment(PurchaseManager.self) private var purchases
    @State private var pendingDelete: Script?

    private let columns = [GridItem(.adaptive(minimum: 300, maximum: 520), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                actions
                myScripts
                samples
                if !purchases.isPremium { premiumCard }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .bottom) { toast }
        .confirmationDialog("Supprimer « \(pendingDelete?.displayTitle ?? "") » ?",
                            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                            titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) {
                if let s = pendingDelete { withAnimation(.snappy) { store.delete(s.id) } }
                pendingDelete = nil
            }
        } message: {
            Text("Ce texte sera effacé définitivement.")
        }
    }

    // MARK: En-tête

    private var header: some View {
        HStack(alignment: .center) {
            Wordmark(size: 32)
            Spacer()
            Button { router.sheet = .help } label: {
                Image(systemName: "questionmark")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Palette.surface))
                    .overlay(Circle().strokeBorder(Palette.hairline))
            }
            .foregroundStyle(Palette.ink)
            .accessibilityLabel("Mode d'emploi")

            Button { router.sheet = .premium } label: {
                Image(systemName: purchases.isPremium ? "crown.fill" : "crown")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(purchases.isPremium ? Palette.sun : Palette.surface))
                    .overlay(Circle().strokeBorder(Palette.hairline))
            }
            .foregroundStyle(purchases.isPremium ? .white : Palette.ink)
            .accessibilityLabel(purchases.isPremium ? "Premium actif" : "Passer Premium")
        }
        .padding(.top, 6)
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Qu'est-ce qu'on lit\naujourd'hui ?")
                .font(Typo.title(32))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button {
                    _ = router.newScript(in: store)
                } label: {
                    Label("Nouveau texte", systemImage: "square.and.pencil")
                }
                .buttonStyle(PrimaryButtonStyle())

                Button { router.sheet = .create } label: {
                    Label("Avec l'IA", systemImage: "sparkles")
                }
                .buttonStyle(SoftButtonStyle(tint: Palette.indigo))
            }
        }
    }

    // MARK: Mes textes

    private var myScripts: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Mes textes").font(Typo.headline(20)).foregroundStyle(Palette.ink)
                Spacer()
                Tag(text: purchases.isPremium ? "\(store.scripts.count)/\(store.limit)"
                                              : "\(store.scripts.count)/\(store.limit) gratuits",
                    tint: store.canCreate ? Palette.inkSoft : Palette.onAir)
            }
            if store.scripts.isEmpty {
                emptyMine
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(store.scripts) { s in
                        ScriptCard(script: s, wordsPerMinute: settings.reader.wordsPerMinute,
                                   onRead: { router.read(s) },
                                   onEdit: { router.edit(s.id) },
                                   onDuplicate: { duplicate(s) },
                                   onDelete: { pendingDelete = s })
                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                    }
                }
            }
        }
    }

    private var emptyMine: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Palette.onAir)
            Text("Aucun texte pour l'instant")
                .font(Typo.headline(17))
                .foregroundStyle(Palette.ink)
            Text("Écris ou colle ton texte, ou commence par un exemple ci-dessous.")
                .font(Typo.body(14))
                .foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(26)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
                .foregroundStyle(Palette.hairline)
        )
    }

    // MARK: Exemples

    private var samples: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exemples").font(Typo.headline(20)).foregroundStyle(Palette.ink)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(SampleScripts.all) { s in
                        SampleCard(script: s, wordsPerMinute: settings.reader.wordsPerMinute) { router.read(s) }
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 20)
            }
            .padding(.horizontal, -20)
        }
    }

    private var premiumCard: some View {
        Button { router.sheet = .premium } label: {
            HStack(spacing: 14) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Palette.sun))
                VStack(alignment: .leading, spacing: 3) {
                    Text("bobprompt Premium").font(Typo.headline(16)).foregroundStyle(Palette.ink)
                    Text("Jusqu'à \(ScriptStore.premiumLimit) textes, en un seul achat.")
                        .font(Typo.body(14)).foregroundStyle(Palette.inkSoft)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Palette.inkSoft)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.surface))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Palette.hairline))
        }
        .buttonStyle(PressableStyle())
    }

    @ViewBuilder
    private var toast: some View {
        if let message = router.toast {
            Text(message)
                .font(Typo.headline(15))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Capsule().fill(Palette.ink.opacity(0.92)))
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func duplicate(_ s: Script) {
        if let copy = store.duplicate(s) {
            withAnimation(.snappy) { router.show("Copie créée : « \(copy.displayTitle) »") }
        } else {
            router.sheet = .premium
        }
    }
}

// MARK: - Cartes

struct ScriptCard: View {
    let script: Script
    let wordsPerMinute: Double
    let onRead: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    var body: some View {
        let color = Palette.cardColor(script.colorIndex)
        let words = script.wordCount
        let progress = words > 0 ? min(1, Double(script.lastWord) / Double(words)) : 0
        Button(action: onRead) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    Monogram(text: script.displayTitle, symbol: script.symbol, color: color)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(script.displayTitle)
                            .font(Typo.headline(17))
                            .foregroundStyle(Palette.ink)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Text("Modifié \(Format.relative(script.updatedAt))")
                            .font(Typo.caption(12))
                            .foregroundStyle(Palette.inkSoft)
                    }
                    Spacer(minLength: 0)
                    Menu {
                        Button(action: onRead) { Label("Lire", systemImage: "play.fill") }
                        Button(action: onEdit) { Label("Modifier", systemImage: "pencil") }
                        Button(action: onDuplicate) { Label("Dupliquer", systemImage: "plus.square.on.square") }
                        Button(role: .destructive, action: onDelete) { Label("Supprimer", systemImage: "trash") }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Palette.inkSoft)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Actions pour \(script.displayTitle)")
                }
                if !script.excerpt.isEmpty {
                    Text(script.excerpt)
                        .font(Typo.body(14))
                        .foregroundStyle(Palette.inkSoft)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                HStack(spacing: 6) {
                    Tag(text: Format.words(words), tint: color)
                    Tag(text: "≈ " + Format.duration(Double(words) / max(1, wordsPerMinute) * 60), symbol: "clock", tint: Palette.inkSoft)
                    if progress > 0.02 && progress < 0.98 {
                        Tag(text: "Lu à \(Int(progress * 100)) %", symbol: "bookmark.fill", tint: Palette.inkSoft)
                    }
                    Spacer()
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Palette.ink)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Palette.background))
                    }
                    .accessibilityLabel("Modifier \(script.displayTitle)")
                    Image(systemName: "play.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(color))
                        .accessibilityHidden(true)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Palette.surface)
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
            )
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Palette.hairline))
        }
        .buttonStyle(PressableStyle())
        .contextMenu {
            Button(action: onRead) { Label("Lire", systemImage: "play.fill") }
            Button(action: onEdit) { Label("Modifier", systemImage: "pencil") }
            Button(action: onDuplicate) { Label("Dupliquer", systemImage: "plus.square.on.square") }
            Button(role: .destructive, action: onDelete) { Label("Supprimer", systemImage: "trash") }
        }
        .accessibilityHint("Ouvre le prompteur")
    }
}

struct SampleCard: View {
    let script: Script
    let wordsPerMinute: Double
    let onRead: () -> Void

    var body: some View {
        let color = Palette.cardColor(script.colorIndex)
        Button(action: onRead) {
            VStack(alignment: .leading, spacing: 10) {
                Monogram(text: script.displayTitle, symbol: script.symbol, color: .white, onColor: color)
                Spacer(minLength: 0)
                Text(script.displayTitle)
                    .font(Typo.headline(16))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text("≈ " + Format.duration(Double(script.wordCount) / max(1, wordsPerMinute) * 60))
                    .font(Typo.caption(12))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(16)
            .frame(width: 168, height: 176, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(LinearGradient(colors: [color, color.opacity(0.78)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: color.opacity(0.35), radius: 10, y: 6)
            )
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Exemple : \(script.displayTitle)")
    }
}

struct Monogram: View {
    let text: String
    var symbol: String?
    let color: Color
    var onColor: Color? = nil

    var body: some View {
        ZStack {
            Circle().fill(onColor == nil ? color.opacity(0.14) : Color.white.opacity(0.22))
            if let symbol {
                Image(systemName: symbol).font(.system(size: 18, weight: .bold))
            } else {
                Text(String(text.first ?? "B").uppercased()).font(.system(size: 20, weight: .black, design: .rounded))
            }
        }
        .foregroundStyle(color)
        .frame(width: 44, height: 44)
        .accessibilityHidden(true)
    }
}
