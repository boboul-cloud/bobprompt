import SwiftUI
import UIKit

// MARK: - Couleurs

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r, g, b, a: Double
        switch s.count {
        case 8:
            r = Double((v >> 24) & 0xFF) / 255; g = Double((v >> 16) & 0xFF) / 255
            b = Double((v >> 8) & 0xFF) / 255; a = Double(v & 0xFF) / 255
        default:
            r = Double((v >> 16) & 0xFF) / 255; g = Double((v >> 8) & 0xFF) / 255
            b = Double(v & 0xFF) / 255; a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    /// Couleur qui s'adapte au mode clair / sombre.
    init(light: String, dark: String) {
        self.init(UIColor { trait in
            UIColor(Color(hex: trait.userInterfaceStyle == .dark ? dark : light))
        })
    }

    func hexString() -> String {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        let c = { (x: CGFloat) in Int((min(max(x, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", c(r), c(g), c(b))
    }
}

/// Palette « studio » : le rouge ON AIR, l'encre et le papier.
enum Palette {
    static let onAir = Color(hex: "#FF4B3E")
    static let onAirDeep = Color(hex: "#E0342A")
    static let sun = Color(hex: "#FFB020")
    static let teal = Color(hex: "#12B5A5")
    static let indigo = Color(hex: "#5B5BF5")
    static let pink = Color(hex: "#F2559B")
    static let leaf = Color(hex: "#2FB463")

    static let ink = Color(light: "#15161D", dark: "#F3EFE6")
    static let inkSoft = Color(light: "#5F6170", dark: "#A6A8B5")
    static let background = Color(light: "#F5F1E8", dark: "#0D0E13")
    static let surface = Color(light: "#FFFFFF", dark: "#191B23")
    static let surfaceRaised = Color(light: "#FFFFFF", dark: "#22252F")
    static let hairline = Color(light: "#E6E0D3", dark: "#2B2E39")

    /// Couleurs attribuées aux textes de la bibliothèque.
    static let cardColors: [Color] = [onAir, indigo, teal, sun, pink, leaf]
    static func cardColor(_ index: Int) -> Color {
        cardColors[((index % cardColors.count) + cardColors.count) % cardColors.count]
    }
}

// MARK: - Typographie

enum Typo {
    static func title(_ size: CGFloat = 34) -> Font { .system(size: size, weight: .heavy, design: .rounded) }
    static func headline(_ size: CGFloat = 17) -> Font { .system(size: size, weight: .bold, design: .rounded) }
    static func body(_ size: CGFloat = 16) -> Font { .system(size: size, weight: .medium, design: .rounded) }
    static func caption(_ size: CGFloat = 13) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
    static func mono(_ size: CGFloat = 13) -> Font { .system(size: size, weight: .semibold, design: .monospaced) }
}

// MARK: - Boutons

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = Palette.onAir
    var compact = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typo.headline(compact ? 15 : 17))
            .foregroundStyle(.white)
            .padding(.horizontal, compact ? 16 : 22)
            .padding(.vertical, compact ? 10 : 15)
            .background(
                Capsule().fill(color)
                    .shadow(color: color.opacity(0.35), radius: configuration.isPressed ? 4 : 12, y: configuration.isPressed ? 2 : 6)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct SoftButtonStyle: ButtonStyle {
    var tint: Color = Palette.ink
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typo.headline(15))
            .foregroundStyle(tint)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(Capsule().fill(Palette.surface))
            .overlay(Capsule().strokeBorder(Palette.hairline, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Bouton rond translucide, utilisé sur les fonds du lecteur.
struct GlassCircleButtonStyle: ButtonStyle {
    var size: CGFloat = 48
    var active = false
    var activeColor: Color = Palette.onAir
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.38, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                Circle().fill(active ? AnyShapeStyle(activeColor) : AnyShapeStyle(.ultraThinMaterial))
            )
            .overlay(Circle().strokeBorder(.white.opacity(active ? 0 : 0.14), lineWidth: 1))
            .environment(\.colorScheme, .dark)
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

// MARK: - Éléments de marque

/// Le voyant « ON AIR » : motif de l'app.
struct OnAirDot: View {
    var size: CGFloat = 10
    var pulsing = true
    @State private var on = false
    var body: some View {
        Circle()
            .fill(Palette.onAir)
            .frame(width: size, height: size)
            .shadow(color: Palette.onAir.opacity(on ? 0.9 : 0.3), radius: on ? size : size * 0.3)
            .onAppear {
                guard pulsing else { return }
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { on = true }
            }
    }
}

struct Wordmark: View {
    var size: CGFloat = 30
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("bob").foregroundStyle(Palette.ink)
            Text("prompt").foregroundStyle(Palette.onAir)
            OnAirDot(size: size * 0.24)
                .padding(.leading, size * 0.12)
                .alignmentGuide(.firstTextBaseline) { d in d[.bottom] + size * 0.02 }
        }
        .font(.system(size: size, weight: .black, design: .rounded))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("bobprompt")
    }
}

/// Étiquette arrondie (« 120 mots », « 2 min »).
struct Tag: View {
    let text: String
    var symbol: String? = nil
    var tint: Color = Palette.inkSoft
    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol).font(.system(size: 10, weight: .bold)) }
            Text(text)
        }
        .font(Typo.caption(12))
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(tint.opacity(0.12)))
    }
}

// MARK: - Retour haptique

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func thump() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func tick() { UISelectionFeedbackGenerator().selectionChanged() }
}

// MARK: - Formats

enum Format {
    static func duration(_ seconds: Double) -> String {
        let s = max(0, Int(seconds.rounded()))
        if s < 60 { return "\(s) s" }
        let m = s / 60, r = s % 60
        return r == 0 ? "\(m) min" : String(format: "%d min %02d", m, r)
    }

    static func clock(_ seconds: Double) -> String {
        let s = max(0, Int(seconds.rounded()))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    static func words(_ n: Int) -> String { n <= 1 ? "\(n) mot" : "\(n) mots" }

    static let shortDate: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "fr_FR")
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }()

    static func relative(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.unitsStyle = .full
        if abs(date.timeIntervalSinceNow) < 60 { return "à l'instant" }
        return f.localizedString(for: date, relativeTo: Date())
    }
}
