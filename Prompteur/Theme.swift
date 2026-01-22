import SwiftUI

struct Theme {
    // MARK: - Gradients modernes
    static let backgroundGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 0.98, green: 0.86, blue: 0.38),
            Color(red: 0.99, green: 0.67, blue: 0.53)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Nouveau: Gradient Aurora (tendance 2024)
    static let auroraGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 0.4, green: 0.2, blue: 0.8),
            Color(red: 0.2, green: 0.6, blue: 0.9),
            Color(red: 0.3, green: 0.8, blue: 0.7)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Nouveau: Gradient Sunset Vibes
    static let sunsetGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 1.0, green: 0.4, blue: 0.5),
            Color(red: 1.0, green: 0.6, blue: 0.3),
            Color(red: 1.0, green: 0.8, blue: 0.4)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Nouveau: Gradient Midnight
    static let midnightGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 0.1, green: 0.1, blue: 0.2),
            Color(red: 0.2, green: 0.15, blue: 0.35),
            Color(red: 0.15, green: 0.25, blue: 0.4)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Nouveau: Gradient Forest
    static let forestGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 0.15, green: 0.45, blue: 0.35),
            Color(red: 0.25, green: 0.55, blue: 0.4),
            Color(red: 0.4, green: 0.7, blue: 0.5)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Couleurs principales
    static let primary = Color(red: 0.20, green: 0.40, blue: 0.85)
    static let accent = Color(red: 0.93, green: 0.36, blue: 0.41)
    static let friendlyGreen = Color(red: 0.24, green: 0.70, blue: 0.44)
    static let friendlyPurple = Color(red: 0.52, green: 0.37, blue: 0.92)
    
    // Nouvelles couleurs modernes
    static let neonBlue = Color(red: 0.0, green: 0.75, blue: 1.0)
    static let neonPink = Color(red: 1.0, green: 0.3, blue: 0.6)
    static let neonGreen = Color(red: 0.2, green: 1.0, blue: 0.6)
    static let softIndigo = Color(red: 0.35, green: 0.35, blue: 0.85)
    static let warmOrange = Color(red: 1.0, green: 0.5, blue: 0.2)
    static let mintGreen = Color(red: 0.6, green: 0.95, blue: 0.85)
    static let lavender = Color(red: 0.75, green: 0.65, blue: 0.95)
    
    // MARK: - Glassmorphism
    static let glassBackground = Color.white.opacity(0.15)
    static let glassBorder = Color.white.opacity(0.3)
    static let darkGlassBackground = Color.black.opacity(0.2)

    static func roundedFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - Modificateurs modernes
extension View {
    /// Effet glassmorphisme moderne
    func glassCard(cornerRadius: CGFloat = 20) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Theme.glassBorder, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
    }
    
    /// Carte avec ombre douce
    func softCard(cornerRadius: CGFloat = 20, color: Color = .white) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(color.opacity(0.95))
            )
            .shadow(color: .black.opacity(0.08), radius: 15, x: 0, y: 8)
    }
    
    /// Badge/Chip moderne
    func chipStyle(color: Color = Theme.primary) -> some View {
        self
            .font(Theme.roundedFont(size: 14, weight: .medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(color.opacity(0.15))
            )
            .overlay(
                Capsule()
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
    }
    
    /// Bouton flottant moderne
    func floatingButton(color: Color = Theme.primary) -> some View {
        self
            .font(Theme.roundedFont(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(color: color.opacity(0.4), radius: 12, x: 0, y: 6)
    }
    
    /// Animation de pulsation subtile
    func pulseAnimation(isActive: Bool) -> some View {
        self
            .scaleEffect(isActive ? 1.02 : 1.0)
            .animation(
                isActive ? .easeInOut(duration: 1.5).repeatForever(autoreverses: true) : .default,
                value: isActive
            )
    }
}

// MARK: - Thèmes prédéfinis
enum AppTheme: String, CaseIterable, Identifiable {
    case candy = "Bonbons"
    case ocean = "Océan"
    case aurora = "Aurora"
    case sunset = "Coucher de soleil"
    case midnight = "Nuit"
    case forest = "Forêt"
    
    var id: String { rawValue }
    
    var gradient: LinearGradient {
        switch self {
        case .candy: return Theme.backgroundGradient
        case .ocean:
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.58, green: 0.82, blue: 0.99),
                    Color(red: 0.20, green: 0.60, blue: 0.86)
                ]),
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .aurora: return Theme.auroraGradient
        case .sunset: return Theme.sunsetGradient
        case .midnight: return Theme.midnightGradient
        case .forest: return Theme.forestGradient
        }
    }
    
    var primaryColor: Color {
        switch self {
        case .candy: return Theme.friendlyPurple
        case .ocean: return Color(red: 0.12, green: 0.55, blue: 0.74)
        case .aurora: return Theme.neonBlue
        case .sunset: return Theme.warmOrange
        case .midnight: return Theme.lavender
        case .forest: return Theme.mintGreen
        }
    }
    
    var accentColor: Color {
        switch self {
        case .candy: return Theme.accent
        case .ocean: return Theme.neonBlue
        case .aurora: return Theme.neonPink
        case .sunset: return Theme.neonPink
        case .midnight: return Theme.neonBlue
        case .forest: return Theme.friendlyGreen
        }
    }
    
    var isDark: Bool {
        self == .midnight
    }
    
    var textColor: Color {
        isDark ? .white : .primary
    }
    
    var icon: String {
        switch self {
        case .candy: return "🍬"
        case .ocean: return "🌊"
        case .aurora: return "🌌"
        case .sunset: return "🌅"
        case .midnight: return "🌙"
        case .forest: return "🌲"
        }
    }
}

extension UIColor {
    static func from(_ color: Color) -> UIColor { UIColor(color) }
}
