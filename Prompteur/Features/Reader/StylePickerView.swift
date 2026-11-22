import SwiftUI

/// Choix du style d'affichage : Classique, Vieille école, 3D.
struct StylePickerView: View {
    @Environment(SettingsStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(StageFamily.allCases) { family in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(family.title.uppercased())
                                .font(Typo.caption(12))
                                .tracking(1.2)
                                .foregroundStyle(.secondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(StageStyle.allCases.filter { $0.family == family }) { style in
                                        StyleTile(style: style, selected: store.reader.style == style) {
                                            withAnimation(.snappy) { store.reader.style = style }
                                            Haptics.tick()
                                        }
                                    }
                                }
                                .padding(.horizontal, 2)
                                .padding(.vertical, 4)
                            }
                            if family == .classic, store.reader.style == .classic { themeChips }
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Style d'affichage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("OK") { dismiss() }.fontWeight(.bold) }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        .tint(Palette.onAir)
    }

    private var themeChips: some View {
        @Bindable var store = store
        return HStack(spacing: 8) {
            ForEach(ClassicTheme.allCases) { t in
                let selected = store.reader.classicTheme == t
                Button {
                    withAnimation(.snappy) { store.reader.classicTheme = t }
                    Haptics.tick()
                } label: {
                    HStack(spacing: 6) {
                        Circle().fill(t == .paper ? Color(hex: "#FBF6EA") : (t == .night ? Color(hex: "#121933") : .black))
                            .overlay(Circle().strokeBorder(Palette.hairline))
                            .frame(width: 16, height: 16)
                        Text(t.title).font(Typo.headline(14))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(selected ? Palette.onAir.opacity(0.14) : Palette.surface))
                    .overlay(Capsule().strokeBorder(selected ? Palette.onAir : Palette.hairline, lineWidth: selected ? 2 : 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct StyleTile: View {
    let style: StageStyle
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                StyleThumbnail(style: style)
                    .frame(width: 168, height: 104)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(selected ? Palette.onAir : .clear, lineWidth: 3)
                    )
                    .overlay(alignment: .topTrailing) {
                        if selected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white, Palette.onAir)
                                .padding(6)
                        }
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text(style.title).font(Typo.headline(15)).foregroundStyle(Palette.ink)
                    Text(style.subtitle).font(Typo.caption(12)).foregroundStyle(Palette.inkSoft)
                        .lineLimit(1)
                }
                .frame(width: 168, alignment: .leading)
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(style.title), \(style.subtitle)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Miniature dessinée de chaque style.
struct StyleThumbnail: View {
    let style: StageStyle

    var body: some View {
        switch style {
        case .classic:
            ZStack {
                LinearGradient(colors: [Color(hex: "#0A0D1A"), Color(hex: "#151C38")], startPoint: .top, endPoint: .bottom)
                VStack(spacing: 7) {
                    bar(0.55, .white.opacity(0.25))
                    HStack(spacing: 4) {
                        Image(systemName: "arrowtriangle.right.fill").font(.system(size: 8)).foregroundStyle(Palette.onAir)
                        bar(0.7, .white)
                        Image(systemName: "arrowtriangle.left.fill").font(.system(size: 8)).foregroundStyle(Palette.onAir)
                    }
                    bar(0.6, .white.opacity(0.7))
                    bar(0.45, .white.opacity(0.5))
                }
            }
        case .crtGreen, .crtAmber:
            let c = style == .crtAmber ? Color(hex: "#FFB43A") : Color(hex: "#46FF86")
            ZStack {
                Color(hex: "#0B0B0B")
                RoundedRectangle(cornerRadius: 18)
                    .fill(style == .crtAmber ? Color(hex: "#120902") : Color(hex: "#031008"))
                    .padding(8)
                VStack(alignment: .leading, spacing: 4) {
                    Text("BOBPROMPT 2.0")
                    Text("PRÊT.▌")
                }
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(c)
                .shadow(color: c, radius: 4)
                VStack(spacing: 2) {
                    ForEach(0..<26, id: \.self) { _ in Rectangle().fill(.black.opacity(0.25)).frame(height: 1); Spacer(minLength: 2) }
                }
                .padding(8)
            }
        case .typewriter:
            ZStack(alignment: .top) {
                Color(hex: "#2E241D")
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 0) {
                        Text("Il était ").foregroundStyle(Color(hex: "#1E1A16"))
                        Text("une").foregroundStyle(Color(hex: "#B3261E"))
                        Text(" fois").foregroundStyle(Color(hex: "#1E1A16"))
                    }
                    Text("un petit drag").foregroundStyle(Color(hex: "#1E1A16"))
                }
                .font(.custom("AmericanTypewriter-Semibold", size: 13))
                .padding(10)
                .frame(width: 130, height: 70, alignment: .topLeading)
                .background(Color(hex: "#F7F0DE"))
                .padding(.top, 8)
                VStack {
                    Spacer()
                    Capsule().fill(LinearGradient(colors: [.black, Color(hex: "#4A4A4E"), .black], startPoint: .top, endPoint: .bottom))
                        .frame(height: 16)
                        .padding(.horizontal, -6)
                    Rectangle().fill(Color(hex: "#34403A")).frame(height: 14)
                }
            }
        case .drum:
            ZStack {
                LinearGradient(colors: [Color(hex: "#07081A"), Color(hex: "#1D1645")], startPoint: .top, endPoint: .bottom)
                ForEach(-3...3, id: \.self) { k in
                    let a = Double(k) * 0.42
                    bar(0.62, .white.opacity(max(0.15, cos(a))))
                        .scaleEffect(y: max(0.2, cos(a)))
                        .offset(y: sin(a) * 34)
                        .rotation3DEffect(.degrees(-16), axis: (x: 0, y: 1, z: 0))
                }
                Ellipse().strokeBorder(Palette.indigo.opacity(0.8), lineWidth: 2)
                    .frame(width: 22, height: 78).offset(x: -60)
                Ellipse().strokeBorder(Palette.indigo.opacity(0.8), lineWidth: 2)
                    .frame(width: 22, height: 78).offset(x: 58)
            }
        case .cards:
            ZStack {
                LinearGradient(colors: [Color(hex: "#181A33"), Color(hex: "#2B2150")], startPoint: .topLeading, endPoint: .bottomTrailing)
                ForEach((0..<3).reversed(), id: \.self) { i in
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color(hex: "#FFFDF7"))
                        .frame(width: 96, height: 62)
                        .overlay(VStack(alignment: .leading, spacing: 5) {
                            Capsule().fill(Palette.pink).frame(width: 18, height: 4)
                            bar(0.0, Color(hex: "#1D5BD6"), width: 60)
                            bar(0.0, Color(hex: "#D7263D"), width: 44)
                        }.padding(10), alignment: .topLeading)
                        .scaleEffect(1 - CGFloat(i) * 0.08)
                        .offset(y: CGFloat(i) * 9)
                        .rotationEffect(.degrees(Double(i) * (i % 2 == 0 ? 3 : -3)))
                        .shadow(color: .black.opacity(0.3), radius: 6, y: 4)
                }
                .rotation3DEffect(.degrees(14), axis: (x: 0, y: 1, z: 0))
            }
        }
    }

    private func bar(_ fraction: CGFloat, _ color: Color, width: CGFloat? = nil) -> some View {
        Capsule().fill(color).frame(width: width ?? 168 * fraction * 0.8, height: 6)
    }
}
